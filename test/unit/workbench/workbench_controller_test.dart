import 'package:flutter_test/flutter_test.dart';
import 'package:reposeance/core/services/ollama_service.dart';
import 'package:reposeance/core/utils/git_checker.dart';
import 'package:reposeance/features/autopsy/data/autopsy_service.dart';
import 'package:reposeance/features/autopsy/domain/models/autopsy_finding.dart';
import 'package:reposeance/features/autopsy/domain/models/autopsy_report.dart';
import 'package:reposeance/features/autopsy/domain/models/evidence_item.dart';
import 'package:reposeance/features/autopsy/domain/models/evidence_snapshot.dart';
import 'package:reposeance/features/autopsy/domain/models/revival_step.dart';
import 'package:reposeance/features/export/domain/models/export_result.dart';
import 'package:reposeance/features/ghost_qa/data/ghost_qa_service.dart';
import 'package:reposeance/features/ghost_qa/domain/models/ghost_answer.dart';

import '../export/mocks/memory_file_saver.dart';

import 'package:reposeance/features/repository/data/git_service.dart';
import 'package:reposeance/features/repository/data/repository_scanner.dart';
import 'package:reposeance/features/repository/domain/models/git_commit.dart';
import 'package:reposeance/features/repository/domain/models/repository_info.dart';
import 'package:reposeance/features/repository/domain/models/scan_limits.dart';
import 'package:reposeance/features/repository/domain/models/scan_result.dart';
import 'package:reposeance/features/repository/domain/models/scanned_file.dart';
import 'package:reposeance/features/workbench/controllers/workbench_controller.dart';
import 'package:reposeance/features/workbench/domain/models/workbench_state.dart';

// --- Fakes for Testing ---

class FakeGitService extends GitService {
  GitRootResult rootResultToReturn;
  RepositoryInfo? repoInfoToReturn;
  List<GitCommit> commitsToReturn;

  FakeGitService({
    this.rootResultToReturn = const GitRootSuccess(r'C:\mock\repo'),
    this.repoInfoToReturn,
    this.commitsToReturn = const [],
  });

  @override
  Future<GitRootResult> resolveRepositoryRoot(
    String candidatePath, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    return rootResultToReturn;
  }

  @override
  Future<RepositoryInfo> getRepositoryInfo(
    String rootPath, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    return repoInfoToReturn ??
        RepositoryInfo.fromPath(rootPath, currentBranch: 'main');
  }

  @override
  Future<List<GitCommit>> getRecentCommits(
    String rootPath, {
    int maxCommits = 15,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    return commitsToReturn;
  }
}

class FakeRepositoryScanner extends RepositoryScanner {
  ScanResult? scanResultToReturn;
  bool shouldThrow = false;

  FakeRepositoryScanner({this.scanResultToReturn});

  @override
  Future<ScanResult> scanRepository(
    String rootPath, {
    ScanLimits limits = const ScanLimits(),
  }) async {
    if (shouldThrow) {
      throw Exception('Disk read error');
    }
    return scanResultToReturn ??
        ScanResult(
          repositoryInfo: RepositoryInfo.fromPath(rootPath),
          files: [
            ScannedFile(
              relativePath: 'lib/main.dart',
              fullPath: '$rootPath/lib/main.dart',
              byteSize: 120,
              lineCount: 8,
              priorityTier: 1,
              contentHash: 'hash_main',
              content: 'void main() {}\n',
            ),
          ],
          commits: [
            GitCommit(
              hash: '1111222233334444555566667777888899990000',
              author: 'dev',
              date: DateTime.parse('2026-10-31T08:00:00Z'),
              subject: 'Initial commit',
            ),
          ],
          scanDurationMs: 15,
          totalCandidatesEnumerated: 1,
          totalBytesRead: 120,
        );
  }
}

class FakeAutopsyService extends AutopsyService {
  AutopsyReport? reportToReturn;
  bool shouldThrow = false;
  String? lastCancelledRequestId;

  FakeAutopsyService({required super.ollamaService, this.reportToReturn});

