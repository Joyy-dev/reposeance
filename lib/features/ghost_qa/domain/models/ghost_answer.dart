import 'package:reposeance/features/autopsy/domain/models/autopsy_finding.dart';

/// Represents a grounded answer from the Ghost Q&A assistant matching contracts/ghost-answer.schema.json.
class GhostAnswer {
  final bool notFound;
  final List<AutopsyFinding> claims;
  final String? missingEvidence;

  // Provenance and execution metadata
  final String? snapshotId;
  final String? requestId;
  final Set<String> suppliedEvidenceIds;
  final DateTime answeredAt;
  final Duration? latency;
  final String? rawModelResponse;
  final int? promptEvalCount;
  final int? evalCount;

  const GhostAnswer({
    required this.notFound,
    required this.claims,
    this.missingEvidence,
    this.snapshotId,
    this.requestId,
    this.suppliedEvidenceIds = const {},
    required this.answeredAt,
    this.latency,
    this.rawModelResponse,
    this.promptEvalCount,
    this.evalCount,
  });

  /// Factory for an honest zero-evidence / unsupported answer.
  factory GhostAnswer.insufficientEvidence({
    required String missingEvidence,
    String? snapshotId,
    String? requestId,
    Set<String> suppliedEvidenceIds = const {},
    Duration? latency,
    String? rawModelResponse,
  }) {
    return GhostAnswer(
      notFound: true,
      claims: const [],
      missingEvidence: missingEvidence,
      snapshotId: snapshotId,
      requestId: requestId,
      suppliedEvidenceIds: suppliedEvidenceIds,
      answeredAt: DateTime.now(),
      latency: latency,
      rawModelResponse: rawModelResponse,
    );
  }

  Map<String, dynamic> toJson() => {
    'not_found': notFound,
    'claims': claims.map((c) => c.toJson()).toList(),
    'missing_evidence': missingEvidence,
    if (snapshotId != null) 'snapshot_id': snapshotId,
    if (requestId != null) 'request_id': requestId,
    'supplied_evidence_ids': suppliedEvidenceIds.toList(),
    'answered_at': answeredAt.toIso8601String(),
    if (latency != null) 'latency_ms': latency!.inMilliseconds,
    if (promptEvalCount != null) 'prompt_eval_count': promptEvalCount,
    if (evalCount != null) 'eval_count': evalCount,
  };

  factory GhostAnswer.fromJson(Map<String, dynamic> json) {
    final notFound = json['not_found'] as bool;
    final rawClaims = (json['claims'] as List<dynamic>?) ?? [];
    final claims = rawClaims
        .map((c) => AutopsyFinding.fromJson(c as Map<String, dynamic>))
        .toList();
    final missingEvidence = json['missing_evidence'] as String?;
    final snapshotId = json['snapshot_id'] as String?;
    final requestId = json['request_id'] as String?;
    final rawSupplied = (json['supplied_evidence_ids'] as List<dynamic>?) ?? [];
    final suppliedEvidenceIds = rawSupplied.map((e) => e.toString()).toSet();
    final answeredAt = json['answered_at'] != null
        ? DateTime.parse(json['answered_at'] as String)
        : DateTime.now();
    final latencyMs = json['latency_ms'] as int?;
    final latency = latencyMs != null
        ? Duration(milliseconds: latencyMs)
        : null;
    final promptEvalCount = json['prompt_eval_count'] as int?;
    final evalCount = json['eval_count'] as int?;

    return GhostAnswer(
      notFound: notFound,
      claims: claims,
      missingEvidence: missingEvidence,
      snapshotId: snapshotId,
      requestId: requestId,
      suppliedEvidenceIds: suppliedEvidenceIds,
      answeredAt: answeredAt,
      latency: latency,
      promptEvalCount: promptEvalCount,
      evalCount: evalCount,
    );
  }
}
