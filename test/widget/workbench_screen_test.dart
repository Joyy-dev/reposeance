import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:reposeance/core/services/ollama_service.dart';
import 'package:reposeance/core/theme/app_theme.dart';
import 'package:reposeance/core/utils/git_checker.dart';
import 'package:reposeance/features/autopsy/domain/models/autopsy_finding.dart';
import 'package:reposeance/features/autopsy/domain/models/autopsy_report.dart';
import 'package:reposeance/features/autopsy/domain/models/evidence_item.dart';
import 'package:reposeance/features/autopsy/domain/models/evidence_snapshot.dart';
import 'package:reposeance/features/autopsy/domain/models/revival_step.dart';
import 'package:reposeance/features/readiness/controllers/readiness_controller.dart';
import 'package:reposeance/features/readiness/models/readiness_state.dart';
import 'package:reposeance/features/repository/domain/models/git_commit.dart';
import 'package:reposeance/features/repository/domain/models/repository_info.dart';
import 'package:reposeance/features/repository/domain/models/scan_result.dart';
import 'package:reposeance/features/repository/domain/models/scanned_file.dart';
import 'package:reposeance/features/workbench/controllers/workbench_controller.dart';
import 'package:reposeance/features/workbench/domain/models/workbench_state.dart';
import 'package:reposeance/features/workbench/presentation/screens/workbench_screen.dart';

Widget _buildTestApp({
  required WorkbenchController workbenchController,
  ReadinessController? readinessController,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(
        value:
            readinessController ??
            ReadinessController(
              autoCheck: false,
              initialState: const SystemReadinessState(
                isChecking: false,
                gitResult: GitCheckResult.installed('git version 2.45.0'),
                ollamaResult: OllamaHealthResult(
                  status: OllamaHealthStatus.ready,
                  version: '0.40.13',
                  models: ['gemma4:e2b'],
                ),
              ),
            ),
      ),
      ChangeNotifierProvider.value(value: workbenchController),
    ],
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(1280, 800),
          textScaler: textScaler,
        ),
        child: const WorkbenchScreen(),
      ),
    ),
  );
}

