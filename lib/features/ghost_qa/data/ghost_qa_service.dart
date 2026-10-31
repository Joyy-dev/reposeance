import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:reposeance/core/services/ollama_service.dart';
import 'package:reposeance/features/autopsy/domain/models/evidence_snapshot.dart';

import '../domain/models/ghost_answer.dart';
import '../domain/validation/ghost_qa_exceptions.dart';
import 'ghost_qa_prompt_builder.dart';
import 'ghost_qa_validator.dart';
import 'lexical_retrieval_engine.dart';

/// Orchestrates deterministic lexical retrieval, prompt construction, loopback Ollama inference,
/// JSON schema validation, bounded repair, cancellation, and state preservation.
class GhostQaService {
  final OllamaService ollamaService;
  final http.Client Function()? clientFactory;

  String? _activeRequestId;
  http.Client? _activeClient;
  GhostAnswer? _lastValidAnswer;

  GhostQaService({required this.ollamaService, this.clientFactory});

  GhostAnswer? get lastValidAnswer => _lastValidAnswer;
  bool get isProcessing => _activeRequestId != null;
  String? get activeRequestId => _activeRequestId;

  /// Cancels in-flight Q&A inference and aborts pending HTTP requests.
  void cancelCurrentRequest() {
    _activeRequestId = null;
    _activeClient?.close();
    _activeClient = null;
  }

  /// Answers a user's question about the repository snapshot.
  /// Enforces:
  /// - Deterministic lexical retrieval bounded to the snapshot.
  /// - Zero/weak match short-circuit to honest not_found in pure Dart.
  /// - Current request evidence allowlist containment.
  /// - Draft 2020-12 ghost-answer schema validation.
  /// - At most 1 repair round on schema failure.
  /// - Preservation of prior valid answer on cancellation or error.
  Future<GhostAnswer> askQuestion({
    required EvidenceSnapshot snapshot,
    required String question,
    Duration timeout = const Duration(seconds: 150),
    int topK = 4,
    double minScore = 1.0,
  }) async {
    final requestId =
        'qa_${DateTime.now().microsecondsSinceEpoch}_${snapshot.snapshotId}';
    _activeRequestId = requestId;

    final stopwatch = Stopwatch()..start();

    // 1. Deterministic Lexical Retrieval
    final retrieved = LexicalRetrievalEngine.retrieve(
      snapshot: snapshot,
      query: question,
      topK: topK,
      minScore: minScore,
    );

    // 2. Zero/weak retrieval short-circuit (pure Dart, 0 CPU inference cost)
    if (retrieved.isEmpty) {
      final honestAnswer = GhostAnswer.insufficientEvidence(
        missingEvidence:
            'No scanned repository files or commit messages contain terms matching query: "$question".',
        snapshotId: snapshot.snapshotId,
        requestId: requestId,
        latency: stopwatch.elapsed,
      );
      _lastValidAnswer = honestAnswer;
      _activeRequestId = null;
      return honestAnswer;
    }

    final suppliedEvidenceIds = retrieved.map((s) => s.item.id).toSet();

    final client = clientFactory?.call() ?? http.Client();
    _activeClient = client;

    final initialMessages = [
      {'role': 'system', 'content': GhostQaPromptBuilder.systemPrompt},
      {
        'role': 'user',
        'content': GhostQaPromptBuilder.buildUserPrompt(
          question: question,
          retrievedEvidence: retrieved,
          suppliedEvidenceIds: suppliedEvidenceIds,
        ),
      },
    ];

    try {
      // 3. Dispatch initial inference
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

      // 4. Validate response
      final validationResult = GhostQaValidator.validate(
        rawJsonOrMap: assistantContent,
        suppliedEvidenceIds: suppliedEvidenceIds,
        snapshotId: snapshot.snapshotId,
        requestId: requestId,
        latency: stopwatch.elapsed,
        rawModelResponse: assistantContent,
        promptEvalCount: promptEvalCount,
        evalCount: evalCount,
      );

      if (validationResult.isValid && validationResult.answer != null) {
        _lastValidAnswer = validationResult.answer;
        _activeRequestId = null;
        return validationResult.answer!;
      }

      // 5. At most 1 repair round
      final repairMessages = [
        ...initialMessages,
        {'role': 'assistant', 'content': assistantContent},
        {
          'role': 'user',
          'content': GhostQaPromptBuilder.buildRepairPrompt(
            originalResponse: assistantContent,
            errors: validationResult.errors,
            suppliedEvidenceIds: suppliedEvidenceIds,
          ),
        },
      ];

      final repairRawResponse = await _dispatchChat(
        messages: repairMessages,
        timeout: timeout,
        client: client,
        requestId: requestId,
      );

      _assertStillActive(requestId);

      final repairedContent = _extractContent(repairRawResponse);
      final repairPromptEval = repairRawResponse['prompt_eval_count'] as int?;
      final repairEval = repairRawResponse['eval_count'] as int?;

      final repairValidationResult = GhostQaValidator.validate(
        rawJsonOrMap: repairedContent,
        suppliedEvidenceIds: suppliedEvidenceIds,
        snapshotId: snapshot.snapshotId,
        requestId: requestId,
        latency: stopwatch.elapsed,
        rawModelResponse: repairedContent,
        promptEvalCount: repairPromptEval,
        evalCount: repairEval,
      );

      if (repairValidationResult.isValid &&
          repairValidationResult.answer != null) {
        _lastValidAnswer = repairValidationResult.answer;
        _activeRequestId = null;
        return repairValidationResult.answer!;
      }

      throw GhostQaValidationException(repairValidationResult.errors);
    } on TimeoutException {
      throw GhostQaTimeoutException(timeout);
    } on SocketException catch (e) {
      throw GhostQaServiceException(
        'Ollama service connection failed: ${e.message}',
      );
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
      model: 'gemma4:e2b',
      options: const {'temperature': 0.1, 'num_predict': 768},
      format: GhostQaPromptBuilder.ghostAnswerSchema,
      timeout: timeout,
      clientOverride: client,
    );
  }

  String _extractContent(Map<String, dynamic> rawResponse) {
    if (rawResponse.containsKey('message') &&
        rawResponse['message'] is Map &&
        (rawResponse['message'] as Map).containsKey('content')) {
      return (rawResponse['message']['content'] as String).trim();
    }
    throw const GhostQaServiceException(
      'Malformed Ollama chat response: missing message.content',
    );
  }

  void _assertStillActive(String requestId) {
    if (_activeRequestId != requestId) {
      throw const GhostQaCancelledException();
    }
  }
}
