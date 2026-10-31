import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reposeance/core/services/ollama_service.dart';
import 'package:reposeance/features/autopsy/domain/models/autopsy_finding.dart';
import 'package:reposeance/features/autopsy/domain/models/evidence_item.dart';
import 'package:reposeance/features/autopsy/domain/models/evidence_snapshot.dart';
import 'package:reposeance/features/ghost_qa/data/ghost_qa_service.dart';
import 'package:reposeance/features/ghost_qa/domain/validation/ghost_qa_exceptions.dart';

void main() {
  group('GhostQaService', () {
    late EvidenceSnapshot testSnapshot;

    setUp(() {
      testSnapshot = EvidenceSnapshot(
        snapshotId: 'snap_qa_1',
        repositoryRoot: 'C:/repos/mock_app',
        evidenceMap: {
          'E001': const FileEvidence(
            id: 'E001',
            snapshotId: 'snap_qa_1',
            repositoryRelativePath: 'lib/services/sqlite_database.dart',
            startLine: 1,
            endLine: 35,
            content: 'class SqliteDatabase { Future<void> openDb() async {} }',
            contentHash: 'hash_sqlite',
          ),
          'E051': CommitEvidence(
            id: 'E051',
            snapshotId: 'snap_qa_1',
            commitHash: 'commit12345',
            date: DateTime.parse('2026-10-31T09:00:00Z'),
            subject: 'feat: add sqlite persistence store',
            author: 'Jane Dev',
          ),
        },
      );
    });

    test('short-circuits to honest not_found on zero lexical match without HTTP call', () async {
      bool httpCalled = false;
      final mockClient = MockClient((request) async {
        httpCalled = true;
        return http.Response('{}', 200);
      });

      final service = GhostQaService(
        ollamaService: OllamaService(),
        clientFactory: () => mockClient,
      );

      final answer = await service.askQuestion(
        snapshot: testSnapshot,
        question: 'quantum superconducting qubits teleportation matrix',
      );

      expect(
        httpCalled,
        isFalse,
        reason: 'Zero-match queries must not call Ollama',
      );
      expect(answer.notFound, isTrue);
      expect(answer.claims, isEmpty);
      expect(
        answer.missingEvidence,
        contains(
          'No scanned repository files or commit messages contain terms',
        ),
      );
      expect(service.lastValidAnswer, isNotNull);
    });

    test('successfully generates grounded answer on first attempt', () async {
      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        final responsePayload = {
          'message': {
            'role': 'assistant',
            'content': jsonEncode({
              'not_found': false,
              'claims': [
                {
                  'text': 'The repository uses SqliteDatabase for local persistence.',
                  'kind': 'observed',
                  'evidence_ids': ['E001'],
                },
              ],
              'missing_evidence': null,
            }),
          },
          'prompt_eval_count': 120,
          'eval_count': 45,
        };
        return http.Response(jsonEncode(responsePayload), 200);
      });

      final service = GhostQaService(
        ollamaService: OllamaService(),
        clientFactory: () => mockClient,
      );

      final answer = await service.askQuestion(
        snapshot: testSnapshot,
        question: 'What database is used for persistence?',
      );

      expect(requestCount, 1);
      expect(answer.notFound, isFalse);
      expect(answer.claims.length, 1);
      expect(answer.claims.first.kind, FindingKind.observed);
      expect(answer.claims.first.evidenceIds, ['E001']);
      expect(service.lastValidAnswer, answer);
    });

    test(
      'executes 1 repair round if initial response has schema errors',
      () async {
        int callCount = 0;
        final mockClient = MockClient((request) async {
          callCount++;
          if (callCount == 1) {
            // Schema violation: not_found is false but claims is empty
            final badResponse = {
              'message': {
                'role': 'assistant',
                'content': jsonEncode({
                  'not_found': false,
                  'claims': [],
                  'missing_evidence': null,
                }),
              },
            };
            return http.Response(jsonEncode(badResponse), 200);
          } else {
            // Repair response: valid
            final repairedResponse = {
              'message': {
                'role': 'assistant',
                'content': jsonEncode({
                  'not_found': false,
                  'claims': [
                    {
                      'text': 'The project uses SqliteDatabase.',
                      'kind': 'observed',
                      'evidence_ids': ['E001'],
                    },
                  ],
                  'missing_evidence': null,
                }),
              },
              'prompt_eval_count': 140,
              'eval_count': 50,
            };
            return http.Response(jsonEncode(repairedResponse), 200);
          }
        });

        final service = GhostQaService(
          ollamaService: OllamaService(),
          clientFactory: () => mockClient,
        );

        final answer = await service.askQuestion(
          snapshot: testSnapshot,
          question: 'What database is configured?',
        );

        expect(
          callCount,
          2,
          reason: 'Must execute repair round on schema failure',
        );
        expect(answer.notFound, isFalse);
        expect(answer.claims.length, 1);
      },
    );

    test('handles cancellation and preserves last valid answer', () async {
      final mockClient = MockClient((request) async {
        await Future.delayed(const Duration(milliseconds: 200));
        return http.Response(
          jsonEncode({
            'message': {
              'role': 'assistant',
              'content': jsonEncode({
                'not_found': true,
                'claims': [],
                'missing_evidence': 'Missing evidence.',
              }),
            },
          }),
          200,
        );
      });

      final service = GhostQaService(
        ollamaService: OllamaService(),
        clientFactory: () => mockClient,
      );

      // Seed with prior answer via short circuit
      await service.askQuestion(
        snapshot: testSnapshot,
        question: 'unknown totally unmatched query',
      );
      expect(service.lastValidAnswer, isNotNull);
      final savedAnswer = service.lastValidAnswer;

      // Start new request and immediately cancel
      final future = service.askQuestion(
        snapshot: testSnapshot,
        question: 'What database is used?',
      );
      service.cancelCurrentRequest();

      expect(future, throwsA(isA<GhostQaCancelledException>()));
      expect(service.isProcessing, isFalse);
      expect(
        service.lastValidAnswer,
        savedAnswer,
        reason: 'Prior valid answer preserved',
      );
    });
  });
}
