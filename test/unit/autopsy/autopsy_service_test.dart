import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reposeance/core/services/ollama_service.dart';
import 'package:reposeance/features/autopsy/data/autopsy_service.dart';
import 'package:reposeance/features/autopsy/domain/models/evidence_snapshot.dart';
import 'package:reposeance/features/autopsy/domain/validation/autopsy_exceptions.dart';
import 'package:reposeance/features/repository/domain/models/git_commit.dart';
import 'package:reposeance/features/repository/domain/models/repository_info.dart';
import 'package:reposeance/features/repository/domain/models/scan_result.dart';
import 'package:reposeance/features/repository/domain/models/scanned_file.dart';

void main() {
  group('AutopsyService Orchestration & Repair Tests', () {
    late EvidenceSnapshot testSnapshot;

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
          byteSize: 100,
          lineCount: 5,
          priorityTier: 1,
          contentHash: 'hash_pubspec',
          content: 'name: mock_app\n',
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

      final scanResult = ScanResult(
        repositoryInfo: repoInfo,
        files: files,
        commits: commits,
        scanDurationMs: 20,
        totalCandidatesEnumerated: 1,
        totalBytesRead: 100,
      );

      testSnapshot = EvidenceSnapshot.fromScanResult(
        scanResult,
        snapshotId: 'snap_test_1',
      );
    });

    Map<String, dynamic> createValidAutopsyJson() {
      return {
        'project_purpose': {
          'text': 'A mock utility application.',
          'kind': 'observed',
          'evidence_ids': ['E001'],
        },
        'architecture': [
          {
            'text': 'Flutter application indicated by pubspec.yaml.',
            'kind': 'observed',
            'evidence_ids': ['E001'],
          },
        ],
        'findings': [
          {
            'text': 'Initial commit created basic scaffold.',
            'kind': 'observed',
            'evidence_ids': ['E051'],
          },
        ],
        'revival_plan': [
          {
            'step': 'Add unit test suite.',
            'reason': {
              'text': 'Project currently lacks automated tests.',
              'kind': 'inferred',
              'evidence_ids': ['E001'],
            },
          },
        ],
        'unknowns': ['Sync credentials are unsupplied.'],
      };
    }

    test('happy path: single request returns valid autopsy JSON', () async {
      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        expect(request.url.path, equals('/api/chat'));
        final validJson = createValidAutopsyJson();
        final responsePayload = {
          'model': 'gemma4:e2b',
          'created_at': DateTime.now().toIso8601String(),
          'message': {'role': 'assistant', 'content': jsonEncode(validJson)},
          'done': true,
          'prompt_eval_count': 350,
          'eval_count': 220,
        };

        return http.Response(
          jsonEncode(responsePayload),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final ollamaService = OllamaService(client: mockClient);
      final autopsyService = AutopsyService(
        ollamaService: ollamaService,
        clientFactory: () => mockClient,
      );

      final report = await autopsyService.generateAutopsy(
        snapshot: testSnapshot,
      );

      expect(requestCount, equals(1));
      expect(report.projectPurpose?.text, contains('mock utility'));
      expect(report.architecture.length, equals(1));
      expect(report.promptEvalCount, equals(350));
      expect(report.evalCount, equals(220));

      // Check state preservation
      expect(autopsyService.lastValidReport, isNotNull);
      expect(
        autopsyService.lastValidReport?.snapshotId,
        equals(testSnapshot.snapshotId),
      );
    });

    test('repair flow: initial response cites unsupplied E999 -> repair round succeeds', () async {
      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        final requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        final messages = requestBody['messages'] as List<dynamic>;

        if (requestCount == 1) {
          // First response with unsupplied E999
          final invalidJson = createValidAutopsyJson();
          invalidJson['findings'] = [
            {
              'text': 'Finding with invalid citation.',
              'kind': 'observed',
              'evidence_ids': ['E999'],
            },
          ];

          return http.Response(
            jsonEncode({
              'model': 'gemma4:e2b',
              'message': {
                'role': 'assistant',
                'content': jsonEncode(invalidJson),
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else {
          // Second request must include repair prompt citing the error
          expect(
            messages.length,
            equals(4),
          ); // system, user, assistant(invalid), user(repair)
          expect(
            messages.last['content'],
            contains('unsupplied or unknown evidence ID "E999"'),
          );

          final validRepairedJson = createValidAutopsyJson();
          return http.Response(
            jsonEncode({
              'model': 'gemma4:e2b',
              'message': {
                'role': 'assistant',
                'content': jsonEncode(validRepairedJson),
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
      });

      final ollamaService = OllamaService(client: mockClient);
      final autopsyService = AutopsyService(
        ollamaService: ollamaService,
        clientFactory: () => mockClient,
      );

      final report = await autopsyService.generateAutopsy(
        snapshot: testSnapshot,
      );

      expect(requestCount, equals(2)); // exactly 1 repair request dispatched
      expect(report.findings.first.evidenceIds, equals(['E051']));
      expect(autopsyService.lastValidReport, isNotNull);
    });

    test('max 1 repair attempt: fails after second invalid response and preserves previous report', () async {
      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        // Always return invalid JSON
        return http.Response(
          jsonEncode({
            'model': 'gemma4:e2b',
            'message': {
              'role': 'assistant',
              'content': jsonEncode({
                'project_purpose': null,
                'architecture': [],
                'findings': [
                  {
                    'text': 'Invalid citation finding.',
                    'kind': 'observed',
                    'evidence_ids': ['E999'],
                  },
                ],
                'revival_plan': [],
                'unknowns': [],
              }),
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final ollamaService = OllamaService(client: mockClient);
      final autopsyService = AutopsyService(
        ollamaService: ollamaService,
        clientFactory: () => mockClient,
      );

      await expectLater(
        autopsyService.generateAutopsy(snapshot: testSnapshot),
        throwsA(
          isA<AutopsyValidationException>().having(
            (e) => e.repairAttempts,
            'repairAttempts',
            equals(1),
          ),
        ),
      );

      // Verify requestCount is capped at 2 (1 initial + 1 repair)
      expect(requestCount, equals(2));
    });

    test('cancellation suppresses late response and throws AutopsyCancelledException', () async {
      final completer = Completer<http.Response>();
      final mockClient = MockClient((request) => completer.future);

      final ollamaService = OllamaService(client: mockClient);
      final autopsyService = AutopsyService(
        ollamaService: ollamaService,
        clientFactory: () => mockClient,
      );

      final future = autopsyService.generateAutopsy(snapshot: testSnapshot);
      expect(autopsyService.isGenerating, isTrue);

      // Cancel while in flight
      autopsyService.cancelCurrentRequest();
      expect(autopsyService.isGenerating, isFalse);

      // Complete HTTP request late
      completer.complete(
        http.Response(
          jsonEncode({
            'model': 'gemma4:e2b',
            'message': {
              'role': 'assistant',
              'content': jsonEncode(createValidAutopsyJson()),
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );

      expect(future, throwsA(isA<AutopsyCancelledException>()));
    });

    test('timeout produces AutopsyTimeoutException', () async {
      final mockClient = MockClient((request) async {
        await Future.delayed(const Duration(milliseconds: 50));
        return http.Response('{}', 200);
      });

      final ollamaService = OllamaService(client: mockClient);
      final autopsyService = AutopsyService(
        ollamaService: ollamaService,
        clientFactory: () => mockClient,
      );

      expect(
        () => autopsyService.generateAutopsy(
          snapshot: testSnapshot,
          timeout: const Duration(milliseconds: 10),
        ),
        throwsA(isA<AutopsyTimeoutException>()),
      );
    });
  });
}
