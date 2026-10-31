import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/utils/hash_util.dart';
import '../domain/models/git_commit.dart';
import '../domain/models/repository_info.dart';
import '../domain/models/scan_limits.dart';
import '../domain/models/scan_result.dart';
import '../domain/models/scanned_file.dart';
import 'git_service.dart';

class ScannerException implements Exception {
  final String message;
  const ScannerException(this.message);

  @override
  String toString() => 'ScannerException: $message';
}

class _CandidateMetadata {
  final String relativePath;
  final String fullPath;
  final int byteSize;
  final int priorityTier;
  final int depth;

  const _CandidateMetadata({
    required this.relativePath,
    required this.fullPath,
    required this.byteSize,
    required this.priorityTier,
    required this.depth,
  });
}

/// Bounded repository scanner enumerating tracked files deterministically with hard limits and safety checks.
class RepositoryScanner {
  final GitService _gitService;
  final ProcessRunner _processRunner;

  RepositoryScanner({GitService? gitService, ProcessRunner? processRunner})
    : _gitService = gitService ?? GitService(),
      _processRunner =
          processRunner ??
          ((
            exe,
            args, {
            workingDirectory,
            runInShell = false,
            stdoutEncoding = utf8,
            stderrEncoding = utf8,
          }) => Process.run(
            exe,
            args,
            workingDirectory: workingDirectory,
            runInShell: runInShell,
            stdoutEncoding: stdoutEncoding,
            stderrEncoding: stderrEncoding,
          ));

  static const Set<String> _excludedSegments = {
    '.git',
    '.dart_tool',
    'build',
    'node_modules',
    'vendor',
    'dist',
    'coverage',
    '.gradle',
    'pods',
    '.idea',
    '.vscode',
    '.cache',
    '.tmp',
  };

  static const Set<String> _excludedLockfiles = {
    'pubspec.lock',
    'package-lock.json',
    'cargo.lock',
    'yarn.lock',
    'pnpm-lock.yaml',
    'gemfile.lock',
    'poetry.lock',
  };

  static const Set<String> _binaryExtensions = {
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.ico',
    '.webp',
    '.bmp',
    '.tiff',
    '.pdf',
    '.zip',
    '.tar',
    '.gz',
    '.7z',
    '.exe',
    '.dll',
    '.so',
    '.dylib',
    '.class',
    '.pyc',
    '.wasm',
    '.mp3',
    '.mp4',
    '.wav',
    '.mov',
    '.avi',
    '.woff',
    '.woff2',
    '.ttf',
    '.eot',
    '.jar',
  };

