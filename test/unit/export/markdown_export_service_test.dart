import 'package:flutter_test/flutter_test.dart';
import 'package:reposeance/features/autopsy/domain/models/autopsy_finding.dart';
import 'package:reposeance/features/autopsy/domain/models/autopsy_report.dart';
import 'package:reposeance/features/autopsy/domain/models/evidence_snapshot.dart';
import 'package:reposeance/features/export/data/markdown_export_service.dart';
import 'package:reposeance/features/export/domain/models/export_result.dart';
import 'package:reposeance/features/repository/domain/models/git_commit.dart';
import 'package:reposeance/features/repository/domain/models/repository_info.dart';
import 'package:reposeance/features/repository/domain/models/scanned_file.dart';
import 'package:reposeance/features/repository/domain/models/scan_result.dart';

import 'mocks/memory_file_saver.dart';

void main() {
  group('MarkdownExportService Unit Tests', () {
    late MarkdownExportService service;
    late MemoryFileSaver memorySaver;
    late EvidenceSnapshot testSnapshot;
    late AutopsyReport testReport;
    late RepositoryInfo testRepoInfo;
    late ScanResult testScanResult;

    setUp(() {
      memorySaver = MemoryFileSaver();
      service = MarkdownExportService(defaultSaver: memorySaver);

      testRepoInfo = const RepositoryInfo(
        rootPath: r'C:\Projects\test_repo',
        name: 'test_repo',
        currentBranch: 'main',
        headCommitHash: '48278f81234567890abcdef',
      );

      final files = [
        const ScannedFile(
          relativePath: 'pubspec.yaml',
          fullPath: r'C:\Projects\test_repo\pubspec.yaml',
          byteSize: 120,
          lineCount: 10,
          priorityTier: 1,
          contentHash: 'hash_pubspec',
          content: 'name: reposeance_test',
        ),
      ];

      final commits = [
        GitCommit(
          hash: '48278f81234567890abcdef',
          author: 'Test Author',
          date: DateTime.utc(2026, 10, 31, 12, 0),
          subject: 'feat: add export feature',
        ),
      ];

      testScanResult = ScanResult(
        repositoryInfo: testRepoInfo,
        files: files,
        commits: commits,
        scanDurationMs: 30,
        totalCandidatesEnumerated: 1,
        totalBytesRead: 120,
        partialWarnings: const [],
      );

      testSnapshot = EvidenceSnapshot.fromScanResult(
        testScanResult,
        snapshotId: 'snap-export-test',
      );

      testReport = AutopsyReport(
        snapshotId: 'snap-export-test',
        requestId: 'req-export-001',
        generatedAt: DateTime.utc(2026, 10, 31, 12, 0),
        rawModelResponse: '{}',
        latency: const Duration(milliseconds: 800),
        projectPurpose: const AutopsyFinding(
          text: 'A test project for export verification.',
          kind: FindingKind.observed,
          evidenceIds: ['E001'],
        ),
        architecture: const [
          AutopsyFinding(
            text: 'Single-package repository.',
            kind: FindingKind.observed,
            evidenceIds: ['E001'],
          ),
        ],
        findings: const [],
        revivalPlan: const [],
        unknowns: const ['No known test issues.'],
      );
    });

    test('successfully exports report bytes via file saver', () async {
      final result = await service.exportReport(
        report: testReport,
        snapshot: testSnapshot,
        repoInfo: testRepoInfo,
        scanResult: testScanResult,
        exportTimestamp: DateTime.utc(2026, 10, 31, 13, 0),
      );

      expect(result.status, equals(ExportStatus.success));
      expect(result.isSuccess, isTrue);
      expect(
        result.filePath,
        contains('test_repo_autopsy_20261031_snap-exp.md'),
      );
      expect(result.bytesWritten, greaterThan(0));

      expect(
        memorySaver.lastSavedFileName,
        equals('test_repo_autopsy_20261031_snap-exp.md'),
      );
      expect(
        memorySaver.lastSavedContent,
        contains('# RepoSéance Forensic Autopsy Report: test_repo'),
      );
      expect(
        memorySaver.lastSavedContent,
        contains('A test project for export verification. [E001]'),
      );
    });

    test('handles user cancellation gracefully without error', () async {
      memorySaver.shouldCancel = true;

      final result = await service.exportReport(
        report: testReport,
        snapshot: testSnapshot,
        repoInfo: testRepoInfo,
        scanResult: testScanResult,
      );

      expect(result.status, equals(ExportStatus.cancelled));
      expect(result.isCancelled, isTrue);
      expect(result.filePath, isNull);
      expect(result.errorMessage, isNull);
    });

    test(
      'handles recoverable I/O failure and returns failed ExportResult',
      () async {
        memorySaver.failureError = 'Permission denied writing to C:\\Exports\\';

        final result = await service.exportReport(
          report: testReport,
          snapshot: testSnapshot,
          repoInfo: testRepoInfo,
          scanResult: testScanResult,
        );

        expect(result.status, equals(ExportStatus.failed));
        expect(result.isFailed, isTrue);
        expect(result.errorMessage, contains('Permission denied'));
      },
    );

    test('generateDefaultFileName sanitizes spaces and illegal characters', () {
      final fileName = MarkdownExportService.generateDefaultFileName(
        repoName: 'My Special:Repo/Project*Name?',
        snapshotId: '1234567890abcdef',
        timestamp: DateTime.utc(2026, 10, 31),
      );

      expect(
        fileName,
        equals('My_Special_Repo_Project_Name_autopsy_20261031_12345678.md'),
      );
      expect(fileName, isNot(contains(':')));
      expect(fileName, isNot(contains('/')));
      expect(fileName, isNot(contains('*')));
      expect(fileName, isNot(contains('?')));
      expect(fileName, isNot(contains(' ')));
    });
  });
}
