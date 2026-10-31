import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:reposeance/features/repository/data/repository_scanner.dart';
import 'package:reposeance/features/repository/domain/models/scan_limits.dart';

void main() {
  group('Adversarial Repository Scanner Suite', () {
    late Directory tempFixtureDir;
    late RepositoryScanner scanner;

    setUp(() {
      scanner = RepositoryScanner();
      tempFixtureDir = Directory.systemTemp.createTempSync('adv_scanner_');
      Process.runSync('git', ['init'], workingDirectory: tempFixtureDir.path);
      Process.runSync('git', [
        'config',
        'user.name',
        'SecurityTester',
      ], workingDirectory: tempFixtureDir.path);
      Process.runSync('git', [
        'config',
        'user.email',
        'security@test.com',
      ], workingDirectory: tempFixtureDir.path);
    });

    tearDown(() {
      try {
        tempFixtureDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test(
      'excludes disguised binary files containing null bytes in .txt file',
      () async {
        // Create legitimate files
        File(p.join(tempFixtureDir.path, 'README.md'))
            .writeAsStringSync('# Test Project');
        File(p.join(tempFixtureDir.path, 'pubspec.yaml'))
            .writeAsStringSync('name: test_project\n');

        // Create a disguised binary file masked with .txt extension containing null byte
        final disguisedBinaryBytes = [
          0x54, 0x68, 0x69, 0x73, 0x20, 0x69, 0x73, 0x20,
          0x74, 0x65, 0x78, 0x74, 0x00, 0x42, 0x49, 0x4E, // 0x00 is null byte
        ];
        File(p.join(tempFixtureDir.path, 'fake_notes.txt'))
            .writeAsBytesSync(disguisedBinaryBytes);

        Process.runSync('git', [
          'add',
          '.',
        ], workingDirectory: tempFixtureDir.path);
        Process.runSync('git', [
          'commit',
          '-m',
          'fixture',
        ], workingDirectory: tempFixtureDir.path);

        final result = await scanner.scanRepository(tempFixtureDir.path);

        final scannedPaths = result.files.map((f) => f.relativePath).toList();
        expect(scannedPaths, contains('README.md'));
        expect(scannedPaths, contains('pubspec.yaml'));
        expect(scannedPaths, isNot(contains('fake_notes.txt')));
      },
    );

    test(
      'excludes sensitive credential variants (.env, .pem, .key, id_rsa)',
      () async {
        File(p.join(tempFixtureDir.path, 'README.md'))
            .writeAsStringSync('# Safe Readme');
        File(p.join(tempFixtureDir.path, 'prod.env'))
            .writeAsStringSync('DB_PASSWORD=secret');
        File(p.join(tempFixtureDir.path, 'id_rsa'))
            .writeAsStringSync('-----BEGIN RSA PRIVATE KEY-----');
        File(p.join(tempFixtureDir.path, 'tls_cert.pem'))
            .writeAsStringSync('-----BEGIN CERTIFICATE-----');
        File(p.join(tempFixtureDir.path, 'oauth_credentials.json'))
            .writeAsStringSync('{"client_secret": "xyz"}');

        Process.runSync('git', [
          'add',
          '.',
        ], workingDirectory: tempFixtureDir.path);
        Process.runSync('git', [
          'commit',
          '-m',
          'credentials fixture',
        ], workingDirectory: tempFixtureDir.path);

        final result = await scanner.scanRepository(tempFixtureDir.path);

        final scannedPaths = result.files.map((f) => f.relativePath).toList();
        expect(scannedPaths, contains('README.md'));
        expect(scannedPaths, isNot(contains('prod.env')));
        expect(scannedPaths, isNot(contains('id_rsa')));
        expect(scannedPaths, isNot(contains('tls_cert.pem')));
        expect(scannedPaths, isNot(contains('oauth_credentials.json')));
      },
    );

    test('enforces maxFileSize limit and skips oversized text files with partial warning', () async {
      File(p.join(tempFixtureDir.path, 'README.md'))
          .writeAsStringSync('# Small File');

      // Create an oversized file exceeding 10KB under tight limit
      final largeContent = 'A' * 20000;
      File(p.join(tempFixtureDir.path, 'large_dump.txt'))
          .writeAsStringSync(largeContent);

      Process.runSync('git', [
        'add',
        '.',
      ], workingDirectory: tempFixtureDir.path);
      Process.runSync('git', [
        'commit',
        '-m',
        'oversized fixture',
      ], workingDirectory: tempFixtureDir.path);

      const tightLimits = ScanLimits(maxFileSize: 10000);
      final result = await scanner.scanRepository(
        tempFixtureDir.path,
        limits: tightLimits,
      );

      final scannedPaths = result.files.map((f) => f.relativePath).toList();
      expect(scannedPaths, contains('README.md'));
      expect(scannedPaths, isNot(contains('large_dump.txt')));
      expect(result.isPartial, isTrue);
      expect(
        result.partialWarnings.any(
          (w) => w.contains('exceeding maximum size bound'),
        ),
        isTrue,
      );
    });

    test(
      'enforces maxDepth limit to prevent deeply nested traversal attacks',
      () async {
        File(p.join(tempFixtureDir.path, 'README.md'))
            .writeAsStringSync('# Root');

        // Create deeply nested structure: d1/d2/d3/d4/d5/deep.dart
        final deepDir = Directory(
          p.join(tempFixtureDir.path, 'd1', 'd2', 'd3', 'd4', 'd5'),
        );
        deepDir.createSync(recursive: true);
        File(p.join(deepDir.path, 'deep.dart'))
            .writeAsStringSync('void deep() {}');

        Process.runSync('git', [
          'add',
          '.',
        ], workingDirectory: tempFixtureDir.path);
        Process.runSync('git', [
          'commit',
          '-m',
          'deep fixture',
        ], workingDirectory: tempFixtureDir.path);

        const depthLimit = ScanLimits(maxDepth: 3);
        final result = await scanner.scanRepository(
          tempFixtureDir.path,
          limits: depthLimit,
        );

        final scannedPaths = result.files.map((f) => f.relativePath).toList();
        expect(scannedPaths, contains('README.md'));
        expect(
          scannedPaths,
          isNot(contains(p.join('d1', 'd2', 'd3', 'd4', 'd5', 'deep.dart'))),
        );
        expect(result.isPartial, isTrue);
      },
    );
  });
}
