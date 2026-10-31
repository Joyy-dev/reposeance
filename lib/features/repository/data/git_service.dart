import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/models/git_commit.dart';
import '../domain/models/repository_info.dart';

/// Result types for repository root resolution.
sealed class GitRootResult {
  const GitRootResult();
}

class GitRootSuccess extends GitRootResult {
  final String canonicalRoot;
  const GitRootSuccess(this.canonicalRoot);
}

class GitRootNotARepository extends GitRootResult {
  final String path;
  final String message;
  const GitRootNotARepository(this.path, this.message);
}

class GitRootNotInstalled extends GitRootResult {
  final String error;
  const GitRootNotInstalled(this.error);
}

class GitRootFailure extends GitRootResult {
  final String error;
  const GitRootFailure(this.error);
}

typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  bool runInShell,
  Encoding? stdoutEncoding,
  Encoding? stderrEncoding,
});

/// Safe, non-shell Git subprocess service enforcing allowlisted subcommands and bounds.
class GitService {
  final ProcessRunner _processRunner;

  GitService({ProcessRunner? processRunner})
    : _processRunner =
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

  /// Resolves the canonical repository root from any selected directory or subdirectory.
  Future<GitRootResult> resolveRepositoryRoot(
    String candidatePath, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final dir = Directory(candidatePath);
    if (!dir.existsSync()) {
      return GitRootFailure(
        'Specified directory does not exist: $candidatePath',
      );
    }

    try {
      final result = await _processRunner('git', [
        '-C',
        candidatePath,
        '--no-pager',
        'rev-parse',
        '--show-toplevel',
      ], runInShell: false).timeout(timeout);

      if (result.exitCode == 0) {
        final stdout = (result.stdout as String).trim();
        if (stdout.isEmpty) {
          return GitRootNotARepository(
            candidatePath,
            'Empty response from rev-parse',
          );
        }
        final canonical = p.normalize(stdout);
        return GitRootSuccess(canonical);
      } else {
        final stderr = (result.stderr as String).trim();
        if (stderr.contains('not a git repository') || result.exitCode == 128) {
          return GitRootNotARepository(candidatePath, stderr);
        }
        return GitRootFailure(
          'Git error (exit code ${result.exitCode}): $stderr',
        );
      }
    } on TimeoutException {
      return const GitRootFailure('Git repository check timed out after 5s');
    } on ProcessException catch (e) {
      return GitRootNotInstalled(
        'Git executable not found in PATH: ${e.message}',
      );
    } catch (e) {
      return GitRootFailure('Unexpected failure resolving repository: $e');
    }
  }

  /// Extracts repository metadata including branch and detached HEAD status.
  Future<RepositoryInfo> getRepositoryInfo(
    String rootPath, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    String? currentBranch;
    bool isDetachedHead = false;
    bool isEmpty = false;
    String? headCommitHash;

    // 1. Check branch name via symbolic-ref
    try {
      final branchResult = await _processRunner('git', [
        '-C',
        rootPath,
        '--no-pager',
        'symbolic-ref',
        '--short',
        'HEAD',
      ], runInShell: false).timeout(timeout);

      if (branchResult.exitCode == 0) {
        currentBranch = (branchResult.stdout as String).trim();
      } else {
        // Fallback: Check if detached HEAD
        final detachedResult = await _processRunner('git', [
          '-C',
          rootPath,
          '--no-pager',
          'rev-parse',
          '--short',
          'HEAD',
        ], runInShell: false).timeout(timeout);

        if (detachedResult.exitCode == 0) {
          final hash = (detachedResult.stdout as String).trim();
          if (hash.isNotEmpty) {
            currentBranch = 'HEAD ($hash)';
            isDetachedHead = true;
          }
        } else {
          // Both failed -> Empty repository with no commits
          isEmpty = true;
          currentBranch = null;
        }
      }
    } catch (_) {
      isEmpty = true;
    }

    // 2. Check full HEAD commit hash
    if (!isEmpty) {
      try {
        final headResult = await _processRunner('git', [
          '-C',
          rootPath,
          '--no-pager',
          'rev-parse',
          'HEAD',
        ], runInShell: false).timeout(timeout);

        if (headResult.exitCode == 0) {
          headCommitHash = (headResult.stdout as String).trim();
        }
      } catch (_) {}
    }

    return RepositoryInfo.fromPath(
      rootPath,
      currentBranch: currentBranch,
      isDetachedHead: isDetachedHead,
      isEmpty: isEmpty,
      headCommitHash: headCommitHash,
    );
  }

  /// Collects up to [maxCommits] recent commit subjects using ASCII Unit Separator format.
  Future<List<GitCommit>> getRecentCommits(
    String rootPath, {
    int maxCommits = 15,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      // Delimiter: ASCII Unit Separator (\x1f)
      final result = await _processRunner('git', [
        '-C',
        rootPath,
        '--no-pager',
        'log',
        '-n',
        maxCommits.toString(),
        '--format=%H%x1f%an%x1f%at%x1f%s',
      ], runInShell: false).timeout(timeout);

      if (result.exitCode != 0) {
        // Exit code != 0 typically means an empty repository without commits
        return [];
      }

      final stdout = (result.stdout as String).trim();
      if (stdout.isEmpty) {
        return [];
      }

      final List<GitCommit> commits = [];
      final lines = stdout.split('\n');

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        final parts = trimmed.split('\x1f');
        if (parts.length >= 4) {
          final hash = parts[0].trim();
          final author = parts[1].trim();
          final timestampSec = int.tryParse(parts[2].trim()) ?? 0;
          final subject = parts.sublist(3).join('\x1f').trim();

          final date = DateTime.fromMillisecondsSinceEpoch(
            timestampSec * 1000,
            isUtc: true,
          );

          commits.add(
            GitCommit(hash: hash, author: author, date: date, subject: subject),
          );
        }
      }

      return commits;
    } catch (_) {
      return [];
    }
  }
}
