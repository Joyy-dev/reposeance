import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:reposeance/features/repository/data/git_service.dart';
import 'package:reposeance/features/repository/data/repository_scanner.dart';

void main() {
  group('Path Containment & Security Invariant Tests', () {
    late Directory tempRepo;

    setUp(() {
      tempRepo = Directory.systemTemp.createTempSync('containment_repo_');
      Process.runSync('git', ['init'], workingDirectory: tempRepo.path);
      Process.runSync('git', [
        'config',
        'user.name',
        'Tester',
      ], workingDirectory: tempRepo.path);
      Process.runSync('git', [
        'config',
        'user.email',
        'test@test.com',
      ], workingDirectory: tempRepo.path);
    });

    tearDown(() {
      try {
        tempRepo.deleteSync(recursive: true);
      } catch (_) {}
    });

    test(
      'rejects candidate paths attempting directory traversal (../../)',
      () async {
        File(p.join(tempRepo.path, 'README.md'))
            .writeAsStringSync('# Safe Root');
        Process.runSync('git', ['add', '.'], workingDirectory: tempRepo.path);
        Process.runSync('git', [
          'commit',
          '-m',
          'safe commit',
        ], workingDirectory: tempRepo.path);

        // Mock ProcessRunner returning a hostile relative path
        Future<ProcessResult> mockRunner(
          String exe,
          List<String> args, {
          String? workingDirectory,
          bool runInShell = false,
          Encoding? stdoutEncoding,
          Encoding? stderrEncoding,
        }) async {
          if (args.contains('ls-files')) {
            // Return valid path plus a path traversal escape candidate
            return ProcessResult(
              0,
              0,
              'README.md\x00../../hostile_escape.txt\x00',
              '',
            );
          }
          return Process.run(
            exe,
            args,
            workingDirectory: workingDirectory,
            runInShell: runInShell,
          );
        }

        final scanner = RepositoryScanner(
          gitService: GitService(processRunner: mockRunner),
          processRunner: mockRunner,
        );

        final result = await scanner.scanRepository(tempRepo.path);
        final files = result.files.map((f) => f.relativePath).toList();

        expect(files, contains('README.md'));
        expect(files, isNot(contains('../../hostile_escape.txt')));
        expect(
          result.partialWarnings.any(
            (w) => w.contains('Path traversal attempted and rejected'),
          ),
          isTrue,
        );
      },
    );

    test('skips symlinks and reparse points without following', () async {
      File(p.join(tempRepo.path, 'README.md')).writeAsStringSync('# Safe Root');
      final targetFile = File(p.join(tempRepo.path, 'target.txt'))
        ..writeAsStringSync('Target Content');

      // Create a link entity inside repo
      try {
        final link = Link(p.join(tempRepo.path, 'symlink_test.txt'));
        link.createSync(targetFile.path);

        Process.runSync('git', ['add', '.'], workingDirectory: tempRepo.path);
        Process.runSync('git', [
          'commit',
          '-m',
          'add link',
        ], workingDirectory: tempRepo.path);

        final scanner = RepositoryScanner();
        final result = await scanner.scanRepository(tempRepo.path);
        final files = result.files.map((f) => f.relativePath).toList();

        expect(files, contains('README.md'));
        expect(files, contains('target.txt'));
        expect(files, isNot(contains('symlink_test.txt')));
        expect(
          result.partialWarnings.any(
            (w) =>
                w.contains('Skipped 1 symlink(s) / Windows reparse point(s)'),
          ),
          isTrue,
        );
      } on FileSystemException {
        // Windows unprivileged users might not have symlink creation permission in developer mode;
        // this test gracefully verifies that if created, it's skipped.
      }
    });

    test('prevents scanning user home directory directly', () async {
      final homeDir =
          Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
      if (homeDir != null && homeDir.isNotEmpty) {
        // Mock GitService to pretend the home directory is a git repository
        final mockGit = GitService(
          processRunner:
              (
                exe,
                args, {
                workingDirectory,
                runInShell = false,
                stdoutEncoding,
                stderrEncoding,
              }) async {
                if (args.contains('rev-parse') &&
                    args.contains('--show-toplevel')) {
                  return ProcessResult(0, 0, homeDir, '');
                }
                return ProcessResult(0, 0, '', '');
              },
        );

        final scanner = RepositoryScanner(gitService: mockGit);
        expect(
          () => scanner.scanRepository(homeDir),
          throwsA(
            isA<ScannerException>().having(
              (e) => e.message,
              'message',
              contains(
                'Scanning the user home directory root directly is prohibited',
              ),
            ),
          ),
        );
      }
    });
  });
}
