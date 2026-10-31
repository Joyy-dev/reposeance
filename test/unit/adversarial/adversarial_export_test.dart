import 'package:flutter_test/flutter_test.dart';
import 'package:reposeance/features/autopsy/domain/models/autopsy_finding.dart';
import 'package:reposeance/features/autopsy/domain/models/autopsy_report.dart';
import 'package:reposeance/features/autopsy/domain/models/evidence_snapshot.dart';
import 'package:reposeance/features/autopsy/domain/models/revival_step.dart';
import 'package:reposeance/features/export/data/markdown_formatter.dart';
import 'package:reposeance/features/export/domain/models/export_options.dart';
import 'package:reposeance/features/repository/domain/models/git_commit.dart';
import 'package:reposeance/features/repository/domain/models/repository_info.dart';
import 'package:reposeance/features/repository/domain/models/scan_result.dart';
import 'package:reposeance/features/repository/domain/models/scanned_file.dart';

void main() {
  group('Adversarial Export Sanitization & Formatting Suite', () {
    late MarkdownFormatter formatter;
    late EvidenceSnapshot testSnapshot;
    late AutopsyReport testReport;
    late RepositoryInfo testRepoInfo;
    late ScanResult testScanResult;

    setUp(() {
      formatter = const MarkdownFormatter();

      testRepoInfo = const RepositoryInfo(
        rootPath: r'C:\Users\joyce\Projects\hostile_repo',
        name: 'hostile_repo',
        currentBranch: 'main',
        headCommitHash: '1a68fcf68e3207264d1441d866850e4ed33410fb',
      );

      final files = [
        const ScannedFile(
          relativePath: 'pubspec.yaml',
          fullPath: r'C:\Users\joyce\Projects\hostile_repo\pubspec.yaml',
          byteSize: 120,
          lineCount: 8,
          priorityTier: 1,
          contentHash: 'hash_pubspec',
          content: 'name: hostile_repo\n',
        ),
      ];

      final commits = [
        GitCommit(
          hash: 'c1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0',
          author: 'Joyce Ava <joyce@example.com>',
          date: DateTime.parse('2026-10-31T10:00:00Z'),
          subject: 'feat: add feature | with hostile | table pipes | and `backticks`',
        ),
      ];

      testScanResult = ScanResult(
        repositoryInfo: testRepoInfo,
        files: files,
        commits: commits,
        totalCandidatesEnumerated: 1,
        totalBytesRead: 120,
        scanDurationMs: 40,
      );

      testSnapshot = EvidenceSnapshot.fromScanResult(testScanResult);

      testReport = AutopsyReport(
        snapshotId: testSnapshot.snapshotId,
        requestId: 'req_adv_export',
        projectPurpose: const AutopsyFinding(
          text: 'Contains path C:\\Users\\joyce\\AppData\\Local\\secret and Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.e30.secret',
          kind: FindingKind.observed,
          evidenceIds: ['E001'],
        ),
        architecture: const [
          AutopsyFinding(
            text: 'Architecture stores API key: ghp_1234567890abcdefghijklmnopqrstuvwxyz12',
            kind: FindingKind.observed,
            evidenceIds: ['E001'],
          ),
        ],
        findings: const [
          AutopsyFinding(
            text: 'Found private block:\n-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASC\n-----END PRIVATE KEY-----',
            kind: FindingKind.observed,
            evidenceIds: ['E001'],
          ),
        ],
        revivalPlan: const [
          RevivalStep(
            step: 'Sanitize all credentials.',
            reason: AutopsyFinding(
              text: 'Credentials leaked in repository findings.',
              kind: FindingKind.inferred,
              evidenceIds: ['E001'],
            ),
          ),
        ],
        unknowns: const [
          'Unknown whether other personal paths exist under C:\\Users\\joyce\\Documents',
        ],
        generatedAt: DateTime.parse('2026-10-31T10:00:00Z'),
        rawModelResponse: '{}',
        latency: const Duration(seconds: 1),
      );
    });

    test('redacts personal Windows home paths (C:\\Users\\joyce) from exported Markdown', () {
      final markdown = formatter.format(
        report: testReport,
        snapshot: testSnapshot,
        repoInfo: testRepoInfo,
        scanResult: testScanResult,
        options: const ExportOptions(),
      );

      // Must NOT contain personal host username path
      expect(
        markdown,
        isNot(contains(r'C:\Users\joyce\Projects\hostile_repo')),
      );
      expect(markdown, isNot(contains(r'C:\Users\joyce\AppData')));
      expect(markdown, isNot(contains(r'C:\Users\joyce\Documents')));

      // Must contain sanitized relative or tilde path representation
      expect(markdown, contains('<user-home>/'));
    });

    test('scrubs Bearer tokens and GitHub-style secret keys from findings and revival plan', () {
      final markdown = formatter.format(
        report: testReport,
        snapshot: testSnapshot,
        repoInfo: testRepoInfo,
        scanResult: testScanResult,
        options: const ExportOptions(),
      );

      // Bearer token must be redacted
      expect(markdown, isNot(contains('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9')));
      expect(markdown, contains('[REDACTED_SECRET]'));

      // Secret API key must be redacted
      expect(
        markdown,
        isNot(contains('ghp_1234567890abcdefghijklmnopqrstuvwxyz12')),
      );
      expect(markdown, contains('ghp_[REDACTED]'));

      // Private key header must be redacted
      expect(markdown, isNot(contains('-----BEGIN PRIVATE KEY-----')));
      expect(markdown, contains('[REDACTED_PRIVATE_KEY]'));
    });

    test('escapes table pipe characters in commit subjects to preserve Markdown table integrity', () {
      final markdown = formatter.format(
        report: testReport,
        snapshot: testSnapshot,
        repoInfo: testRepoInfo,
        scanResult: testScanResult,
        options: const ExportOptions(),
      );

      // Commit subject table row must escape pipes: \| instead of breaking columns
      expect(markdown, contains(r'\| with hostile \| table pipes \|'));
    });
  });
}
