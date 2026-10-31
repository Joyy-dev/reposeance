import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/services/ollama_service.dart';
import '../domain/models/autopsy_report.dart';
import '../domain/models/evidence_request_map.dart';
import '../domain/models/evidence_snapshot.dart';
import '../domain/validation/autopsy_exceptions.dart';
import '../domain/validation/autopsy_validator.dart';
import 'autopsy_prompt_builder.dart';

/// Orchestrates evidence snapshot translation, prompt construction, Ollama inference,
/// JSON schema validation, bounded repair attempts, and state preservation.
class AutopsyService {
  final OllamaService ollamaService;
  final http.Client Function()? clientFactory;

  String? _activeRequestId;
  http.Client? _activeClient;
  AutopsyReport? _lastValidReport;

  AutopsyService({required this.ollamaService, this.clientFactory});

  AutopsyReport? get lastValidReport => _lastValidReport;
  bool get isGenerating => _activeRequestId != null;
  String? get activeRequestId => _activeRequestId;

  /// Cancels any in-flight autopsy inference and invalidates active request IDs.
  void cancelCurrentRequest() {
    _activeRequestId = null;
    _activeClient?.close();
    _activeClient = null;
  }

  /// Generates a validated autopsy report from an immutable EvidenceSnapshot.
  /// Enforces:
  /// - Unique request ID allowlist.
  /// - JSON Schema draft 2020-12 validation.
  /// - At most one repair attempt on validation failure.
  /// - Preservation of last valid report upon failure or cancellation.
  /// - Suppression and drop of stale late responses.
  Future<AutopsyReport> generateAutopsy({
    required EvidenceSnapshot snapshot,
    Duration timeout = const Duration(seconds: 180),
  }) async {
    final requestId =
        'req_${DateTime.now().microsecondsSinceEpoch}_${snapshot.snapshotId}';
    _activeRequestId = requestId;

    final client = clientFactory?.call() ?? http.Client();
    _activeClient = client;

    final requestMap = EvidenceRequestMap(
      requestId: requestId,
      snapshotId: snapshot.snapshotId,
      suppliedEvidenceIds: snapshot.allEvidenceIds.toSet(),
    );

    final initialMessages = [
      {'role': 'system', 'content': AutopsyPromptBuilder.systemPrompt},
      {
        'role': 'user',
        'content': AutopsyPromptBuilder.buildUserPrompt(
          snapshot: snapshot,
          requestMap: requestMap,
        ),
      },
    ];

    final stopwatch = Stopwatch()..start();

    try {
      final initialRawResponse = await _dispatchChat(
        messages: initialMessages,
        timeout: timeout,
        client: client,
        requestId: requestId,
      );

      _assertStillActive(requestId);

      final assistantContent = _extractContent(initialRawResponse);
      final promptEvalCount = initialRawResponse['prompt_eval_count'] as int?;
      final evalCount = initialRawResponse['eval_count'] as int?;

      // Validate first response
      final validationResult = AutopsyValidator.validate(
        rawJsonOrMap: assistantContent,
        requestMap: requestMap,
        rawModelResponse: assistantContent,
        latency: stopwatch.elapsed,
        promptEvalCount: promptEvalCount,
        evalCount: evalCount,
      );

      if (validationResult.isValid && validationResult.report != null) {
        _lastValidReport = validationResult.report;
        _activeRequestId = null;
        _activeClient = null;
        return validationResult.report!;
      }

      // First validation failed -> Attempt bounded repair (at most 1 repair round)
      final repairMessages = List<Map<String, String>>.from(initialMessages)
        ..add({'role': 'assistant', 'content': assistantContent})
        ..add({
          'role': 'user',
          'content': AutopsyPromptBuilder.buildRepairMessage(
            validationErrors: validationResult.errors,
            requestMap: requestMap,
          ),
        });

      final repairRawResponse = await _dispatchChat(
        messages: repairMessages,
        timeout: timeout,
        client: client,
        requestId: requestId,
      );

      _assertStillActive(requestId);

      final repairedContent = _extractContent(repairRawResponse);
      final repairedPromptEval = repairRawResponse['prompt_eval_count'] as int?;
      final repairedEval = repairRawResponse['eval_count'] as int?;

      final repairedValidationResult = AutopsyValidator.validate(
        rawJsonOrMap: repairedContent,
        requestMap: requestMap,
        rawModelResponse: repairedContent,
        latency: stopwatch.elapsed,
        promptEvalCount: repairedPromptEval,
        evalCount: repairedEval,
      );

      if (repairedValidationResult.isValid &&
          repairedValidationResult.report != null) {
        _lastValidReport = repairedValidationResult.report;
        _activeRequestId = null;
        _activeClient = null;
        return repairedValidationResult.report!;
      }

      // Repair failed -> Max 1 repair reached; throw validation exception without wiping lastValidReport
      throw AutopsyValidationException(
        'Autopsy report failed validation after 1 repair attempt.',
        errors: repairedValidationResult.errors,
        rawResponse: repairedContent,
        repairAttempts: 1,
      );
    } on AutopsyException {
      rethrow;
    } on TimeoutException {
      throw AutopsyTimeoutException(
        'Autopsy inference timed out after ${timeout.inSeconds} seconds.',
        timeout,
      );
    } on SocketException catch (e) {
      throw AutopsyUnavailableException('Ollama service offline: ${e.message}');
    } on OllamaServiceException catch (e) {
      throw AutopsyUnavailableException(e.message);
    } finally {
      if (_activeRequestId == requestId) {
        _activeRequestId = null;
        _activeClient = null;
      }
    }
  }

  Future<Map<String, dynamic>> _dispatchChat({
    required List<Map<String, String>> messages,
    required Duration timeout,
    required http.Client client,
    required String requestId,
  }) async {
    _assertStillActive(requestId);

    return await ollamaService.chat(
      messages: messages,
      format: AutopsyPromptBuilder.autopsySchema,
      options: const {'temperature': 0.1, 'num_predict': 2048},
      timeout: timeout,
      clientOverride: client,
    );
  }

  String _extractContent(Map<String, dynamic> rawResponse) {
    if (rawResponse.containsKey('message') &&
        rawResponse['message'] is Map<String, dynamic>) {
      final msg = rawResponse['message'] as Map<String, dynamic>;
      if (msg.containsKey('content') && msg['content'] is String) {
        return msg['content'] as String;
      }
    }
    throw AutopsyValidationException(
      'Malformed Ollama response: missing message.content string.',
      rawResponse: rawResponse.toString(),
    );
  }

  void _assertStillActive(String requestId) {
    if (_activeRequestId != requestId) {
      throw AutopsyCancelledException(
        'Autopsy request $requestId was cancelled or superseded by another request.',
      );
    }
  }
}
