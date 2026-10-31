import 'package:flutter_test/flutter_test.dart';
import 'package:reposeance/features/autopsy/domain/models/autopsy_finding.dart';
import 'package:reposeance/features/autopsy/domain/models/autopsy_report.dart';
import 'package:reposeance/features/autopsy/domain/models/evidence_snapshot.dart';
import 'package:reposeance/features/autopsy/domain/models/revival_step.dart';
import 'package:reposeance/features/export/data/markdown_formatter.dart';
import 'package:reposeance/features/ghost_qa/domain/models/ghost_answer.dart';
import 'package:reposeance/features/ghost_qa/domain/models/ghost_question.dart';
import 'package:reposeance/features/repository/domain/models/git_commit.dart';
import 'package:reposeance/features/repository/domain/models/repository_info.dart';
import 'package:reposeance/features/repository/domain/models/scanned_file.dart';
import 'package:reposeance/features/repository/domain/models/scan_result.dart';

void main() {
  group('Golden Deterministic Markdown Export Test', () {
    test('produces bit-for-bit deterministic golden report matching contract', () {
      const formatter = MarkdownFormatter();

      const repoInfo = RepositoryInfo(
        rootPath:
            r'C:\Users\joyce\OneDrive\Desktop\project\forgotten_inventory',
        name: 'forgotten_inventory',
        currentBranch: 'main',
        headCommitHash: 'be72cfa0d8294439b812b7197d76c332c6c52287',
      );

      final files = [
        const ScannedFile(
          relativePath: 'pubspec.yaml',
          fullPath: r'C:\Users\joyce\OneDrive\Desktop\project\forgotten_inventory\pubspec.yaml',
          byteSize: 150,
          lineCount: 12,
          priorityTier: 1,
          contentHash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          content: 'name: forgotten_inventory\nversion: 0.1.0\ndependencies:\n  flutter:\n    sdk: flutter\n  sqflite: ^2.0.0',
        ),
      ];

      final commits = [
        GitCommit(
          hash: 'be72cfa0d8294439b812b7197d76c332c6c52287',
          author: 'Joyce Developer',
          date: DateTime.utc(2026, 10, 31, 6, 24),
          subject: 'feat: initial RepoSéance Windows desktop scaffold',
        ),
      ];

      final scanResult = ScanResult(
        repositoryInfo: repoInfo,
        files: files,
        commits: commits,
        scanDurationMs: 15,
        totalCandidatesEnumerated: 1,
        totalBytesRead: 150,
        partialWarnings: const [],
      );

      final snapshot = EvidenceSnapshot.fromScanResult(
        scanResult,
        snapshotId: 'golden-snap-001',
      );

      final report = AutopsyReport(
        snapshotId: 'golden-snap-001',
        requestId: 'golden-req-001',
        generatedAt: DateTime.utc(2026, 10, 31, 13, 0),
        rawModelResponse: '{}',
        latency: const Duration(milliseconds: 1500),
        projectPurpose: const AutopsyFinding(
          text: 'An offline inventory management utility.',
          kind: FindingKind.observed,
          evidenceIds: ['E001'],
        ),
        architecture: const [
          AutopsyFinding(
            text: 'Structured as a Flutter desktop app utilizing SQLite.',
            kind: FindingKind.observed,
            evidenceIds: ['E001'],
          ),
        ],
        findings: const [
          AutopsyFinding(
            text: 'pubspec.yaml specifies dependencies and assets.',
            kind: FindingKind.observed,
            evidenceIds: ['E001'],
          ),
          AutopsyFinding(
            text: 'Scaffold committed with SQLite dependencies.',
            kind: FindingKind.observed,
            evidenceIds: ['E051'],
          ),
        ],
        revivalPlan: const [
          RevivalStep(
            step: 'Run flutter pub get and execute unit tests.',
            reason: AutopsyFinding(
              text: 'Ensures dependencies resolve cleanly.',
              kind: FindingKind.inferred,
              evidenceIds: ['E001'],
            ),
          ),
        ],
        unknowns: const [
          'No remote API sync endpoints documented in repository.',
        ],
      );

      final question = GhostQuestion(
        text: 'What database package is declared in pubspec.yaml?',
        askedAt: DateTime.utc(2026, 10, 31, 13, 0),
      );

      final answer = GhostAnswer(
        notFound: false,
        claims: const [
          AutopsyFinding(
            text: 'The sqflite package is declared under dependencies.',
            kind: FindingKind.observed,
            evidenceIds: ['E001'],
          ),
        ],
        missingEvidence: '',
        answeredAt: DateTime.utc(2026, 10, 31, 13, 0),
        latency: const Duration(seconds: 40),
        promptEvalCount: 280,
        evalCount: 60,
      );

      final output1 = formatter.format(
        report: report,
        snapshot: snapshot,
        repoInfo: repoInfo,
        scanResult: scanResult,
        ghostQuestion: question,
        ghostAnswer: answer,
        exportTimestamp: DateTime.utc(2026, 10, 31, 13, 30),
      );

      final output2 = formatter.format(
        report: report,
        snapshot: snapshot,
        repoInfo: repoInfo,
        scanResult: scanResult,
        ghostQuestion: question,
        ghostAnswer: answer,
        exportTimestamp: DateTime.utc(2026, 10, 31, 13, 30),
      );

      // Verify strict determinism: identical inputs yield identical outputs
      expect(output1, equals(output2));

      // Golden contract checks:
      // 1. Zero personal paths
      expect(output1, isNot(contains(r'C:\Users\joyce')));
      expect(output1, isNot(contains('OneDrive')));

      // 2. Exact metadata properties
      expect(
        output1,
        contains('| **Target Repository** | `forgotten_inventory` |'),
      );
      expect(output1, contains('| **Active Branch** | `main` |'));
      expect(
        output1,
        contains(
          '| **HEAD Commit** | `be72cfa0d8294439b812b7197d76c332c6c52287` |',
        ),
      );
      expect(output1, contains('| **Snapshot ID** | `golden-snap-001` |'));
      expect(
        output1,
        contains(
          '| **Local AI Engine** | `gemma4:e2b (Ollama loopback 127.0.0.1:11434, CPU)` |',
        ),
      );
      expect(
        output1,
        contains('| **Analysis Timestamp** | `2026-10-31T13:30:00.000Z` |'),
      );

      // 3. Evidence citations in sections
      expect(
        output1,
        contains(
          '**[Observed]** An offline inventory management utility. [E001]',
        ),
      );
      expect(
        output1,
        contains(
          '**[Observed]** Structured as a Flutter desktop app utilizing SQLite. [E001]',
        ),
      );
      expect(
        output1,
        contains(
          '**Grounded Reason**: **[Inferred]** Ensures dependencies resolve cleanly. [E001]',
        ),
      );

      // 4. Q&A
      expect(output1, contains('## 7. Ask the Ghost Q&A Inquiries'));
      expect(
        output1,
        contains(
          '**Question**: "What database package is declared in pubspec.yaml?"',
        ),
      );
      expect(
        output1,
        contains(
          '**[Observed]**: The sqflite package is declared under dependencies. [E001]',
        ),
      );

      // 5. Evidence Ledger
      expect(output1, contains('## 8. Evidence Ledger & Provenance Map'));
      expect(output1, contains('### Evidence Item `[E001]` — `pubspec.yaml`'));
      expect(
        output1,
        contains(
          '- **SHA-256 Provenance**: `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`',
        ),
      );
      expect(
        output1,
        contains('### Evidence Item `[E051]` — Commit `be72cfa`'),
      );
      expect(
        output1,
        contains('feat: initial RepoSéance Windows desktop scaffold'),
      );
    });
  });
}
