import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Health status classification for Ollama local service.
enum OllamaHealthStatus { checking, ready, runningModelMissing, unreachable }

/// Result of Ollama health check inspection.
class OllamaHealthResult {
  final OllamaHealthStatus status;
  final String? version;
  final List<String> models;
  final String? error;
  final int responseTimeMs;

  const OllamaHealthResult({
    required this.status,
    this.version,
    this.models = const [],
    this.error,
    this.responseTimeMs = 0,
  });

  bool get isReady => status == OllamaHealthStatus.ready;
}

/// Service communicating directly over loopback HTTP with native Ollama daemon.
class OllamaService {
  final String baseUri;
  final String targetModel;
  final http.Client _client;

  static const String defaultLoopback = 'http://127.0.0.1:11434';
  static const String defaultModel = 'gemma4:e2b';

  OllamaService({String? baseUri, String? targetModel, http.Client? client})
    : baseUri = baseUri ?? defaultLoopback,
      targetModel = targetModel ?? defaultModel,
      _client = client ?? http.Client() {
    _assertLoopback(this.baseUri);
  }

  /// Security invariant: Enforce loopback destination to prevent data egress.
  static void _assertLoopback(String uriString) {
    final uri = Uri.parse(uriString);
    final host = uri.host.toLowerCase();
    if (host != '127.0.0.1' && host != 'localhost') {
      throw SecurityException(
        'RepoSéance security violation: Non-loopback endpoint ($uriString) rejected. '
        'Only loopback (127.0.0.1) is permitted.',
      );
    }
  }

  /// Checks whether Ollama service is running and whether target model is installed.
  Future<OllamaHealthResult> checkHealth({
    Duration timeout = const Duration(milliseconds: 2500),
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      _assertLoopback(baseUri);

      // Check daemon version via GET /api/version
      final versionUri = Uri.parse('$baseUri/api/version');
      final versionRequest = http.Request('GET', versionUri)
        ..followRedirects = false;
      final streamedVersionResponse = await _client
          .send(versionRequest)
          .timeout(timeout);
      final versionResponse = await http.Response.fromStream(
        streamedVersionResponse,
      );

      if (versionResponse.statusCode != 200) {
        stopwatch.stop();
        return OllamaHealthResult(
          status: OllamaHealthStatus.unreachable,
          error: 'HTTP ${versionResponse.statusCode} from /api/version',
          responseTimeMs: stopwatch.elapsedMilliseconds,
        );
      }

      String? version;
      try {
        final versionJson =
            jsonDecode(versionResponse.body) as Map<String, dynamic>;
        version = versionJson['version'] as String?;
      } catch (_) {
        // Version string parse failure is non-fatal
      }

      // Check available models via GET /api/tags
      final tagsUri = Uri.parse('$baseUri/api/tags');
      final tagsRequest = http.Request('GET', tagsUri)..followRedirects = false;
      final streamedTagsResponse = await _client
          .send(tagsRequest)
          .timeout(timeout);
      final tagsResponse = await http.Response.fromStream(streamedTagsResponse);

      final List<String> availableModels = [];
      if (tagsResponse.statusCode == 200) {
        try {
          final tagsJson =
              jsonDecode(tagsResponse.body) as Map<String, dynamic>;
          final modelsList = tagsJson['models'] as List<dynamic>? ?? [];
          for (final item in modelsList) {
            if (item is Map<String, dynamic> && item.containsKey('name')) {
              availableModels.add(item['name'] as String);
            }
          }
        } catch (_) {}
      }

      stopwatch.stop();

      // Check if target model (e.g. gemma4:e2b) or any model tagged with the prefix is present
      final hasTargetModel = availableModels.any(
        (m) =>
            m == targetModel ||
            m == '$targetModel:latest' ||
            m.startsWith('$targetModel:') ||
            m.startsWith(targetModel),
      );

      if (hasTargetModel) {
        return OllamaHealthResult(
          status: OllamaHealthStatus.ready,
          version: version,
          models: availableModels,
          responseTimeMs: stopwatch.elapsedMilliseconds,
        );
      } else {
        return OllamaHealthResult(
          status: OllamaHealthStatus.runningModelMissing,
          version: version,
          models: availableModels,
          error:
              'Model "$targetModel" is not installed. Found: ${availableModels.join(", ")}',
          responseTimeMs: stopwatch.elapsedMilliseconds,
        );
      }
    } on TimeoutException {
      stopwatch.stop();
      return OllamaHealthResult(
        status: OllamaHealthStatus.unreachable,
        error: 'Connection timed out after ${timeout.inMilliseconds}ms',
        responseTimeMs: stopwatch.elapsedMilliseconds,
      );
    } on SocketException catch (e) {
      stopwatch.stop();
      return OllamaHealthResult(
        status: OllamaHealthStatus.unreachable,
        error: 'Ollama service offline (${e.message})',
        responseTimeMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      return OllamaHealthResult(
        status: OllamaHealthStatus.unreachable,
        error: e.toString(),
        responseTimeMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  /// Dispatches a structured non-streaming chat request to Ollama `/api/chat`.
  /// Security & correctness invariants:
  /// - Enforces loopback destination to prevent data egress.
  /// - Disables redirect following (`followRedirects = false`).
  /// - Sends `"think": false` so internal reasoning tokens do not consume output token budget.
  /// - Default temperature 0.1 for deterministic, factual extraction.
  Future<Map<String, dynamic>> chat({
    required List<Map<String, String>> messages,
    Map<String, dynamic>? format,
    String? model,
    Map<String, dynamic>? options,
    Duration timeout = const Duration(seconds: 180),
    http.Client? clientOverride,
  }) async {
    _assertLoopback(baseUri);

    final selectedModel = model ?? targetModel;
    final client = clientOverride ?? _client;
    final chatUri = Uri.parse('$baseUri/api/chat');

    final payload = <String, dynamic>{
      'model': selectedModel,
      'messages': messages,
      'stream': false,
      'think': false,
      'options': {'temperature': 0.1, 'num_predict': 2048, ...?options},
    };
    if (format != null) {
      payload['format'] = format;
    }

    final request = http.Request('POST', chatUri)
      ..followRedirects = false
      ..headers[HttpHeaders.contentTypeHeader] =
          'application/json; charset=utf-8'
      ..body = jsonEncode(payload);

    try {
      final streamedResponse = await client.send(request).timeout(timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw OllamaServiceException(
          'Ollama chat failed with HTTP ${response.statusCode}: ${response.body}',
          statusCode: response.statusCode,
        );
      }

      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw OllamaServiceException(
          'Unexpected non-object response payload from Ollama /api/chat: $decoded',
        );
      }

      return decoded;
    } on SocketException catch (e) {
      throw OllamaServiceException('Ollama service offline (${e.message})');
    }
  }

  void dispose() {
    _client.close();
  }
}

class OllamaServiceException implements Exception {
  final String message;
  final int? statusCode;

  const OllamaServiceException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class SecurityException implements Exception {
  final String message;
  SecurityException(this.message);

  @override
  String toString() => message;
}
