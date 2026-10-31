import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:reposeance/features/autopsy/domain/models/autopsy_finding.dart';
import 'package:reposeance/features/autopsy/domain/models/evidence_item.dart';
import 'package:reposeance/features/autopsy/domain/models/evidence_snapshot.dart';
import 'package:reposeance/features/ghost_qa/domain/models/ghost_answer.dart';
import 'package:reposeance/features/ghost_qa/domain/models/ghost_question.dart';
import 'package:reposeance/features/ghost_qa/presentation/widgets/ghost_qa_view.dart';
import 'package:reposeance/features/readiness/models/readiness_state.dart';
import 'package:reposeance/features/workbench/controllers/workbench_controller.dart';
import 'package:reposeance/features/workbench/domain/models/workbench_state.dart';

void main() {
  Widget createTestWidget(WorkbenchController controller) {
    return MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider<WorkbenchController>.value(
          value: controller,
          child: const SingleChildScrollView(child: GhostQaView()),
        ),
      ),
    );
  }

  group('GhostQaView Widget Tests', () {
    testWidgets('renders idle state with title, suggestions, and input form', (
      tester,
    ) async {
      final controller = WorkbenchController(autoCheckReadiness: false);

      await tester.pumpWidget(createTestWidget(controller));

      expect(find.text('Ask the Ghost (Interactive Q&A)'), findsOneWidget);
      expect(find.text('Interactive Software Archaeology'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Ask Ghost'), findsOneWidget);

      // Suggestions exist
      expect(
        find.text('What database or persistence layer is configured?'),
        findsOneWidget,
      );
      expect(
        find.text('Why was SQLite chosen over PostgreSQL?'),
        findsOneWidget,
      );
    });

    testWidgets(
      'renders loading state with stage description, elapsed timer and cancel button',
      (tester) async {
        final loadingState = WorkbenchState(
          readinessState: SystemReadinessState.initial(),
          ghostQaStatus: GhostQaStatus.searching,
          ghostQaStageText:
              'Searching snapshot & consulting local Gemma (CPU)...',
          ghostQaElapsedDuration: const Duration(seconds: 45),
        );

        final controller = WorkbenchController(
          initialState: loadingState,
          autoCheckReadiness: false,
        );

        await tester.pumpWidget(createTestWidget(controller));

        expect(
          find.text('Searching snapshot & consulting local Gemma (CPU)...'),
          findsOneWidget,
        );
        expect(find.text('00:45 elapsed'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);

        // Input should be disabled
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.enabled, isFalse);
      },
    );

    testWidgets(
      'renders grounded claims with observed/inferred badges and citation buttons',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final snapshot = EvidenceSnapshot(
          snapshotId: 'snap_qa_widget',
          repositoryRoot: 'C:/mock/repo',
          evidenceMap: {
            'E001': const FileEvidence(
              id: 'E001',
              snapshotId: 'snap_qa_widget',
              repositoryRelativePath: 'lib/db/sqlite.dart',
              startLine: 1,
              endLine: 20,
              content: 'class SqliteDatabase {}',
              contentHash: 'h_db',
            ),
          },
        );

        final answer = GhostAnswer(
          notFound: false,
          claims: const [
            AutopsyFinding(
              text: 'SQLite database is configured for local storage.',
              kind: FindingKind.observed,
              evidenceIds: ['E001'],
            ),
          ],
          answeredAt: DateTime.now(),
          latency: const Duration(milliseconds: 1400),
        );

        final answeredState = WorkbenchState(
          readinessState: SystemReadinessState.initial(),
          evidenceSnapshot: snapshot,
          ghostQuestion: GhostQuestion(text: 'What database is used?'),
          ghostAnswer: answer,
          ghostQaStatus: GhostQaStatus.completed,
        );

        final controller = WorkbenchController(
          initialState: answeredState,
          autoCheckReadiness: false,
        );

        await tester.pumpWidget(createTestWidget(controller));

        expect(find.text('Inquiry: "What database is used?"'), findsOneWidget);
        expect(
          find.text('SQLite database is configured for local storage.'),
          findsOneWidget,
        );
        expect(find.text('Observed'), findsOneWidget);
        expect(find.text('E001 · sqlite.dart'), findsOneWidget);

        // Ensure citation is visible and tap it
        await tester.ensureVisible(find.text('E001 · sqlite.dart'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('E001 · sqlite.dart'));
        await tester.pump();

        expect(controller.state.activeEvidenceItem, isNotNull);
        expect(controller.state.activeEvidenceItem!.id, 'E001');
      },
    );

    testWidgets(
      'renders honest not_found answer with missing evidence explanation',
      (tester) async {
        final answer = GhostAnswer.insufficientEvidence(
          missingEvidence: 'The inspected files and commit subjects do not document why SQLite was chosen instead of PostgreSQL.',
        );

        final notFoundState = WorkbenchState(
          readinessState: SystemReadinessState.initial(),
          ghostQuestion: GhostQuestion(text: 'Why was SQLite chosen?'),
          ghostAnswer: answer,
          ghostQaStatus: GhostQaStatus.completed,
        );

        final controller = WorkbenchController(
          initialState: notFoundState,
          autoCheckReadiness: false,
        );

        await tester.pumpWidget(createTestWidget(controller));

        expect(find.text('Insufficient Repository Evidence'), findsOneWidget);
        expect(
          find.text(
            'The inspected files and commit subjects do not document why SQLite was chosen instead of PostgreSQL.',
          ),
          findsOneWidget,
        );
        expect(find.text('New Inquiry'), findsOneWidget);
      },
    );

    testWidgets('renders diagnostic error card on Q&A failure', (tester) async {
      final errorState = WorkbenchState(
        readinessState: SystemReadinessState.initial(),
        ghostQaStatus: GhostQaStatus.failed,
        ghostQaErrorMessage:
            'Ollama service connection refused on 127.0.0.1:11434',
      );

      final controller = WorkbenchController(
        initialState: errorState,
        autoCheckReadiness: false,
      );

      await tester.pumpWidget(createTestWidget(controller));

      expect(
        find.text('Ollama service connection refused on 127.0.0.1:11434'),
        findsOneWidget,
      );
    });
  });
}
