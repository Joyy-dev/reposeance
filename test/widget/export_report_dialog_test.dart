import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reposeance/features/autopsy/domain/models/autopsy_finding.dart';
import 'package:reposeance/features/autopsy/domain/models/evidence_item.dart';
import 'package:reposeance/features/autopsy/domain/models/evidence_snapshot.dart';
import 'package:reposeance/features/export/domain/models/export_options.dart';
import 'package:reposeance/features/export/presentation/widgets/export_report_dialog.dart';
import 'package:reposeance/features/ghost_qa/domain/models/ghost_answer.dart';
import 'package:reposeance/features/ghost_qa/domain/models/ghost_question.dart';
import 'package:reposeance/features/readiness/models/readiness_state.dart';
import 'package:reposeance/features/repository/domain/models/repository_info.dart';
import 'package:reposeance/features/repository/domain/models/scan_result.dart';
import 'package:reposeance/features/workbench/domain/models/workbench_state.dart';

void main() {
  WorkbenchState createSampleState({bool withGhostAnswer = true}) {
    const repoInfo = RepositoryInfo(
      rootPath: r'C:\dev\my_project',
      name: 'my_project',
      currentBranch: 'main',
      headCommitHash: 'deadbeef1234',
    );

    final snapshot = EvidenceSnapshot(
      snapshotId: 'snap_test_12345678',
      repositoryRoot: r'C:\dev\my_project',
      evidenceMap: {
        'E001': const FileEvidence(
          id: 'E001',
          snapshotId: 'snap_test_12345678',
          repositoryRelativePath: 'lib/main.dart',
          content: 'void main() {}',
          contentHash: 'hash1',
          startLine: 1,
          endLine: 1,
        ),
        'E051': CommitEvidence(
          id: 'E051',
          snapshotId: 'snap_test_12345678',
          commitHash: 'deadbeef1234',
          author: 'Alice',
          date: DateTime(2026, 10, 31),
          subject: 'Initial commit',
        ),
      },
    );

    final scanResult = const ScanResult(
      repositoryInfo: repoInfo,
      files: [],
      commits: [],
      totalCandidatesEnumerated: 1,
      totalBytesRead: 100,
      scanDurationMs: 50,
    );

    return WorkbenchState(
      readinessState: SystemReadinessState.initial(),
      repositoryInfo: repoInfo,
      scanResult: scanResult,
      evidenceSnapshot: snapshot,
      ghostQuestion: withGhostAnswer
          ? GhostQuestion(text: 'What database is used?')
          : null,
      ghostAnswer: withGhostAnswer
          ? GhostAnswer(
              notFound: false,
              claims: const [
                AutopsyFinding(
                  text: 'SQLite is configured for local data storage.',
                  evidenceIds: ['E001'],
                  kind: FindingKind.observed,
                ),
              ],
              answeredAt: DateTime(2026, 10, 31, 10, 5),
            )
          : null,
    );
  }

  group('ExportReportDialog Widget Tests', () {
    setUp(() {});

    testWidgets('renders scope summary, privacy badge, and actions', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = createSampleState(withGhostAnswer: true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    await ExportReportDialog.show(
                      context,
                      workbenchState: state,
                    );
                  },
                  child: const Text('Open Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Export Autopsy Report'), findsOneWidget);
      expect(find.text('Target Repository'), findsOneWidget);
      expect(find.text('my_project'), findsOneWidget);
      expect(find.text('Snapshot ID'), findsOneWidget);
      expect(find.text('snap_tes'), findsOneWidget);
      expect(find.textContaining('Privacy Guard'), findsOneWidget);
      expect(find.text('Include Ask the Ghost Q&A inquiries'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save as Markdown (.md)...'), findsOneWidget);
    });

    testWidgets('cancelling dialog returns null', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = createSampleState(withGhostAnswer: true);
      ExportOptions? result;
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    result = await ExportReportDialog.show(
                      context,
                      workbenchState: state,
                    );
                    completed = true;
                  },
                  child: const Text('Open Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(result, isNull);
    });

    testWidgets(
      'submitting dialog returns ExportOptions with ghost Q&A included by default',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final state = createSampleState(withGhostAnswer: true);
        ExportOptions? result;
        var completed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      result = await ExportReportDialog.show(
                        context,
                        workbenchState: state,
                      );
                      completed = true;
                    },
                    child: const Text('Open Dialog'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Save as Markdown (.md)...'));
        await tester.pumpAndSettle();

        expect(completed, isTrue);
        expect(result, isNotNull);
        expect(result!.includeGhostQa, isTrue);
      },
    );

    testWidgets(
      'unchecking Q&A checkbox returns ExportOptions with includeGhostQa false',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final state = createSampleState(withGhostAnswer: true);
        ExportOptions? result;
        var completed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      result = await ExportReportDialog.show(
                        context,
                        workbenchState: state,
                      );
                      completed = true;
                    },
                    child: const Text('Open Dialog'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        // Tap checkbox to uncheck
        await tester.tap(find.text('Include Ask the Ghost Q&A inquiries'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Save as Markdown (.md)...'));
        await tester.pumpAndSettle();

        expect(completed, isTrue);
        expect(result, isNotNull);
        expect(result!.includeGhostQa, isFalse);
      },
    );

    testWidgets('does not show Q&A checkbox when ghostAnswer is null', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = createSampleState(withGhostAnswer: false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    await ExportReportDialog.show(
                      context,
                      workbenchState: state,
                    );
                  },
                  child: const Text('Open Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Include Ask the Ghost Q&A inquiries'), findsNothing);
    });
  });
}
