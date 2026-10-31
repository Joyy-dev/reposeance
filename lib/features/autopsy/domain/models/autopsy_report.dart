import 'autopsy_finding.dart';
import 'revival_step.dart';

/// Complete structured repository autopsy report validated against contracts/autopsy.schema.json.
class AutopsyReport {
  final String snapshotId;
  final String requestId;
  final AutopsyFinding? projectPurpose;
  final List<AutopsyFinding> architecture;
  final List<AutopsyFinding> findings;
  final List<RevivalStep> revivalPlan;
  final List<String> unknowns;
  final DateTime generatedAt;
  final String rawModelResponse;
  final Duration latency;
  final int? promptEvalCount;
  final int? evalCount;

  const AutopsyReport({
    required this.snapshotId,
    required this.requestId,
    this.projectPurpose,
    required this.architecture,
    required this.findings,
    required this.revivalPlan,
    required this.unknowns,
    required this.generatedAt,
    required this.rawModelResponse,
    required this.latency,
    this.promptEvalCount,
    this.evalCount,
  });

  Map<String, dynamic> toJson() => {
    'snapshotId': snapshotId,
    'requestId': requestId,
    'project_purpose': projectPurpose?.toJson(),
    'architecture': architecture.map((e) => e.toJson()).toList(),
    'findings': findings.map((e) => e.toJson()).toList(),
    'revival_plan': revivalPlan.map((e) => e.toJson()).toList(),
    'unknowns': unknowns,
    'generatedAt': generatedAt.toIso8601String(),
    'latencyMs': latency.inMilliseconds,
    if (promptEvalCount != null) 'promptEvalCount': promptEvalCount,
    if (evalCount != null) 'evalCount': evalCount,
  };
}