  @override
  Future<AutopsyReport> generateAutopsy({
    required EvidenceSnapshot snapshot,
    Duration timeout = const Duration(seconds: 180),
  }) async {
    if (shouldThrow) {
      throw Exception('Ollama timeout');
    }
    return reportToReturn ??
        AutopsyReport(
          snapshotId: snapshot.snapshotId,
          requestId: 'req_test_001',
          projectPurpose: const AutopsyFinding(
            text: 'A test forensic application.',
            kind: FindingKind.observed,
            evidenceIds: ['E001'],
          ),
          architecture: const [
            AutopsyFinding(
              text: 'Single-window Flutter architecture.',
              kind: FindingKind.observed,
              evidenceIds: ['E001'],
            ),
          ],
          findings: const [
            AutopsyFinding(
              text: 'Clean domain separation.',
              kind: FindingKind.inferred,
              evidenceIds: ['E001'],
            ),
          ],
          revivalPlan: const [
            RevivalStep(
              step: 'Run unit test suite.',
              reason: AutopsyFinding(
                text: 'Verify tests before modifying.',
                kind: FindingKind.observed,
                evidenceIds: ['E001'],
              ),
            ),
          ],
          unknowns: const ['Performance on low-spec hardware not verified.'],
          generatedAt: DateTime.parse('2026-10-31T08:30:00Z'),
          rawModelResponse: '{"status":"ok"}',
          latency: const Duration(milliseconds: 800),
        );
  }

  @override
  void cancelCurrentRequest() {
    lastCancelledRequestId = 'cancelled';
  }
}

class FakeGhostQaService extends GhostQaService {
  GhostAnswer? answerToReturn;
  bool shouldThrow = false;
  bool wasCancelled = false;

  FakeGhostQaService({required super.ollamaService, this.answerToReturn});

  @override
  Future<GhostAnswer> askQuestion({
    required EvidenceSnapshot snapshot,
    required String question,
    Duration timeout = const Duration(seconds: 150),
    int topK = 4,
    double minScore = 1.0,
  }) async {
    if (shouldThrow) {
      throw Exception('Model inference timeout');
    }
    return answerToReturn ??
        GhostAnswer(
          notFound: false,
          claims: const [
            AutopsyFinding(
              text: 'The app uses SQLite for persistence.',
              kind: FindingKind.observed,
              evidenceIds: ['E001'],
            ),
          ],
          answeredAt: DateTime.now(),
        );
  }

