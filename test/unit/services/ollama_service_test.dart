import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reposeance/core/services/ollama_service.dart';

void main() {
  group('OllamaService Security & Loopback Boundaries', () {
    test('permits loopback 127.0.0.1 and localhost', () {
      expect(
        () => OllamaService(baseUri: 'http://127.0.0.1:11434'),
        returnsNormally,
      );
      expect(
        () => OllamaService(baseUri: 'http://localhost:11434'),
        returnsNormally,
      );
    });

    test('rejects non-loopback endpoints with SecurityException', () {
      expect(
        () => OllamaService(baseUri: 'https://api.openai.com/v1'),
        throwsA(isA<SecurityException>()),
      );
      expect(
        () => OllamaService(baseUri: 'http://192.168.1.100:11434'),
        throwsA(isA<SecurityException>()),
      );
      expect(
        () => OllamaService(baseUri: 'https://ollama.remote-host.net'),
        throwsA(isA<SecurityException>()),
      );
    });
  });

  group('OllamaService Health Check Diagnostics', () {
    test(
      'reports ready when Ollama daemon is active and gemma4:e2b is installed',
      () async {
        final mockClient = MockClient((request) async {
          if (request.url.path == '/api/version') {
            return http.Response(jsonEncode({'version': '0.40.13'}), 200);
          } else if (request.url.path == '/api/tags') {
            return http.Response(
              jsonEncode({
                'models': [
                  {'name': 'gemma4:e2b', 'size': 4587156505},
                  {'name': 'llama3:latest', 'size': 3820000000},
                ],
              }),
              200,
            );
          }
          return http.Response('Not Found', 404);
        });

        final service = OllamaService(
          baseUri: 'http://127.0.0.1:11434',
          targetModel: 'gemma4:e2b',
          client: mockClient,
        );

        final result = await service.checkHealth();
        expect(result.status, equals(OllamaHealthStatus.ready));
        expect(result.version, equals('0.40.13'));
        expect(result.models, contains('gemma4:e2b'));
        expect(result.isReady, isTrue);
      },
    );

    test('reports runningModelMissing when daemon is up but target model is absent', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/version') {
          return http.Response(jsonEncode({'version': '0.40.13'}), 200);
        } else if (request.url.path == '/api/tags') {
          return http.Response(
            jsonEncode({
              'models': [
                {'name': 'mistral:7b', 'size': 4100000000},
              ],
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = OllamaService(
        baseUri: 'http://127.0.0.1:11434',
        targetModel: 'gemma4:e2b',
        client: mockClient,
      );

      final result = await service.checkHealth();
      expect(result.status, equals(OllamaHealthStatus.runningModelMissing));
      expect(result.version, equals('0.40.13'));
      expect(result.models, contains('mistral:7b'));
      expect(result.models, isNot(contains('gemma4:e2b')));
      expect(result.isReady, isFalse);
    });

    test(
      'reports unreachable when HTTP endpoint returns error status',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response('Internal Server Error', 500);
        });

        final service = OllamaService(
          baseUri: 'http://127.0.0.1:11434',
          client: mockClient,
        );

        final result = await service.checkHealth();
        expect(result.status, equals(OllamaHealthStatus.unreachable));
        expect(result.isReady, isFalse);
      },
    );
  });
}