void main() {
  group('WorkbenchScreen Widget Tests (M5 Acceptance Criteria)', () {
    testWidgets(
      '1. Empty state renders cleanly without synthetic prototype defaults',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = WorkbenchController(
          autoCheckReadiness: false,
          initialState: const WorkbenchState(
            status: InvestigationStatus.idle,
            readinessState: SystemReadinessState(
              isChecking: false,
              gitResult: GitCheckResult.installed('git version 2.45.0'),
              ollamaResult: OllamaHealthResult(
                status: OllamaHealthStatus.ready,
                version: '0.40.13',
                models: ['gemma4:e2b'],
              ),
            ),
          ),
        );

        await tester.pumpWidget(_buildTestApp(workbenchController: controller));
        await tester.pumpAndSettle();

        // Assert core landing headlines are visible
        expect(
          find.text('The code survived.\nRecover the context.'),
          findsOneWidget,
        );
        expect(find.text('Select Git Repository'), findsOneWidget);
        expect(find.text('Recheck Toolchain'), findsOneWidget);
        expect(find.text('01'), findsOneWidget);
        expect(find.text('Bounded Scan'), findsOneWidget);

        // Assert zero synthetic prototype defaults in live UI
        expect(find.text('forgotten_inventory'), findsNothing);
        expect(find.text('demo-001'), findsNothing);
        expect(find.text('Synthetic investigation / 001'), findsNothing);
      },
    );

    testWidgets(
      '2. Loading state renders truthful stage text, live timer and cancel button without fake percent bars',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = WorkbenchController(
          autoCheckReadiness: false,
          initialState: const WorkbenchState(
            status: InvestigationStatus.scanning,
            stage: ScanStage.readingFiles,
            stageMessage: 'Stage 2/4: Reading priority files and commits...',
            elapsedDuration: Duration(seconds: 42),
            readinessState: SystemReadinessState(
              isChecking: false,
              gitResult: GitCheckResult.installed('git 2.45.0'),
              ollamaResult: OllamaHealthResult(
                status: OllamaHealthStatus.ready,
              ),
            ),
          ),
        );

        await tester.pumpWidget(_buildTestApp(workbenchController: controller));
        await tester.pump();

        // Verify truthful stage text and elapsed counter
        expect(
          find.text('Stage 2/4: Reading priority files and commits...'),
          findsOneWidget,
        );
        expect(find.text('00:42 elapsed'), findsOneWidget);
        expect(find.text('Cancel Investigation'), findsOneWidget);

        // Verify absence of fake percentage indicators
        expect(find.text('0%'), findsNothing);
        expect(find.text('25%'), findsNothing);
        expect(find.text('50%'), findsNothing);
        expect(find.text('100%'), findsNothing);
      },
    );

    testWidgets(
      '3. Autopsy report view renders purpose, architecture, timeline, and unknowns accurately',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final repoInfo = RepositoryInfo.fromPath(
          r'C:\repos\my_tool',
          currentBranch: 'main',
        );

        final files = [
          ScannedFile(
            relativePath: 'README.md',
            fullPath: r'C:\repos\my_tool\README.md',
            byteSize: 180,
            lineCount: 10,
            priorityTier: 1,
            contentHash: 'hash_readme_123',
            content: '# My Tool\nA repository forensics utility.\n',
          ),
        ];

        final commits = [
          GitCommit(
            hash: 'c1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0',
            author: 'Joyce Ava',
            date: DateTime.parse('2026-10-31T08:00:00Z'),
            subject: 'Initial prototype commit',
          ),
        ];

        final scanResult = ScanResult(
          repositoryInfo: repoInfo,
          files: files,
          commits: commits,
          scanDurationMs: 40,
          totalCandidatesEnumerated: 1,
          totalBytesRead: 180,
        );

        final snapshot = EvidenceSnapshot.fromScanResult(
          scanResult,
          snapshotId: 'snap_live_001',
        );

        final autopsyReport = AutopsyReport(
          snapshotId: 'snap_live_001',
          requestId: 'req_001',
          projectPurpose: const AutopsyFinding(
            text: 'A repository forensics utility designed to recover abandoned code.',
            kind: FindingKind.observed,
            evidenceIds: ['E001'],
          ),
          architecture: const [
            AutopsyFinding(
              text: 'Structured Provider state management with safe non-shell Git.',
              kind: FindingKind.observed,
              evidenceIds: ['E001'],
            ),
          ],
          findings: const [
            AutopsyFinding(
              text: 'Documentation agrees with entrypoint implementation.',
              kind: FindingKind.inferred,
              evidenceIds: ['E001'],
            ),
          ],
          revivalPlan: const [
            RevivalStep(
              step: 'Verify test suite before refactoring.',
              reason: AutopsyFinding(
                text: 'Ensure unit tests pass before making modifications.',
                kind: FindingKind.observed,
                evidenceIds: ['E001'],
              ),
            ),
          ],
          unknowns: const [
            'CI deployment pipeline is not visible in local excerpts.',
          ],
          generatedAt: DateTime.parse('2026-10-31T08:35:00Z'),
          rawModelResponse: '{}',
          latency: const Duration(seconds: 4),
        );

        final controller = WorkbenchController(
          autoCheckReadiness: false,
          initialState: WorkbenchState(
            selectedDirectory: r'C:\repos\my_tool',
            repositoryInfo: repoInfo,
            scanResult: scanResult,
            evidenceSnapshot: snapshot,
            autopsyReport: autopsyReport,
            status: InvestigationStatus.completed,
            readinessState: const SystemReadinessState(
              isChecking: false,
              gitResult: GitCheckResult.installed('git 2.45.0'),
              ollamaResult: OllamaHealthResult(
                status: OllamaHealthStatus.ready,
              ),
            ),
          ),
        );

        await tester.pumpWidget(_buildTestApp(workbenchController: controller));
        await tester.pumpAndSettle();

        // Verify report headers and findings
        expect(find.text('my_tool'), findsAtLeastNWidgets(1));
        expect(find.text('Project Purpose & Identity'), findsOneWidget);
        expect(
          find.text(
            'A repository forensics utility designed to recover abandoned code.',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            'Structured Provider state management with safe non-shell Git.',
          ),
          findsOneWidget,
        );
        expect(find.text('Three Starting Points'), findsOneWidget);
        expect(
          find.text('Verify test suite before refactoring.'),
          findsOneWidget,
        );
        expect(find.text('Development History'), findsOneWidget);
        expect(find.text('Initial prototype commit'), findsOneWidget);
        expect(find.text('What Remains Unsaid'), findsOneWidget);
        expect(
          find.text('CI deployment pipeline is not visible in local excerpts.'),
          findsOneWidget,
        );
        expect(find.text('EVIDENCE, NOT MEMORY'), findsOneWidget);
        expect(find.text('Ask the Ghost (Interactive Q&A)'), findsOneWidget);
      },
    );

    testWidgets('4. Partial scan banner renders when bounds are hit', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repoInfo = RepositoryInfo.fromPath(r'C:\repos\large_repo');
      final scanResult = ScanResult(
        repositoryInfo: repoInfo,
        files: [],
        commits: [],
        scanDurationMs: 50,
        totalCandidatesEnumerated: 5000,
        totalBytesRead: 2000000,
        partialWarnings: [
          'Hit candidate enumeration limit: 5000 items encountered.',
        ],
      );

      final autopsyReport = AutopsyReport(
        snapshotId: 'snap_partial',
        requestId: 'req_002',
        projectPurpose: null,
        architecture: [],
        findings: [],
        revivalPlan: [],
        unknowns: ['Repository truncated due to candidate bounds.'],
        generatedAt: DateTime.now(),
        rawModelResponse: '{}',
        latency: Duration.zero,
      );

      final controller = WorkbenchController(
        autoCheckReadiness: false,
        initialState: WorkbenchState(
          selectedDirectory: r'C:\repos\large_repo',
          repositoryInfo: repoInfo,
          scanResult: scanResult,
          autopsyReport: autopsyReport,
          status: InvestigationStatus.completed,
          readinessState: const SystemReadinessState(
            isChecking: false,
            gitResult: GitCheckResult.installed('git 2.45.0'),
            ollamaResult: OllamaHealthResult(status: OllamaHealthStatus.ready),
          ),
        ),
      );

      await tester.pumpWidget(_buildTestApp(workbenchController: controller));
      await tester.pumpAndSettle();

      expect(find.text('PARTIAL SCOPE INSPECTION'), findsOneWidget);
      expect(
        find.textContaining('Hit candidate enumeration limit'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Caveat: Excluded, uninspected, or untracked files',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      '5. Evidence Drawer opens on citation click and dismisses on Escape key',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final repoInfo = RepositoryInfo.fromPath(r'C:\repos\my_repo');
        final files = [
          ScannedFile(
            relativePath: 'lib/core.dart',
            fullPath: r'C:\repos\my_repo\lib\core.dart',
            byteSize: 50,
            lineCount: 3,
            priorityTier: 1,
            contentHash: 'hash_core',
            content: 'line 1\nline 2\nline 3',
          ),
        ];

        final scanResult = ScanResult(
          repositoryInfo: repoInfo,
          files: files,
          commits: [],
          scanDurationMs: 10,
          totalCandidatesEnumerated: 1,
          totalBytesRead: 50,
        );

        final snapshot = EvidenceSnapshot.fromScanResult(
          scanResult,
          snapshotId: 'snap_drawer_test',
        );

        final autopsyReport = AutopsyReport(
          snapshotId: 'snap_drawer_test',
          requestId: 'req_drawer',
          projectPurpose: const AutopsyFinding(
            text: 'Core library for investigation.',
            kind: FindingKind.observed,
            evidenceIds: ['E001'],
          ),
          architecture: [],
          findings: [],
          revivalPlan: [],
          unknowns: [],
          generatedAt: DateTime.now(),
          rawModelResponse: '{}',
          latency: Duration.zero,
        );

        final controller = WorkbenchController(
          autoCheckReadiness: false,
          initialState: WorkbenchState(
            selectedDirectory: r'C:\repos\my_repo',
            repositoryInfo: repoInfo,
            scanResult: scanResult,
            evidenceSnapshot: snapshot,
            autopsyReport: autopsyReport,
            status: InvestigationStatus.completed,
            readinessState: const SystemReadinessState(
              isChecking: false,
              gitResult: GitCheckResult.installed('git 2.45.0'),
              ollamaResult: OllamaHealthResult(
                status: OllamaHealthStatus.ready,
              ),
            ),
          ),
        );

        await tester.pumpWidget(_buildTestApp(workbenchController: controller));
        await tester.pumpAndSettle();

        // Drawer is initially closed
        expect(find.text('CAPTURED EVIDENCE INSPECTOR'), findsNothing);

        // Find and tap the citation button for E001
        final citationPill = find.widgetWithText(
          OutlinedButton,
          'E001 · core.dart',
        );
        expect(citationPill, findsOneWidget);
        await tester.tap(citationPill);
        await tester.pumpAndSettle();

        // Drawer is now open
        expect(find.text('CAPTURED EVIDENCE INSPECTOR'), findsOneWidget);
        expect(find.text('lib/core.dart'), findsOneWidget);
        expect(find.textContaining('Captured lines 1–3'), findsOneWidget);
        expect(find.text('EVIDENCE PROVENANCE INVARIANT'), findsOneWidget);

        // Press Escape to dismiss drawer
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        // Drawer is now closed
        expect(find.text('CAPTURED EVIDENCE INSPECTOR'), findsNothing);
      },
    );

    testWidgets(
      '6. CommitEvidence renders distinct commit fields in Evidence Drawer without fake source lines',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final commitEvidence = CommitEvidence(
          id: 'E051',
          snapshotId: 'snap_commit_test',
          commitHash: 'deadbeef1234567890abcdef1234567890abcdef',
          date: DateTime.parse('2026-10-31T07:30:00Z'),
          subject: 'Add forensic unit tests',
          author: 'Joyce Ava',
        );

        final controller = WorkbenchController(
          autoCheckReadiness: false,
          initialState: WorkbenchState(
            activeEvidenceItem: commitEvidence,
            status: InvestigationStatus.completed,
            readinessState: const SystemReadinessState(
              isChecking: false,
              gitResult: GitCheckResult.installed('git 2.45.0'),
              ollamaResult: OllamaHealthResult(
                status: OllamaHealthStatus.ready,
              ),
            ),
          ),
        );

        await tester.pumpWidget(_buildTestApp(workbenchController: controller));
        await tester.pumpAndSettle();

        // Verify commit drawer elements
        expect(find.text('CAPTURED EVIDENCE INSPECTOR'), findsOneWidget);
        expect(find.text('Commit Evidence'), findsOneWidget);
        expect(find.text('Commit deadbee'), findsOneWidget);
        expect(find.text('Add forensic unit tests'), findsOneWidget);
        expect(
          find.text('deadbeef1234567890abcdef1234567890abcdef'),
          findsOneWidget,
        );
        expect(find.textContaining('Author: Joyce Ava'), findsOneWidget);

        // Verify absence of fake file line text
        expect(find.textContaining('Captured lines'), findsNothing);
      },
    );

    testWidgets(
      '7. Model unavailable state renders guidance and loopback callout without cloud fallback',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = WorkbenchController(
          autoCheckReadiness: false,
          initialState: const WorkbenchState(
            status: InvestigationStatus.idle,
            readinessState: SystemReadinessState(
              isChecking: false,
              gitResult: GitCheckResult.installed('git 2.45.0'),
              ollamaResult: OllamaHealthResult(
                status: OllamaHealthStatus.unreachable,
                error: 'Connection refused',
              ),
            ),
          ),
        );

        await tester.pumpWidget(_buildTestApp(workbenchController: controller));
        await tester.pumpAndSettle();

        expect(
          find.text('Keep the scan. Restore the connection.'),
          findsOneWidget,
        );
        expect(find.text('LOCAL MODEL UNAVAILABLE'), findsOneWidget);
        expect(find.text('ollama serve'), findsOneWidget);
        expect(find.text('ollama pull gemma4:e2b'), findsOneWidget);
        expect(find.text('Recheck Connection'), findsOneWidget);
        expect(
          find.textContaining(
            'RepoSéance is architected strictly for local privacy',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '8. Desktop layout resizes gracefully down to 1000x700 without overflow',
      (tester) async {
        // Minimum required desktop test: 1000x700
        tester.view.physicalSize = const Size(1000, 700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final repoInfo = RepositoryInfo.fromPath(r'C:\repos\compact_repo');
        final autopsyReport = AutopsyReport(
          snapshotId: 'snap_compact',
          requestId: 'req_compact',
          projectPurpose: const AutopsyFinding(
            text: 'Compact repository verification.',
            kind: FindingKind.observed,
            evidenceIds: ['E001'],
          ),
          architecture: const [
            AutopsyFinding(
              text: 'Single-column responsive stacked layout.',
              kind: FindingKind.observed,
              evidenceIds: ['E001'],
            ),
          ],
          findings: [],
          revivalPlan: [],
          unknowns: ['Small window testing.'],
          generatedAt: DateTime.now(),
          rawModelResponse: '{}',
          latency: Duration.zero,
        );

        final controller = WorkbenchController(
          autoCheckReadiness: false,
          initialState: WorkbenchState(
            selectedDirectory: r'C:\repos\compact_repo',
            repositoryInfo: repoInfo,
            autopsyReport: autopsyReport,
            status: InvestigationStatus.completed,
            readinessState: const SystemReadinessState(
              isChecking: false,
              gitResult: GitCheckResult.installed('git 2.45.0'),
              ollamaResult: OllamaHealthResult(
                status: OllamaHealthStatus.ready,
              ),
            ),
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: MediaQuery(
              data: const MediaQueryData(size: Size(1000, 700)),
              child: MultiProvider(
                providers: [
                  ChangeNotifierProvider<WorkbenchController>.value(
                    value: controller,
                  ),
                ],
                child: const WorkbenchScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Assert no RenderFlex errors occurred and report is rendered
        expect(find.text('Compact repository verification.'), findsOneWidget);
        expect(
          find.text('Single-column responsive stacked layout.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '9. Text scaling resilience test (textScaler = 1.5x) renders without RenderFlex overflow',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = WorkbenchController(
          autoCheckReadiness: false,
          initialState: const WorkbenchState(
            status: InvestigationStatus.idle,
            readinessState: SystemReadinessState(
              isChecking: false,
              gitResult: GitCheckResult.installed('git 2.45.0'),
              ollamaResult: OllamaHealthResult(
                status: OllamaHealthStatus.ready,
              ),
            ),
          ),
        );

        await tester.pumpWidget(
          _buildTestApp(
            workbenchController: controller,
            textScaler: const TextScaler.linear(1.5),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('The code survived.\nRecover the context.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
