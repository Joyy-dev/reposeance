import 'package:flutter_test/flutter_test.dart';
import 'package:reposeance/features/autopsy/domain/models/evidence_item.dart';
import 'package:reposeance/features/autopsy/domain/models/evidence_request_map.dart';
import 'package:reposeance/features/autopsy/domain/models/evidence_snapshot.dart';
import 'package:reposeance/features/repository/domain/models/git_commit.dart';
import 'package:reposeance/features/repository/domain/models/repository_info.dart';
import 'package:reposeance/features/repository/domain/models/scan_result.dart';
import 'package:reposeance/features/repository/domain/models/scanned_file.dart';

void main() {
  group('EvidenceSnapshot & Tagged Union Tests', () {
    late ScanResult mockScanResult;

    setUp(() {
      final repoInfo = RepositoryInfo(
        rootPath: r'C:\mock\repo',
        name: 'repo',
        currentBranch: 'main',
        isDetachedHead: false,
        isEmpty: false,
      );

      final files = [
        ScannedFile(
          relativePath: 'pubspec.yaml',
          fullPath: r'C:\mock\repo\pubspec.yaml',
          byteSize: 120,
          lineCount: 10,
          priorityTier: 1,
          contentHash: 'hash_pubspec',
          content: 'name: mock_app\nversion: 1.0.0\n',
        ),
        ScannedFile(
          relativePath: 'README.md',
          fullPath: r'C:\mock\repo\README.md',
          byteSize: 250,
          lineCount: 15,
          priorityTier: 0,
          contentHash: 'hash_readme',
          content: '# Mock App\nDocumentation\n',
        ),
      ];

      final commits = [
        GitCommit(
          hash: 'c1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0',
          author: 'dev',
          date: DateTime.parse('2026-10-31T10:00:00Z'),
          subject: 'initial commit',
        ),
      ];

      mockScanResult = ScanResult(
        repositoryInfo: repoInfo,
        files: files,
        commits: commits,
        scanDurationMs: 50,
        totalCandidatesEnumerated: 2,
        totalBytesRead: 370,
      );
    });

    test(
      'deterministic evidence ID assignment and tagged union separation',
      () {
        final snapshot = EvidenceSnapshot.fromScanResult(
          mockScanResult,
          snapshotId: 'snap_test_1',
        );

        expect(snapshot.snapshotId, equals('snap_test_1'));
        expect(snapshot.repositoryRoot, equals(r'C:\mock\repo'));
        expect(
          snapshot.headCommit,
          equals('c1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0'),
        );

        // File IDs must be E001, E002
        expect(snapshot.hasEvidence('E001'), isTrue);
        expect(snapshot.hasEvidence('E002'), isTrue);

        final fileE1 = snapshot.getEvidence('E001');
        expect(fileE1, isA<FileEvidence>());
        final fe = fileE1 as FileEvidence;
        expect(fe.type, equals(EvidenceType.file));
        expect(fe.repositoryRelativePath, equals('pubspec.yaml'));
        expect(fe.contentHash, equals('hash_pubspec'));
        expect(fe.startLine, equals(1));
        expect(fe.endLine, equals(10));

        // Commit IDs start at E051
        expect(snapshot.hasEvidence('E051'), isTrue);
        final commitE51 = snapshot.getEvidence('E051');
        expect(commitE51, isA<CommitEvidence>());
        final ce = commitE51 as CommitEvidence;
        expect(ce.type, equals(EvidenceType.commit));
        expect(
          ce.commitHash,
          equals('c1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0'),
        );
        expect(ce.subject, equals('initial commit'));
        expect(ce.author, equals('dev'));

        // Evidence map must be unmodifiable
        expect(() => snapshot.evidenceMap['E999'] = fe, throwsUnsupportedError);
      },
    );

    test('EvidenceRequestMap validates allowed IDs strictly', () {
      final requestMap = EvidenceRequestMap(
        requestId: 'req_123',
        snapshotId: 'snap_1',
        suppliedEvidenceIds: {'E001', 'E002', 'E051'},
      );

      expect(requestMap.isAllowed('E001'), isTrue);
      expect(requestMap.isAllowed('E002'), isTrue);
      expect(requestMap.isAllowed('E051'), isTrue);

      // Unsupplied or unknown IDs must be rejected
      expect(requestMap.isAllowed('E999'), isFalse);
      expect(requestMap.isAllowed('E003'), isFalse);
      expect(requestMap.isAllowed('E-FILE-001'), isFalse);

      expect(requestMap.allowedIdsSorted, equals(['E001', 'E002', 'E051']));
      expect(
        () => requestMap.suppliedEvidenceIds.add('E999'),
        throwsUnsupportedError,
      );
    });
  });
}
