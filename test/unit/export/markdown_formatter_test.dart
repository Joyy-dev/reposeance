import 'package:flutter_test/flutter_test.dart';
import 'package:reposeance/features/autopsy/domain/models/autopsy_finding.dart';
import 'package:reposeance/features/autopsy/domain/models/autopsy_report.dart';
import 'package:reposeance/features/autopsy/domain/models/evidence_snapshot.dart';
import 'package:reposeance/features/autopsy/domain/models/revival_step.dart';
import 'package:reposeance/features/export/data/markdown_formatter.dart';
import 'package:reposeance/features/export/domain/models/export_options.dart';
import 'package:reposeance/features/ghost_qa/domain/models/ghost_answer.dart';
import 'package:reposeance/features/ghost_qa/domain/models/ghost_question.dart';
import 'package:reposeance/features/repository/domain/models/git_commit.dart';
import 'package:reposeance/features/repository/domain/models/repository_info.dart';
import 'package:reposeance/features/repository/domain/models/scanned_file.dart';
import 'package:reposeance/features/repository/domain/models/scan_result.dart';

void main() {
  group('MarkdownFormatter Unit Tests', () {
    late MarkdownFormatter formatter;
    late EvidenceSnapshot testSnapshot;
    late AutopsyReport testReport;
    late RepositoryInfo testRepoInfo;
    late ScanResult testScanResult;

    setUp(() {
      formatter = const MarkdownFormatter();

      testRepoInfo = const RepositoryInfo(
        rootPath: r'C:\Users\joyce\Projects\forgotten_inventory',
        name: 'forgotten_inventory',
        currentBranch: 'main',
        headCommitHash: '1a68fcf68e3207264d1441d866850e4ed33410fb',
      );

      final files = [
        const ScannedFile(
          relativePath: 'pubspec.yaml',
          fullPath: r'C:\Users\joyce\Projects\forgotten_inventory\pubspec.yaml',
          byteSize: 250,
          lineCount: 15,
          priorityTier: 1,
          contentHash: 'hash_pubspec_123',
          content: 'name: forgotten_inventory\ndependencies:\n  flutter:\n    sdk: flutter\n  sqflite: ^2.0.0',
        ),
        const ScannedFile(
          relativePath: 'README.md',
          fullPath: r'C:\Users\joyce\Projects\forgotten_inventory\README.md',
          byteSize: 180,
          lineCount: 10,
          priorityTier: 1,
          contentHash: 'hash_readme_456',
          content: '# Forgotten Inventory\nOffline stock taking utility using SQLite.',
        ),
      ];

      final commits = [
        GitCommit(
          hash: '1a68fcf68e3207264d1441d866850e4ed33410fb',
          author: 'Alice Developer',
          date: DateTime.utc(2026, 10, 31, 7, 7),
          subject: 'feat: initial database and scanner setup',
        ),
      ];

      testScanResult = ScanResult(
        repositoryInfo: testRepoInfo,
        files: files,
        commits: commits,
        scanDurationMs: 45,
        totalCandidatesEnumerated: 2,
        totalBytesRead: 430,
        partialWarnings: const [],
      );

      testSnapshot = EvidenceSnapshot.fromScanResult(
        testScanResult,
        snapshotId: 'snap-test-001',
      );

      testReport = AutopsyReport(
        snapshotId: 'snap-test-001',
        requestId: 'req-001',
        generatedAt: DateTime.utc(2026, 10, 31, 12, 0),
        rawModelResponse: '{}',
        latency: const Duration(milliseconds: 1200),
        projectPurpose: const AutopsyFinding(
          text: 'An offline tool for stocktaking in hardware warehouses.',
          kind: FindingKind.observed,
          evidenceIds: ['E001', 'E002'],
        ),
        architecture: const [
          AutopsyFinding(
            text: 'Utilizes SQLite for persistent offline storage via sqflite.',
            kind: FindingKind.observed,
            evidenceIds: ['E001'],
          ),
          AutopsyFinding(
            text: 'May have been planned for cloud sync based on dormant code.',
            kind: FindingKind.inferred,
            evidenceIds: ['E002'],
          ),
        ],
        findings: const [
          AutopsyFinding(
            text: 'pubspec.yaml declares sqflite and flutter dependencies.',
            kind: FindingKind.observed,
            evidenceIds: ['E001'],
          ),
          AutopsyFinding(
            text:
                'Scaffold and database initialization added in commit history.',
            kind: FindingKind.observed,
            evidenceIds: ['E051'],
          ),
        ],
        revivalPlan: const [
          RevivalStep(
            step: 'Verify database schema migrations and run tests.',
            reason: AutopsyFinding(
              text: 'Database is core to offline operations.',
              kind: FindingKind.inferred,
              evidenceIds: ['E001'],
            ),
          ),
        ],
        unknowns: const [
          'No remote API or cloud credentials present in evidence.',
        ],
      );
    });

    test(
      'generates expected markdown with all required sections and metadata',
      () {
        final md = formatter.format(
          report: testReport,
          snapshot: testSnapshot,
          repoInfo: testRepoInfo,
          scanResult: testScanResult,
          exportTimestamp: DateTime.utc(2026, 10, 31, 13, 0),
        );

        // Verify Title and Notice
        expect(
          md,
          contains('# RepoSéance Forensic Autopsy Report: forgotten_inventory'),
        );
        expect(
          md,
          contains('Forensic archaeological analysis generated locally'),
        );

        // Verify Metadata Table
        expect(
          md,
          contains('| **Target Repository** | `forgotten_inventory` |'),
        );
        expect(md, contains('| **Active Branch** | `main` |'));
        expect(
          md,
          contains(
            '| **HEAD Commit** | `1a68fcf68e3207264d1441d866850e4ed33410fb` |',
          ),
        );
        expect(md, contains('| **Snapshot ID** | `snap-test-001` |'));
        expect(
          md,
          contains(
            '| **Local AI Engine** | `gemma4:e2b (Ollama loopback 127.0.0.1:11434, CPU)` |',
          ),
        );
        expect(
          md,
          contains('| **Analysis Timestamp** | `2026-10-31T13:00:00.000Z` |'),
        );

        // Verify Sections
        expect(md, contains('## 1. Project Purpose'));
        expect(
          md,
          contains(
            '**[Observed]** An offline tool for stocktaking in hardware warehouses. [E001, E002]',
          ),
        );

        expect(md, contains('## 2. Architecture Overview'));
        expect(
          md,
          contains(
            '**[Observed]** Utilizes SQLite for persistent offline storage via sqflite. [E001]',
          ),
        );
        expect(
          md,
          contains(
            '**[Inferred]** May have been planned for cloud sync based on dormant code. [E002]',
          ),
        );

        expect(md, contains('## 3. What the Evidence Says'));
        expect(
          md,
          contains(
            '**[Observed]** pubspec.yaml declares sqflite and flutter dependencies. [E001]',
          ),
        );

        expect(md, contains('## 4. Inspected Recent Commit Timeline'));
        expect(
          md,
          contains(
            '| `1a68fcf` | 2026-10-31 | `Alice Developer` | feat: initial database and scanner setup |',
          ),
        );

        expect(md, contains('## 5. Recommended Revival Plan'));
        expect(
          md,
          contains(
            '### Step 1: Verify database schema migrations and run tests.',
          ),
        );
        expect(
          md,
          contains(
            '**Grounded Reason**: **[Inferred]** Database is core to offline operations. [E001]',
          ),
        );

        expect(md, contains('## 6. Forensic Unknowns & Limitations'));
        expect(
          md,
          contains('No remote API or cloud credentials present in evidence.'),
        );

        // Verify Evidence Ledger
        expect(md, contains('## 8. Evidence Ledger & Provenance Map'));
        expect(md, contains('### Evidence Item `[E001]` — `pubspec.yaml`'));
        expect(md, contains('- **SHA-256 Provenance**: `hash_pubspec_123`'));
        expect(md, contains('### Evidence Item `[E002]` — `README.md`'));
        expect(md, contains('### Evidence Item `[E051]` — Commit `1a68fcf`'));
        expect(md, contains('- **Author**: `Alice Developer`'));
      },
    );

    test(
      'includes Ask the Ghost Q&A when question and answer are provided',
      () {
        final question = GhostQuestion(
          text: 'What database package is used?',
          askedAt: DateTime.utc(2026, 10, 31, 13, 5),
        );

        final answer = GhostAnswer(
          notFound: false,
          claims: const [
            AutopsyFinding(
              text: 'The application uses the sqflite package for local SQLite operations.',
              kind: FindingKind.observed,
              evidenceIds: ['E001'],
            ),
          ],
          missingEvidence: '',
          answeredAt: DateTime.utc(2026, 10, 31, 13, 5),
          latency: const Duration(seconds: 45),
          promptEvalCount: 300,
          evalCount: 80,
        );

        final md = formatter.format(
          report: testReport,
          snapshot: testSnapshot,
          repoInfo: testRepoInfo,
          scanResult: testScanResult,
          ghostQuestion: question,
          ghostAnswer: answer,
          options: const ExportOptions(includeGhostQa: true),
        );

        expect(md, contains('## 7. Ask the Ghost Q&A Inquiries'));
        expect(md, contains('**Question**: "What database package is used?"'));
        expect(
          md,
          contains(
            '**[Observed]**: The application uses the sqflite package for local SQLite operations. [E001]',
          ),
        );
      },
    );

    test('formats honest missing evidence when Q&A not_found is true', () {
      final question = GhostQuestion(
        text: 'Why did the author stop working on the project?',
        askedAt: DateTime.utc(2026, 10, 31, 13, 6),
      );

      final answer = GhostAnswer(
        notFound: true,
        claims: const [],
        missingEvidence: 'The repository commits and README do not contain recorded reasons for project cessation.',
        answeredAt: DateTime.utc(2026, 10, 31, 13, 6),
        latency: const Duration(seconds: 15),
        promptEvalCount: 250,
        evalCount: 40,
      );

      final md = formatter.format(
        report: testReport,
        snapshot: testSnapshot,
        repoInfo: testRepoInfo,
        scanResult: testScanResult,
        ghostQuestion: question,
        ghostAnswer: answer,
        options: const ExportOptions(includeGhostQa: true),
      );

      expect(md, contains('## 7. Ask the Ghost Q&A Inquiries'));
      expect(
        md,
        contains('Epistemic Classification: Not Found / Missing Evidence'),
      );
      expect(
        md,
        contains(
          'The repository commits and README do not contain recorded reasons',
        ),
      );
    });

    test('excludes Q&A section when includeGhostQa option is false', () {
      final question = GhostQuestion(
        text: 'What database package is used?',
        askedAt: DateTime.utc(2026, 10, 31, 13, 5),
      );

      final answer = GhostAnswer(
        notFound: false,
        claims: const [
          AutopsyFinding(
            text: 'The application uses the sqflite package.',
            kind: FindingKind.observed,
            evidenceIds: ['E001'],
          ),
        ],
        missingEvidence: '',
        answeredAt: DateTime.utc(2026, 10, 31, 13, 5),
        latency: const Duration(seconds: 45),
        promptEvalCount: 300,
        evalCount: 80,
      );

      final md = formatter.format(
        report: testReport,
        snapshot: testSnapshot,
        repoInfo: testRepoInfo,
        scanResult: testScanResult,
        ghostQuestion: question,
        ghostAnswer: answer,
        options: const ExportOptions(includeGhostQa: false),
      );

      expect(md, isNot(contains('## 7. Ask the Ghost Q&A Inquiries')));
    });

    test(
      'scrubs personal Windows home directory paths and repository root',
      () {
        const personalPath =
            r'C:\Users\joyce\SecretProjects\forgotten_inventory\lib\main.dart';
        final sanitized = MarkdownFormatter.sanitizePath(
          personalPath,
          r'C:\Users\joyce\SecretProjects\forgotten_inventory',
        );

        expect(sanitized, isNot(contains('joyce')));
        expect(sanitized, isNot(contains(r'C:\Users\joyce')));
        expect(sanitized, contains('<repo-root>'));
      },
    );

    test('scrubs tokens, API keys, and private keys from excerpts', () {
      const rawText = '''
Authorization: Bearer secret_token_123456789
API_KEY="AIzaSyA1234567890abcdef"
ghp_1234567890abcdef1234567890abcdef123456
-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEAz...
-----END RSA PRIVATE KEY-----
''';

      final sanitized = MarkdownFormatter.sanitizeCredentials(rawText);

      expect(sanitized, isNot(contains('secret_token_123456789')));
      expect(sanitized, isNot(contains('AIzaSyA1234567890abcdef')));
      expect(
        sanitized,
        isNot(contains('ghp_1234567890abcdef1234567890abcdef123456')),
      );
      expect(sanitized, isNot(contains('MIIEowIBAAKCAQEAz')));

      expect(sanitized, contains('[REDACTED_SECRET]'));
      expect(sanitized, contains('ghp_[REDACTED]'));
      expect(sanitized, contains('[REDACTED_PRIVATE_KEY]'));
    });

    test('escapes table pipes correctly', () {
      const hostileTableText = 'Feature | A pipe | in commit';
      final escaped = MarkdownFormatter.escapeTable(hostileTableText);
      expect(escaped, equals(r'Feature \| A pipe \| in commit'));
    });
  });
}
