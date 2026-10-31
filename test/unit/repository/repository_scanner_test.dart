import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:reposeance/features/repository/data/repository_scanner.dart';
import 'package:reposeance/features/repository/domain/models/scan_limits.dart';

void main() {
  late RepositoryScanner scanner;
  late String currentRepoPath;

  setUp(() {
    scanner = RepositoryScanner();
    currentRepoPath = p.normalize(Directory.current.path);
  });

  group('RepositoryScanner Self-Scan & Priority Ordering Tests', () {
    test('scans product repository and prioritizes identity manifests and entrypoints', () async {
      final result = await scanner.scanRepository(currentRepoPath);

      expect(result.files, isNotEmpty);
      expect(result.commits, isNotEmpty);
      expect(result.repositoryInfo.currentBranch, equals('main'));

      // Check priority ordering
      final relativePaths = result.files.map((f) => f.relativePath).toList();

      // Tier 1 manifests (README.md, pubspec.yaml) must appear before Tier 2 entrypoint (lib/main.dart)
      final readmeIndex = relativePaths.indexOf('README.md');
      final pubspecIndex = relativePaths.indexOf('pubspec.yaml');
      final mainIndex = relativePaths.indexOf('lib/main.dart');

      expect(readmeIndex, isNonNegative);
      expect(pubspecIndex, isNonNegative);
      expect(mainIndex, isNonNegative);

      expect(readmeIndex, lessThan(mainIndex));
      expect(pubspecIndex, lessThan(mainIndex));

      // Check line preservation and content hash
      final pubspecFile = result.files.firstWhere(
        (f) => f.relativePath == 'pubspec.yaml',
      );
      expect(pubspecFile.lineCount, greaterThan(10));
      expect(pubspecFile.contentHash.length, equals(64));
      expect(pubspecFile.content, contains('name: reposeance'));
    });

    test('respects maxFiles limit and records partial scan warning', () async {
      const tightLimits = ScanLimits(maxFiles: 2);
      final result = await scanner.scanRepository(
        currentRepoPath,
        limits: tightLimits,
      );

      expect(result.files.length, equals(2));
      expect(result.isPartial, isTrue);
      expect(
        result.partialWarnings.any(
          (w) => w.contains('Selected file limit (2) reached'),
        ),
        isTrue,
      );
    });
  });

  group('RepositoryScanner Sensitive & Binary Exclusion Fixture Tests', () {
    late Directory tempFixtureDir;

    setUp(() {
      tempFixtureDir = Directory.systemTemp.createTempSync('scanner_fixture_');
      Process.runSync('git', ['init'], workingDirectory: tempFixtureDir.path);
      Process.runSync('git', [
        'config',
        'user.name',
        'Tester',
      ], workingDirectory: tempFixtureDir.path);
      Process.runSync('git', [
        'config',
        'user.email',
        'test@test.com',
      ], workingDirectory: tempFixtureDir.path);
    });

    tearDown(() {
      try {
        tempFixtureDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test(
      'excludes sensitive files, secrets, lockfiles, and binary files',
      () async {
        // 1. Create allowed files
        File(p.join(tempFixtureDir.path, 'README.md'))
            .writeAsStringSync('# Fixture Project\nTest');
        File(p.join(tempFixtureDir.path, 'pubspec.yaml'))
            .writeAsStringSync('name: fixture\nversion: 1.0.0');
        File(p.join(tempFixtureDir.path, 'main.dart'))
            .writeAsStringSync('void main() {}');

        // 2. Create sensitive secret files
        File(p.join(tempFixtureDir.path, '.env'))
            .writeAsStringSync('API_KEY=123456');
        File(p.join(tempFixtureDir.path, 'server_secret.key'))
            .writeAsStringSync('PRIVATE_KEY');
        File(p.join(tempFixtureDir.path, 'api_credentials.json'))
            .writeAsStringSync('{"secret":"abc"}');
        File(p.join(tempFixtureDir.path, '.npmrc'))
            .writeAsStringSync('//registry.npmjs.org/:_authToken=XYZ');

        // 3. Create lockfile
        File(p.join(tempFixtureDir.path, 'pubspec.lock'))
            .writeAsStringSync('packages: {}');

        // 4. Create binary file (.png)
        File(p.join(tempFixtureDir.path, 'logo.png'))
            .writeAsBytesSync([0x89, 0x50, 0x4E, 0x47, 0x00]);

        // 5. Track files in git fixture
        Process.runSync('git', [
          'add',
          '.',
        ], workingDirectory: tempFixtureDir.path);
        Process.runSync('git', [
          'commit',
          '-m',
          'initial fixture',
        ], workingDirectory: tempFixtureDir.path);

        final result = await scanner.scanRepository(tempFixtureDir.path);
        final relativePaths = result.files.map((f) => f.relativePath).toSet();

        // Allowed files present
        expect(relativePaths, contains('README.md'));
        expect(relativePaths, contains('pubspec.yaml'));
        expect(relativePaths, contains('main.dart'));

        // Sensitive & excluded files absent
        expect(relativePaths, isNot(contains('.env')));
        expect(relativePaths, isNot(contains('server_secret.key')));
        expect(relativePaths, isNot(contains('api_credentials.json')));
        expect(relativePaths, isNot(contains('.npmrc')));
        expect(relativePaths, isNot(contains('pubspec.lock')));
        expect(relativePaths, isNot(contains('logo.png')));

        // Warning recorded
        expect(
          result.partialWarnings.any(
            (w) => w.contains('Excluded 4 sensitive/secret-bearing file(s)'),
          ),
          isTrue,
        );
      },
    );

    test('skips files exceeding maxDepth limit', () async {
      File(p.join(tempFixtureDir.path, 'README.md'))
          .writeAsStringSync('# Root');

      // Depth 5 path: a/b/c/d/e/deep.dart (5 directory levels)
      final deepDir = Directory(
        p.join(tempFixtureDir.path, 'a', 'b', 'c', 'd', 'e'),
      );
      deepDir.createSync(recursive: true);
      File(p.join(deepDir.path, 'deep.dart'))
          .writeAsStringSync('class Deep {}');

      Process.runSync('git', [
        'add',
        '.',
      ], workingDirectory: tempFixtureDir.path);
      Process.runSync('git', [
        'commit',
        '-m',
        'add deep file',
      ], workingDirectory: tempFixtureDir.path);

      final result = await scanner.scanRepository(
        tempFixtureDir.path,
        limits: const ScanLimits(maxDepth: 4),
      );

      final relativePaths = result.files.map((f) => f.relativePath).toList();
      expect(relativePaths, contains('README.md'));
      expect(relativePaths, isNot(contains('a/b/c/d/e/deep.dart')));
      expect(
        result.partialWarnings.any(
          (w) => w.contains(
            'Skipped 1 file(s) exceeding maximum traversal depth (4)',
          ),
        ),
        isTrue,
      );
    });

    test('skips oversized files exceeding maxFileSize', () async {
      File(p.join(tempFixtureDir.path, 'README.md'))
          .writeAsStringSync('# Root');

      // Create 70 KiB file
      final largeContent = 'A' * (70 * 1024);
      File(p.join(tempFixtureDir.path, 'large.txt'))
          .writeAsStringSync(largeContent);

      Process.runSync('git', [
        'add',
        '.',
      ], workingDirectory: tempFixtureDir.path);
      Process.runSync('git', [
        'commit',
        '-m',
        'add large file',
      ], workingDirectory: tempFixtureDir.path);

      final result = await scanner.scanRepository(
        tempFixtureDir.path,
        limits: const ScanLimits(maxFileSize: 64 * 1024),
      );

      final relativePaths = result.files.map((f) => f.relativePath).toList();
      expect(relativePaths, contains('README.md'));
      expect(relativePaths, isNot(contains('large.txt')));
      expect(
        result.partialWarnings.any(
          (w) => w.contains(
            'Skipped 1 file(s) exceeding maximum size bound (64 KiB)',
          ),
        ),
        isTrue,
      );
    });
  });
}