  /// Performs a bounded scan over the selected repository working tree.
  Future<ScanResult> scanRepository(
    String targetPath, {
    ScanLimits limits = ScanLimits.standard,
  }) async {
    final stopwatch = Stopwatch()..start();
    final List<String> warnings = [];

    // 1. Resolve canonical repository root
    final rootResult = await _gitService.resolveRepositoryRoot(targetPath);
    final String canonicalRoot = switch (rootResult) {
      GitRootSuccess(:final canonicalRoot) => canonicalRoot,
      GitRootNotARepository(:final message) => throw ScannerException(
        'Path is not a Git repository: $message',
      ),
      GitRootNotInstalled(:final error) => throw ScannerException(
        'Git executable not found in PATH: $error',
      ),
      GitRootFailure(:final error) => throw ScannerException(
        'Failed to resolve repository root: $error',
      ),
    };

    // 2. Protected directory guard (prevent scanning user home directly)
    _assertNotUserHome(canonicalRoot);

    // 3. Extract RepositoryInfo and Commit History
    final RepositoryInfo repoInfo = await _gitService.getRepositoryInfo(
      canonicalRoot,
    );
    final List<GitCommit> commits = await _gitService.getRecentCommits(
      canonicalRoot,
      maxCommits: limits.maxCommits,
    );

    // 4. Enumerate tracked files via git ls-files -z (null-delimited)
    List<String> rawCandidates = [];
    try {
      final lsResult = await _processRunner('git', [
        '-C',
        canonicalRoot,
        '--no-pager',
        'ls-files',
        '-z',
      ], runInShell: false).timeout(limits.scanTimeout);

      if (lsResult.exitCode == 0) {
        final stdoutString = lsResult.stdout as String;

        // Bounded listing check
        if (stdoutString.length > limits.maxListingBytes) {
          warnings.add(
            'Candidate listing exceeded buffer limit (${limits.maxListingBytes ~/ (1024 * 1024)} MiB); truncated listing evaluated.',
          );
        }

        // Split by null byte \x00
        rawCandidates = stdoutString
            .split('\x00')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

        if (rawCandidates.length > limits.maxCandidates) {
          warnings.add(
            'Enumerated candidates exceeded limit of ${limits.maxCandidates} (found ${rawCandidates.length}); partial candidate list inspected.',
          );
          rawCandidates = rawCandidates.sublist(0, limits.maxCandidates);
        }
      } else {
        warnings.add(
          'git ls-files returned exit code ${lsResult.exitCode}: ${lsResult.stderr}',
        );
      }
    } on TimeoutException {
      warnings.add(
        'git ls-files timed out after ${limits.scanTimeout.inMilliseconds}ms',
      );
    } catch (e) {
      warnings.add('Error during candidate enumeration: $e');
    }

    // 5. Filter candidates according to security, depth, and size limits
    final List<_CandidateMetadata> validCandidates = [];
    final canonicalDir = Directory(canonicalRoot);
    final resolvedCanonicalRoot = canonicalDir.existsSync()
        ? canonicalDir.resolveSymbolicLinksSync()
        : canonicalRoot;

    int skippedSecrets = 0;
    int skippedOversized = 0;
    int skippedDepth = 0;
    int skippedReparsePoints = 0;

    for (final rawPath in rawCandidates) {
      final normRelPath = p.posix.normalize(rawPath.replaceAll(r'\', '/'));
      final segments = normRelPath.toLowerCase().split('/');

      // Check directory exclusions
      if (segments.any((seg) => _excludedSegments.contains(seg))) {
        continue;
      }

      // Check depth limit
      final depth = segments.length - 1;
      if (depth > limits.maxDepth) {
        skippedDepth++;
        continue;
      }

      // Check sensitive file patterns
      final filename = p.basename(normRelPath).toLowerCase();
      if (_isSensitiveFile(filename)) {
        skippedSecrets++;
        continue;
      }

      // Check lockfiles
      if (_excludedLockfiles.contains(filename)) {
        continue;
      }

      // Check binary extensions
      final ext = p.extension(filename).toLowerCase();
      if (_binaryExtensions.contains(ext)) {
        continue;
      }

      // Check canonical path containment
      final fullPath = p.normalize(p.join(canonicalRoot, normRelPath));
      final candidateEntity = File(fullPath);

      // Verify containment within canonical root
      if (!_isContainedWithin(resolvedCanonicalRoot, fullPath)) {
        warnings.add('Path traversal attempted and rejected: $normRelPath');
        continue;
      }

      // Verify file existence
      if (!candidateEntity.existsSync()) {
        continue;
      }

      // Check symlinks / Windows reparse points
      if (FileSystemEntity.isLinkSync(fullPath)) {
        skippedReparsePoints++;
        continue;
      }

      // Check file size bound
      final fileSize = candidateEntity.lengthSync();
      if (fileSize > limits.maxFileSize) {
        skippedOversized++;
        continue;
      }

      final tier = _calculatePriorityTier(normRelPath, filename);

      validCandidates.add(
        _CandidateMetadata(
          relativePath: normRelPath,
          fullPath: fullPath,
          byteSize: fileSize,
          priorityTier: tier,
          depth: depth,
        ),
      );
    }

    // Record aggregate filter warnings
    if (skippedSecrets > 0) {
      warnings.add(
        'Excluded $skippedSecrets sensitive/secret-bearing file(s) before read.',
      );
    }
    if (skippedOversized > 0) {
      warnings.add(
        'Skipped $skippedOversized file(s) exceeding maximum size bound (${limits.maxFileSize ~/ 1024} KiB).',
      );
    }
    if (skippedDepth > 0) {
      warnings.add(
        'Skipped $skippedDepth file(s) exceeding maximum traversal depth (${limits.maxDepth}).',
      );
    }
    if (skippedReparsePoints > 0) {
      warnings.add(
        'Skipped $skippedReparsePoints symlink(s) / Windows reparse point(s).',
      );
    }

    // 6. Deterministic Priority Sorting
    validCandidates.sort((a, b) {
      // Primary: Priority Tier (Tier 1 manifests first)
      if (a.priorityTier != b.priorityTier) {
        return a.priorityTier.compareTo(b.priorityTier);
      }
      // Secondary: Depth (shallower paths first)
      if (a.depth != b.depth) {
        return a.depth.compareTo(b.depth);
      }
      // Tertiary: Lexicographical order of relative path
      return a.relativePath.compareTo(b.relativePath);
    });

    // 7. Bounded File Reading and Line Counting
    final List<ScannedFile> selectedFiles = [];
    int totalBytesRead = 0;

    for (final candidate in validCandidates) {
      if (selectedFiles.length >= limits.maxFiles) {
        warnings.add(
          'Selected file limit (${limits.maxFiles}) reached; remaining ${validCandidates.length - selectedFiles.length} candidate(s) omitted.',
        );
        break;
      }

      if (totalBytesRead + candidate.byteSize > limits.maxTotalBytes) {
        warnings.add(
          'Total read byte budget (${limits.maxTotalBytes ~/ (1024 * 1024)} MiB) reached; remaining candidates omitted.',
        );
        break;
      }

      try {
        final bytes = File(candidate.fullPath).readAsBytesSync();

        // Sample initial 512 bytes for null byte (binary probe)
        final probeLength = bytes.length < 512 ? bytes.length : 512;
        bool isBinary = false;
        for (int i = 0; i < probeLength; i++) {
          if (bytes[i] == 0x00) {
            isBinary = true;
            break;
          }
        }
        if (isBinary) {
          continue;
        }

        // Decode as UTF-8
        final content = utf8.decode(bytes, allowMalformed: false);
        final lineCount = content.isEmpty ? 0 : content.split('\n').length;
        final hash = HashUtil.sha256Hex(content);

        selectedFiles.add(
          ScannedFile(
            relativePath: candidate.relativePath,
            fullPath: candidate.fullPath,
            byteSize: candidate.byteSize,
            lineCount: lineCount,
            priorityTier: candidate.priorityTier,
            content: content,
            contentHash: hash,
          ),
        );

        totalBytesRead += candidate.byteSize;
      } on FormatException {
        // Non-UTF-8 or malformed encoding -> skip safely
        continue;
      } catch (e) {
        warnings.add('Error reading file ${candidate.relativePath}: $e');
      }
    }

    stopwatch.stop();

    return ScanResult(
      repositoryInfo: repoInfo,
      files: selectedFiles,
      commits: commits,
      partialWarnings: warnings,
      totalCandidatesEnumerated: rawCandidates.length,
      totalBytesRead: totalBytesRead,
      scanDurationMs: stopwatch.elapsedMilliseconds,
    );
  }

  /// Verifies that candidatePath remains strictly beneath canonicalRoot.
  bool _isContainedWithin(String canonicalRoot, String candidatePath) {
    final normRoot = p.normalize(canonicalRoot).toLowerCase();
    final normCandidate = p.normalize(candidatePath).toLowerCase();

    if (normRoot == normCandidate) return true;
    return p.isWithin(normRoot, normCandidate);
  }

  /// Prevents scanning the host user's home directory.
  void _assertNotUserHome(String canonicalRoot) {
    final home =
        Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      final normHome = p.normalize(home).toLowerCase();
      final normRoot = p.normalize(canonicalRoot).toLowerCase();
      if (normRoot == normHome) {
        throw const ScannerException(
          'Scanning the user home directory root directly is prohibited for safety.',
        );
      }
    }
  }

  /// Sensitive file pattern detection.
  bool _isSensitiveFile(String filename) {
    if (filename == '.env' ||
        filename.startsWith('.env.') ||
        filename.endsWith('.env')) {
      return true;
    }
    if (filename.endsWith('.pem') ||
        filename.endsWith('.key') ||
        filename.endsWith('.p12') ||
        filename.endsWith('.pfx')) {
      return true;
    }
    if (filename.startsWith('id_rsa') || filename.startsWith('id_ed25519')) {
      return true;
    }
    if (filename.contains('credentials') || filename.contains('secret')) {
      return true;
    }
    if (filename == '.npmrc' || filename == '.netrc') {
      return true;
    }
    return false;
  }

  /// Calculates deterministic priority tier (1 to 5).
  int _calculatePriorityTier(String normRelPath, String filename) {
    // Tier 1: Project Identity & Manifests
    if (filename.startsWith('readme') ||
        filename == 'pubspec.yaml' ||
        filename == 'package.json' ||
        filename == 'cargo.toml' ||
        filename == 'pyproject.toml' ||
        filename == 'requirements.txt' ||
        filename == 'go.mod' ||
        filename == 'pom.xml' ||
        filename == 'build.gradle' ||
        filename == 'dockerfile' ||
        filename == 'makefile') {
      return 1;
    }

    // Tier 2: Entry points
    if (normRelPath == 'lib/main.dart' ||
        normRelPath == 'src/index.ts' ||
        normRelPath == 'src/index.js' ||
        normRelPath == 'src/main.ts' ||
        normRelPath == 'src/main.js' ||
        normRelPath == 'main.py' ||
        normRelPath == 'app.py' ||
        normRelPath.startsWith('cmd/') && normRelPath.endsWith('/main.go')) {
      return 2;
    }

    // Tier 3: Core Architecture
    if (normRelPath.contains('/services/') ||
        normRelPath.contains('/service/') ||
        normRelPath.contains('/controllers/') ||
        normRelPath.contains('/controller/') ||
        normRelPath.contains('/models/') ||
        normRelPath.contains('/model/') ||
        normRelPath.contains('/domain/') ||
        normRelPath.contains('/routes/') ||
        normRelPath.contains('/repositories/') ||
        normRelPath.contains('/core/')) {
      return 3;
    }

    // Tier 4: Tests
    if (normRelPath.startsWith('test/') ||
        normRelPath.startsWith('tests/') ||
        filename.endsWith('_test.dart') ||
        filename.endsWith('_test.go') ||
        filename.startsWith('test_')) {
      return 4;
    }

    // Tier 5: Other Source Code
    return 5;
  }
}
