import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:reposeance/features/repository/data/git_service.dart';

void main() {
  late GitService gitService;
  late String currentProductRepo;

  setUp(() {
    gitService = GitService();
    currentProductRepo = p.normalize(Directory.current.path);
  });

  group('GitService Root Resolution Tests', () {
    test('resolves canonical repository root from current repo root', () async {
      final result = await gitService.resolveRepositoryRoot(currentProductRepo);
      expect(result, isA<GitRootSuccess>());
      final success = result as GitRootSuccess;
      expect(
        p.normalize(success.canonicalRoot.toLowerCase()),
        equals(p.normalize(currentProductRepo).toLowerCase()),
      );
    });

    test('resolves repository root when pointed to a subdirectory', () async {
      final subDir = p.join(currentProductRepo, 'lib', 'core');
      final result = await gitService.resolveRepositoryRoot(subDir);
      expect(result, isA<GitRootSuccess>());
      final success = result as GitRootSuccess;
      expect(
        p.normalize(success.canonicalRoot.toLowerCase()),
        equals(p.normalize(currentProductRepo).toLowerCase()),
      );
    });

    test(
      'returns GitRootNotARepository when pointed to a non-git directory',
      () async {
        final tempDir = Directory.systemTemp.createTempSync('non_git_test_');
        addTearDown(() => tempDir.deleteSync(recursive: true));

        final result = await gitService.resolveRepositoryRoot(tempDir.path);
        expect(result, isA<GitRootNotARepository>());
      },
    );

    test('returns GitRootFailure when directory does not exist', () async {
      final nonExistent = p.join(currentProductRepo, 'non_existent_folder_xyz');
      final result = await gitService.resolveRepositoryRoot(nonExistent);
      expect(result, isA<GitRootFailure>());
    });
  });

  group('GitService Repository Metadata & Commits Tests', () {
    test('extracts branch and commit info from current repository', () async {
      final repoInfo = await gitService.getRepositoryInfo(currentProductRepo);
      expect(repoInfo.currentBranch, equals('main'));
      expect(repoInfo.isDetachedHead, isFalse);
      expect(repoInfo.isEmpty, isFalse);
      expect(repoInfo.headCommitHash, isNotNull);
      expect(repoInfo.headCommitHash!.length, equals(40));
    });

    test(
      'retrieves recent commit subjects using ASCII Unit Separator',
      () async {
        final commits = await gitService.getRecentCommits(
          currentProductRepo,
          maxCommits: 15,
        );
        expect(commits, isNotEmpty);
        final latestCommit = commits.first;
        expect(latestCommit.hash.length, equals(40));
        expect(latestCommit.shortHash.length, equals(7));
        expect(latestCommit.author, contains('Joyce Ava'));
        expect(latestCommit.subject, isNotEmpty);
        // Verify history contains known repository commits
        expect(
          commits.any(
            (c) =>
                c.subject.contains(
                  'initial RepoSéance Windows desktop scaffold',
                ) ||
                c.subject.contains('feat: safe git service') ||
                c.subject.contains('feat: native markdown report export'),
          ),
          isTrue,
        );
      },
    );

    test('handles hostile commit subjects with punctuation, quotes, and markdown', () async {
      // Mock ProcessRunner to test hostile commit subjects
      Future<ProcessResult> mockRunner(
        String exe,
        List<String> args, {
        String? workingDirectory,
        bool runInShell = false,
        Encoding? stdoutEncoding,
        Encoding? stderrEncoding,
      }) async {
        if (args.contains('log')) {
          const sampleOutput =
              'be72cfa0d8294439b812b7197d76c332c6c52287\x1fJoyce Ava\x1f1761919907\x1ffeat(core): fix "quotes", [brackets], and `code`!\n'
              'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2\x1fContributor\x1f1761919800\x1fchore: special symbols @#\$%^&*()_+{}|:<>?';
          return ProcessResult(0, 0, sampleOutput, '');
        }
        return ProcessResult(0, 0, '', '');
      }

      final customGitService = GitService(processRunner: mockRunner);
      final commits = await customGitService.getRecentCommits(
        'dummy/path',
        maxCommits: 2,
      );

      expect(commits.length, equals(2));
      expect(
        commits[0].subject,
        equals('feat(core): fix "quotes", [brackets], and `code`!'),
      );
      expect(commits[0].author, equals('Joyce Ava'));
      expect(
        commits[1].subject,
        equals('chore: special symbols @#\$%^&*()_+{}|:<>?'),
      );
    });

    test('handles empty commit history gracefully', () async {
      Future<ProcessResult> mockRunner(
        String exe,
        List<String> args, {
        String? workingDirectory,
        bool runInShell = false,
        Encoding? stdoutEncoding,
        Encoding? stderrEncoding,
      }) async {
        if (args.contains('log')) {
          // git log returns exit code 128 on empty repository
          return ProcessResult(
            0,
            128,
            '',
            'fatal: your current branch has does not have any commits yet',
          );
        }
        return ProcessResult(0, 0, '', '');
      }

      final customGitService = GitService(processRunner: mockRunner);
      final commits = await customGitService.getRecentCommits('empty/repo');
      expect(commits, isEmpty);
    });
  });
}