  @override
  void cancelCurrentRequest() {
    wasCancelled = true;
  }
}

void main() {
  group('WorkbenchController Unit Tests', () {
    late FakeGitService fakeGit;
    late FakeRepositoryScanner fakeScanner;
    late FakeAutopsyService fakeAutopsy;
    late FakeGhostQaService fakeGhostQa;
    late OllamaService realOllamaService;

    setUp(() {
      fakeGit = FakeGitService();
      fakeScanner = FakeRepositoryScanner();
      realOllamaService = OllamaService();
      fakeAutopsy = FakeAutopsyService(ollamaService: realOllamaService);
      fakeGhostQa = FakeGhostQaService(ollamaService: realOllamaService);
    });

    test('initial state has idle status, zero elapsed duration, and initial readiness', () {
      final controller = WorkbenchController(
        gitService: fakeGit,
        scanner: fakeScanner,
        autopsyService: fakeAutopsy,
        autoCheckReadiness: false,
      );

      expect(controller.state.status, equals(InvestigationStatus.idle));
      expect(controller.state.stage, equals(ScanStage.idle));
      expect(controller.state.elapsedDuration, equals(Duration.zero));
      expect(controller.state.selectedDirectory, isNull);
      expect(controller.state.repositoryInfo, isNull);
      expect(controller.state.scanResult, isNull);
      expect(controller.state.evidenceSnapshot, isNull);
      expect(controller.state.autopsyReport, isNull);
      expect(controller.state.activeEvidenceItem, isNull);
      expect(controller.state.isLoading, isFalse);
    });

    test(
      'checkSystemReadiness updates readinessState with diagnostic results',
      () async {
        final controller = WorkbenchController(
          gitService: fakeGit,
          scanner: fakeScanner,
          autopsyService: fakeAutopsy,
          gitChecker: () async =>
              const GitCheckResult.installed('git version 2.45.0'),
          autoCheckReadiness: false,
        );

        await controller.checkSystemReadiness();

        expect(controller.state.readinessState.gitResult.isInstalled, isTrue);
        expect(
          controller.state.readinessState.gitResult.version,
          contains('2.45.0'),
        );
        expect(controller.state.readinessState.isChecking, isFalse);
      },
    );

    test('setDirectory with valid repository sets repository info and clears previous reports', () async {
      final controller = WorkbenchController(
        gitService: fakeGit,
        scanner: fakeScanner,
        autopsyService: fakeAutopsy,
        autoCheckReadiness: false,
      );

      await controller.setDirectory(r'C:\mock\repo');

      expect(controller.state.selectedDirectory, equals(r'C:\mock\repo'));
      expect(controller.state.repositoryInfo, isNotNull);
      expect(controller.state.repositoryInfo!.name, equals('repo'));
      expect(controller.state.repositoryInfo!.currentBranch, equals('main'));
      expect(controller.state.status, equals(InvestigationStatus.idle));
      expect(controller.state.errorMessage, isNull);
    });

    test('setDirectory with non-git directory sets failure status and error message', () async {
      fakeGit.rootResultToReturn = const GitRootNotARepository(
        r'C:\not_git',
        'fatal: not a git repository',
      );

      final controller = WorkbenchController(
        gitService: fakeGit,
        scanner: fakeScanner,
        autopsyService: fakeAutopsy,
        autoCheckReadiness: false,
      );

      await controller.setDirectory(r'C:\not_git');

      expect(controller.state.status, equals(InvestigationStatus.failed));
      expect(controller.state.repositoryInfo, isNull);
      expect(
        controller.state.errorMessage,
        contains('Directory is not a Git repository'),
      );
    });

    test('startInvestigation without directory sets failed status', () async {
      final controller = WorkbenchController(
        gitService: fakeGit,
        scanner: fakeScanner,
        autopsyService: fakeAutopsy,
        autoCheckReadiness: false,
      );

      await controller.startInvestigation();

      expect(controller.state.status, equals(InvestigationStatus.failed));
      expect(
        controller.state.errorMessage,
        contains('Please select a valid Git repository'),
      );
    });

    test('startInvestigation completes full pipeline successfully', () async {
      final controller = WorkbenchController(
        gitService: fakeGit,
        scanner: fakeScanner,
        autopsyService: fakeAutopsy,
        autoCheckReadiness: false,
      );

      await controller.setDirectory(r'C:\mock\repo');
      await controller.startInvestigation();

      expect(controller.state.status, equals(InvestigationStatus.completed));
      expect(controller.state.scanResult, isNotNull);
      expect(controller.state.evidenceSnapshot, isNotNull);
      expect(controller.state.autopsyReport, isNotNull);
      expect(
        controller.state.autopsyReport!.projectPurpose?.text,
        contains('forensic application'),
      );
      expect(controller.state.errorMessage, isNull);
    });

    test(
      'startInvestigation failure preserves previous valid report',
      () async {
        final controller = WorkbenchController(
          gitService: fakeGit,
          scanner: fakeScanner,
          autopsyService: fakeAutopsy,
          autoCheckReadiness: false,
        );

        await controller.setDirectory(r'C:\mock\repo');
        await controller.startInvestigation();
        expect(controller.state.status, equals(InvestigationStatus.completed));
        final firstReport = controller.state.autopsyReport;
        expect(firstReport, isNotNull);

        // Second run fails
        fakeAutopsy.shouldThrow = true;
        await controller.startInvestigation();

        expect(controller.state.status, equals(InvestigationStatus.failed));
        expect(
          controller.state.errorMessage,
          contains('Investigation failed: Exception: Ollama timeout'),
        );
        expect(
          controller.state.autopsyReport,
          equals(firstReport),
          reason: 'Must preserve last valid report',
        );
      },
    );

    test('cancelInvestigation halts pipeline, marks cancelled and preserves report', () async {
      final controller = WorkbenchController(
        gitService: fakeGit,
        scanner: fakeScanner,
        autopsyService: fakeAutopsy,
        autoCheckReadiness: false,
      );

      await controller.setDirectory(r'C:\mock\repo');
      await controller.startInvestigation();
      final report = controller.state.autopsyReport;

      controller.cancelInvestigation();

      expect(controller.state.status, equals(InvestigationStatus.cancelled));
      expect(
        controller.state.stageMessage,
        contains('Investigation cancelled by user'),
      );
      expect(controller.state.autopsyReport, equals(report));
      expect(fakeAutopsy.lastCancelledRequestId, equals('cancelled'));
    });

    test(
      'openEvidence and closeEvidence manage active evidence item',
      () async {
        final controller = WorkbenchController(
          gitService: fakeGit,
          scanner: fakeScanner,
          autopsyService: fakeAutopsy,
          autoCheckReadiness: false,
        );

        await controller.setDirectory(r'C:\mock\repo');
        await controller.startInvestigation();

        // Open E001
        controller.openEvidence('E001');
        expect(controller.state.activeEvidenceItem, isNotNull);
        expect(controller.state.activeEvidenceItem!.id, equals('E001'));
        expect(controller.state.activeEvidenceItem, isA<FileEvidence>());

        // Close evidence
        controller.closeEvidence();
        expect(controller.state.activeEvidenceItem, isNull);
      },
    );

    test('clearInvestigation resets state cleanly', () async {
      final controller = WorkbenchController(
        gitService: fakeGit,
        scanner: fakeScanner,
        autopsyService: fakeAutopsy,
        autoCheckReadiness: false,
      );

      await controller.setDirectory(r'C:\mock\repo');
      await controller.startInvestigation();

      controller.clearInvestigation();

      expect(controller.state.status, equals(InvestigationStatus.idle));
      expect(controller.state.selectedDirectory, isNull);
      expect(controller.state.scanResult, isNull);
      expect(controller.state.autopsyReport, isNull);
      expect(controller.state.activeEvidenceItem, isNull);
    });

    test('askGhost sets searching status and completes with answer', () async {
      final controller = WorkbenchController(
        gitService: fakeGit,
        scanner: fakeScanner,
        autopsyService: fakeAutopsy,
        ghostQaService: fakeGhostQa,
        autoCheckReadiness: false,
      );

      await controller.setDirectory(r'C:\mock\repo');
      await controller.startInvestigation();

      await controller.askGhost('What database is used?');

      expect(
        controller.state.ghostQuestion?.text,
        equals('What database is used?'),
      );
      expect(controller.state.ghostQaStatus, equals(GhostQaStatus.completed));
      expect(controller.state.ghostAnswer, isNotNull);
      expect(
        controller.state.ghostAnswer!.claims.first.text,
        contains('SQLite'),
      );
    });

    test(
      'askGhost without evidence snapshot reports descriptive error',
      () async {
        final controller = WorkbenchController(
          gitService: fakeGit,
          scanner: fakeScanner,
          autopsyService: fakeAutopsy,
          ghostQaService: fakeGhostQa,
          autoCheckReadiness: false,
        );

        await controller.askGhost('What database is used?');

        expect(controller.state.ghostQaStatus, equals(GhostQaStatus.failed));
        expect(
          controller.state.ghostQaErrorMessage,
          contains('Investigate a repository first'),
        );
      },
    );

    test(
      'cancelGhostQuestion cancels request and marks status cancelled',
      () async {
        final controller = WorkbenchController(
          gitService: fakeGit,
          scanner: fakeScanner,
          autopsyService: fakeAutopsy,
          ghostQaService: fakeGhostQa,
          autoCheckReadiness: false,
        );

        await controller.setDirectory(r'C:\mock\repo');
        await controller.startInvestigation();

        // Trigger question then cancel
        controller.cancelGhostQuestion();

        expect(controller.state.ghostQaStatus, equals(GhostQaStatus.cancelled));
        expect(fakeGhostQa.wasCancelled, isTrue);
      },
    );

    test(
      'switching repository resets Ghost Q&A state preventing repo mixing',
      () async {
        final controller = WorkbenchController(
          gitService: fakeGit,
          scanner: fakeScanner,
          autopsyService: fakeAutopsy,
          ghostQaService: fakeGhostQa,
          autoCheckReadiness: false,
        );

        await controller.setDirectory(r'C:\mock\repo');
        await controller.startInvestigation();
        await controller.askGhost('What database is used?');

        expect(controller.state.ghostAnswer, isNotNull);

        // Switch to empty/new directory
        await controller.setDirectory('');

        expect(controller.state.ghostQuestion, isNull);
        expect(controller.state.ghostAnswer, isNull);
        expect(controller.state.ghostQaStatus, equals(GhostQaStatus.idle));
      },
    );

    // --- Markdown Report Export Operations (M7) Tests ---

    test(
      'exportMarkdownReport without active report returns failure',
      () async {
        final controller = WorkbenchController(
          gitService: fakeGit,
          scanner: fakeScanner,
          autopsyService: fakeAutopsy,
          autoCheckReadiness: false,
        );

        final result = await controller.exportMarkdownReport();

        expect(result.status, equals(ExportStatus.failed));
        expect(result.errorMessage, contains('No active autopsy report'));
        expect(controller.state.isExporting, isFalse);
      },
    );

    test(
      'exportMarkdownReport successfully saves and updates lastExportedPath',
      () async {
        final memorySaver = MemoryFileSaver();
        final controller = WorkbenchController(
          gitService: fakeGit,
          scanner: fakeScanner,
          autopsyService: fakeAutopsy,
          ghostQaService: fakeGhostQa,
          autoCheckReadiness: false,
        );

        await controller.setDirectory(r'C:\mock\repo');
        await controller.startInvestigation();

        final result = await controller.exportMarkdownReport(
          overrideSaver: memorySaver,
          exportTimestamp: DateTime.utc(2026, 10, 31, 13, 0),
        );

        expect(result.status, equals(ExportStatus.success));
        expect(controller.state.isExporting, isFalse);
        expect(controller.state.lastExportedPath, isNotNull);
        expect(
          controller.state.lastExportedPath,
          contains('repo_autopsy_20261031_snap_'),
        );
        expect(controller.state.exportErrorMessage, isNull);
        expect(
          memorySaver.lastSavedContent,
          contains('# RepoSéance Forensic Autopsy Report: repo'),
        );
      },
    );

    test('exportMarkdownReport user cancellation leaves state intact without error', () async {
      final memorySaver = MemoryFileSaver(shouldCancel: true);
      final controller = WorkbenchController(
        gitService: fakeGit,
        scanner: fakeScanner,
        autopsyService: fakeAutopsy,
        ghostQaService: fakeGhostQa,
        autoCheckReadiness: false,
      );

      await controller.setDirectory(r'C:\mock\repo');
      await controller.startInvestigation();

      final result = await controller.exportMarkdownReport(
        overrideSaver: memorySaver,
      );

      expect(result.status, equals(ExportStatus.cancelled));
      expect(controller.state.isExporting, isFalse);
      expect(controller.state.lastExportedPath, isNull);
      expect(controller.state.exportErrorMessage, isNull);
      expect(controller.state.autopsyReport, isNotNull);
    });

    test('exportMarkdownReport recoverable failure sets exportErrorMessage without clearing report', () async {
      final memorySaver = MemoryFileSaver(
        failureError: 'Simulated disk write failure',
      );
      final controller = WorkbenchController(
        gitService: fakeGit,
        scanner: fakeScanner,
        autopsyService: fakeAutopsy,
        ghostQaService: fakeGhostQa,
        autoCheckReadiness: false,
      );

      await controller.setDirectory(r'C:\mock\repo');
      await controller.startInvestigation();

      final result = await controller.exportMarkdownReport(
        overrideSaver: memorySaver,
      );

      expect(result.status, equals(ExportStatus.failed));
      expect(controller.state.isExporting, isFalse);
      expect(
        controller.state.exportErrorMessage,
        contains('Simulated disk write failure'),
      );
      expect(controller.state.autopsyReport, isNotNull);

      // Verify clearExportError
      controller.clearExportError();
      expect(controller.state.exportErrorMessage, isNull);
    });
  });
}
