import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:reposeance/features/autopsy/domain/models/autopsy_finding.dart';
import 'package:reposeance/features/autopsy/domain/models/autopsy_report.dart';
import 'package:reposeance/features/autopsy/domain/models/evidence_item.dart';
import 'package:reposeance/features/autopsy/domain/models/evidence_snapshot.dart';
import 'package:reposeance/features/autopsy/domain/models/revival_step.dart';
import 'package:reposeance/features/export/data/markdown_export_service.dart';
import 'package:reposeance/features/readiness/models/readiness_state.dart';
import 'package:reposeance/features/repository/domain/models/repository_info.dart';
import 'package:reposeance/features/repository/domain/models/scan_result.dart';
import 'package:reposeance/features/workbench/controllers/workbench_controller.dart';
import 'package:reposeance/features/workbench/domain/models/workbench_state.dart';
import 'package:reposeance/features/workbench/presentation/widgets/autopsy_report_view.dart';

import '../unit/export/mocks/memory_file_saver.dart';

void main() {
  WorkbenchState createAutopsyState() {
    const repoInfo = RepositoryInfo(
      rootPath: r'C:\dev\my_project',
      name: 'my_project',
      currentBranch: 'main',
      headCommitHash: 'deadbeef1234',
    );

    final snapshot = EvidenceSnapshot(
      snapshotId: 'snap_widget_test_123',
      repositoryRoot: r'C:\dev\my_project',
      evidenceMap: {
        'E001': const FileEvidence(
          id: 'E001',
          snapshotId: 'snap_widget_test_123',
          repositoryRelativePath: 'lib/main.dart',
          content: 'void main() {}',
          contentHash: 'hash1',
          startLine: 1,
          endLine: 1,
        ),
      },
    );

    final report = AutopsyReport(
      snapshotId: 'snap_widget_test_123',
      requestId: 'req_123',
      projectPurpose: const AutopsyFinding(
        text: 'A forensic CLI and UI tool for git archaeological recovery.',
        evidenceIds: ['E001'],
        kind: FindingKind.observed,
      ),
      architecture: const [
        AutopsyFinding(
          text: 'Modular layer-based architecture.',
          evidenceIds: ['E001'],
          kind: FindingKind.observed,
        ),
      ],
      findings: const [],
      revivalPlan: const [
        RevivalStep(
          step: 'Compile and test core suite',
          reason: AutopsyFinding(
            text: 'Run flutter test to confirm basic suite health.',
            evidenceIds: ['E001'],
            kind: FindingKind.observed,
          ),
        ),
      ],
      unknowns: const [
        'Continuous integration service configuration is absent.',
      ],
      generatedAt: DateTime(2026, 10, 31, 10, 0),
      rawModelResponse: '{}',
      latency: const Duration(milliseconds: 1200),
    );

    return WorkbenchState(
      readinessState: SystemReadinessState.initial(),
      repositoryInfo: repoInfo,
      scanResult: const ScanResult(
        repositoryInfo: repoInfo,
        files: [],
        commits: [],
        totalCandidatesEnumerated: 1,
        totalBytesRead: 100,
        scanDurationMs: 50,
      ),
      evidenceSnapshot: snapshot,
      autopsyReport: report,
    );
  }

  Widget createTestWidget({
    required WorkbenchController controller,
    required WorkbenchState state,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider<WorkbenchController>.value(
          value: controller,
          child: AutopsyReportView(state: state, controller: controller),
        ),
      ),
    );
  }

  group('AutopsyReportView Export Integration Widget Tests', () {
    testWidgets('renders Export Report button and opens ExportReportDialog', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = createAutopsyState();
      final memorySaver = MemoryFileSaver();
      final controller = WorkbenchController(
        initialState: state,
        exportService: MarkdownExportService(defaultSaver: memorySaver),
        autoCheckReadiness: false,
      );

      await tester.pumpWidget(
        createTestWidget(controller: controller, state: state),
      );
      await tester.pumpAndSettle();

      final exportButton = find.byKey(const Key('export-report-button'));
      expect(exportButton, findsOneWidget);
      expect(find.text('Export Report'), findsOneWidget);

      // Tap button to open dialog
      await tester.tap(exportButton);
      await tester.pumpAndSettle();

      expect(find.text('Export Autopsy Report'), findsOneWidget);
      expect(find.text('Save as Markdown (.md)...'), findsOneWidget);

      // Cancel closes dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Export Autopsy Report'), findsNothing);
      expect(memorySaver.lastSavedFileName, isNull);
    });

    testWidgets('successfully exports report and shows confirmation SnackBar', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = createAutopsyState();
      final memorySaver = MemoryFileSaver();
      final controller = WorkbenchController(
        initialState: state,
        exportService: MarkdownExportService(defaultSaver: memorySaver),
        autoCheckReadiness: false,
      );

      await tester.pumpWidget(
        createTestWidget(controller: controller, state: state),
      );
      await tester.pumpAndSettle();

      // Tap Export Report
      await tester.tap(find.byKey(const Key('export-report-button')));
      await tester.pumpAndSettle();

      // Tap Save as Markdown (.md)...
      await tester.tap(find.text('Save as Markdown (.md)...'));
      await tester.pumpAndSettle();

      // Dialog closed
      expect(find.text('Export Autopsy Report'), findsNothing);

      // File was saved by MemoryFileSaver
      expect(
        memorySaver.lastSavedFileName,
        startsWith('my_project_autopsy_20261031_'),
      );
      expect(
        memorySaver.lastSavedContent,
        contains('# RepoSéance Forensic Autopsy Report'),
      );

      // SnackBar shown
      expect(
        find.textContaining('Report exported to C:\\Exports\\'),
        findsOneWidget,
      );
    });

    testWidgets('shows error SnackBar when export fails', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = createAutopsyState();
      final memorySaver = MemoryFileSaver(failureError: 'Simulated disk full');
      final controller = WorkbenchController(
        initialState: state,
        exportService: MarkdownExportService(defaultSaver: memorySaver),
        autoCheckReadiness: false,
      );

      await tester.pumpWidget(
        createTestWidget(controller: controller, state: state),
      );
      await tester.pumpAndSettle();

      // Tap Export Report
      await tester.tap(find.byKey(const Key('export-report-button')));
      await tester.pumpAndSettle();

      // Tap Save
      await tester.tap(find.text('Save as Markdown (.md)...'));
      await tester.pumpAndSettle();

      // SnackBar shown with error message
      expect(find.textContaining('Simulated disk full'), findsOneWidget);
    });
  });
}
