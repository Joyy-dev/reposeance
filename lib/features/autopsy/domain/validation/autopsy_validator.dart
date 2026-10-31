import 'dart:convert';

import '../models/autopsy_finding.dart';
import '../models/autopsy_report.dart';
import '../models/evidence_request_map.dart';
import '../models/revival_step.dart';

/// Result of autopsy validation against schema and evidence request allowlist.
class AutopsyValidationResult {
  final AutopsyReport? report;
  final List<String> errors;

  const AutopsyValidationResult._({this.report, this.errors = const []});

  factory AutopsyValidationResult.success(AutopsyReport report) {
    return AutopsyValidationResult._(report: report);
  }

  factory AutopsyValidationResult.failure(List<String> errors) {
    return AutopsyValidationResult._(errors: errors);
  }

  bool get isValid => errors.isEmpty && report != null;
}

/// Pure Dart validator strictly enforcing contracts/autopsy.schema.json
/// and request-level evidence allowlists.
class AutopsyValidator {
  static final RegExp _evidenceIdRegex = RegExp(r'^E[0-9]{3,6}$');

  /// Validates a raw JSON string or pre-decoded Map against schema constraints and request allowlist.
  static AutopsyValidationResult validate({
    required dynamic rawJsonOrMap,
    required EvidenceRequestMap requestMap,
    required String rawModelResponse,
    required Duration latency,
    int? promptEvalCount,
    int? evalCount,
  }) {
    final List<String> errors = [];

    Map<String, dynamic> data;
    if (rawJsonOrMap is String) {
      try {
        final decoded = jsonDecode(rawJsonOrMap);
        if (decoded is! Map<String, dynamic>) {
          return AutopsyValidationResult.failure([
            'Root JSON must be an object, but got ${decoded.runtimeType}',
          ]);
        }
        data = decoded;
      } catch (e) {
        return AutopsyValidationResult.failure([
          'Malformed JSON: ${e.toString()}',
        ]);
      }
    } else if (rawJsonOrMap is Map<String, dynamic>) {
      data = rawJsonOrMap;
    } else {
      return AutopsyValidationResult.failure([
        'Input must be a JSON String or Map<String, dynamic>, got ${rawJsonOrMap.runtimeType}',
      ]);
    }

    // Top-level required properties
    final requiredKeys = [
      'project_purpose',
      'architecture',
      'findings',
      'revival_plan',
      'unknowns',
    ];
    for (final key in requiredKeys) {
      if (!data.containsKey(key)) {
        errors.add('Missing required top-level property: "$key"');
      }
    }

    // Top-level additionalProperties: false
    for (final key in data.keys) {
      if (!requiredKeys.contains(key)) {
        errors.add(
          'Unexpected top-level property: "$key" (additionalProperties: false)',
        );
      }
    }

    if (errors.isNotEmpty) {
      return AutopsyValidationResult.failure(errors);
    }

    // 1. project_purpose: anyOf [ finding, null ]
    AutopsyFinding? projectPurpose;
    final rawPurpose = data['project_purpose'];
    if (rawPurpose != null) {
      if (rawPurpose is Map<String, dynamic>) {
        final findingErrors = <String>[];
        projectPurpose = _validateFinding(
          rawFinding: rawPurpose,
          path: 'project_purpose',
          requestMap: requestMap,
          errors: findingErrors,
        );
        errors.addAll(findingErrors);
      } else {
        errors.add(
          'Property "project_purpose" must be a finding object or null, got ${rawPurpose.runtimeType}',
        );
      }
    }

    // 2. architecture: array, maxItems 6
    final List<AutopsyFinding> architecture = [];
    final rawArchitecture = data['architecture'];
    if (rawArchitecture is! List) {
      errors.add(
        'Property "architecture" must be an array, got ${rawArchitecture.runtimeType}',
      );
    } else {
      if (rawArchitecture.length > 6) {
        errors.add(
          'Property "architecture" exceeds maxItems 6 (got ${rawArchitecture.length})',
        );
      }
      for (int i = 0; i < rawArchitecture.length; i++) {
        final item = rawArchitecture[i];
        if (item is! Map<String, dynamic>) {
          errors.add(
            'architecture[$i] must be a finding object, got ${item.runtimeType}',
          );
        } else {
          final finding = _validateFinding(
            rawFinding: item,
            path: 'architecture[$i]',
            requestMap: requestMap,
            errors: errors,
          );
          if (finding != null) architecture.add(finding);
        }
      }
    }

    // 3. findings: array, maxItems 8
    final List<AutopsyFinding> findings = [];
    final rawFindings = data['findings'];
    if (rawFindings is! List) {
      errors.add(
        'Property "findings" must be an array, got ${rawFindings.runtimeType}',
      );
    } else {
      if (rawFindings.length > 8) {
        errors.add(
          'Property "findings" exceeds maxItems 8 (got ${rawFindings.length})',
        );
      }
      for (int i = 0; i < rawFindings.length; i++) {
        final item = rawFindings[i];
        if (item is! Map<String, dynamic>) {
          errors.add(
            'findings[$i] must be a finding object, got ${item.runtimeType}',
          );
        } else {
          final finding = _validateFinding(
            rawFinding: item,
            path: 'findings[$i]',
            requestMap: requestMap,
            errors: errors,
          );
          if (finding != null) findings.add(finding);
        }
      }
    }

    // 4. revival_plan: array, maxItems 3
    final List<RevivalStep> revivalPlan = [];
    final rawRevival = data['revival_plan'];
    if (rawRevival is! List) {
      errors.add(
        'Property "revival_plan" must be an array, got ${rawRevival.runtimeType}',
      );
    } else {
      if (rawRevival.length > 3) {
        errors.add(
          'Property "revival_plan" exceeds maxItems 3 (got ${rawRevival.length})',
        );
      }
      for (int i = 0; i < rawRevival.length; i++) {
        final item = rawRevival[i];
        if (item is! Map<String, dynamic>) {
          errors.add(
            'revival_plan[$i] must be an object, got ${item.runtimeType}',
          );
        } else {
          final stepErrors = <String>[];
          // additionalProperties: false
          for (final stepKey in item.keys) {
            if (stepKey != 'step' && stepKey != 'reason') {
              stepErrors.add(
                'revival_plan[$i] contains unexpected property "$stepKey"',
              );
            }
          }
          if (!item.containsKey('step')) {
            stepErrors.add('revival_plan[$i] missing required property "step"');
          }
          if (!item.containsKey('reason')) {
            stepErrors.add(
              'revival_plan[$i] missing required property "reason"',
            );
          }

          String stepText = '';
          if (item['step'] is String) {
            stepText = item['step'] as String;
            if (stepText.isEmpty) {
              stepErrors.add('revival_plan[$i].step must have minLength 1');
            } else if (stepText.length > 400) {
              stepErrors.add(
                'revival_plan[$i].step exceeds maxLength 400 (got ${stepText.length})',
              );
            }
          } else if (item.containsKey('step')) {
            stepErrors.add(
              'revival_plan[$i].step must be a string, got ${item['step'].runtimeType}',
            );
          }

          AutopsyFinding? reasonFinding;
          if (item['reason'] is Map<String, dynamic>) {
            reasonFinding = _validateFinding(
              rawFinding: item['reason'] as Map<String, dynamic>,
              path: 'revival_plan[$i].reason',
              requestMap: requestMap,
              errors: stepErrors,
            );
          } else if (item.containsKey('reason')) {
            stepErrors.add(
              'revival_plan[$i].reason must be a finding object, got ${item['reason'].runtimeType}',
            );
          }

          errors.addAll(stepErrors);
          if (stepErrors.isEmpty && reasonFinding != null) {
            revivalPlan.add(RevivalStep(step: stepText, reason: reasonFinding));
          }
        }
      }
    }

    // 5. unknowns: array, maxItems 8
    final List<String> unknowns = [];
    final rawUnknowns = data['unknowns'];
    if (rawUnknowns is! List) {
      errors.add(
        'Property "unknowns" must be an array, got ${rawUnknowns.runtimeType}',
      );
    } else {
      if (rawUnknowns.length > 8) {
        errors.add(
          'Property "unknowns" exceeds maxItems 8 (got ${rawUnknowns.length})',
        );
      }
      for (int i = 0; i < rawUnknowns.length; i++) {
        final item = rawUnknowns[i];
        if (item is! String) {
          errors.add('unknowns[$i] must be a string, got ${item.runtimeType}');
        } else {
          if (item.isEmpty) {
            errors.add('unknowns[$i] must have minLength 1');
          } else if (item.length > 500) {
            errors.add(
              'unknowns[$i] exceeds maxLength 500 (got ${item.length})',
            );
          } else {
            unknowns.add(item);
          }
        }
      }
    }

    if (errors.isNotEmpty) {
      return AutopsyValidationResult.failure(errors);
    }

    final report = AutopsyReport(
      snapshotId: requestMap.snapshotId,
      requestId: requestMap.requestId,
      projectPurpose: projectPurpose,
      architecture: architecture,
      findings: findings,
      revivalPlan: revivalPlan,
      unknowns: unknowns,
      generatedAt: DateTime.now(),
      rawModelResponse: rawModelResponse,
      latency: latency,
      promptEvalCount: promptEvalCount,
      evalCount: evalCount,
    );

    return AutopsyValidationResult.success(report);
  }

  /// Validates a single Finding object against schema and request allowlist.
  static AutopsyFinding? _validateFinding({
    required Map<String, dynamic> rawFinding,
    required String path,
    required EvidenceRequestMap requestMap,
    required List<String> errors,
  }) {
    final findingErrors = <String>[];

    // additionalProperties: false
    final allowedFindingKeys = ['text', 'kind', 'evidence_ids'];
    for (final key in rawFinding.keys) {
      if (!allowedFindingKeys.contains(key)) {
        findingErrors.add(
          '$path has unexpected property "$key" (additionalProperties: false)',
        );
      }
    }

    // required: text, kind, evidence_ids
    for (final req in allowedFindingKeys) {
      if (!rawFinding.containsKey(req)) {
        findingErrors.add('$path missing required property "$req"');
      }
    }

    // text: string, 1..1200
    String text = '';
    if (rawFinding['text'] is String) {
      text = rawFinding['text'] as String;
      if (text.isEmpty) {
        findingErrors.add('$path.text must have minLength 1');
      } else if (text.length > 1200) {
        findingErrors.add(
          '$path.text exceeds maxLength 1200 (got ${text.length})',
        );
      }
    } else if (rawFinding.containsKey('text')) {
      findingErrors.add(
        '$path.text must be a string, got ${rawFinding['text'].runtimeType}',
      );
    }

    // kind: enum ["observed", "inferred"]
    FindingKind kind = FindingKind.observed;
    if (rawFinding['kind'] is String) {
      final kindStr = rawFinding['kind'] as String;
      if (kindStr == 'observed') {
        kind = FindingKind.observed;
      } else if (kindStr == 'inferred') {
        kind = FindingKind.inferred;
      } else {
        findingErrors.add(
          '$path.kind must be "observed" or "inferred", got "$kindStr"',
        );
      }
    } else if (rawFinding.containsKey('kind')) {
      findingErrors.add(
        '$path.kind must be a string, got ${rawFinding['kind'].runtimeType}',
      );
    }

    // evidence_ids: array, minItems 1, maxItems 5, uniqueItems: true, pattern: ^E[0-9]{3,6}$
    final List<String> evidenceIds = [];
    if (rawFinding['evidence_ids'] is! List) {
      if (rawFinding.containsKey('evidence_ids')) {
        findingErrors.add(
          '$path.evidence_ids must be an array, got ${rawFinding['evidence_ids'].runtimeType}',
        );
      }
    } else {
      final idsList = rawFinding['evidence_ids'] as List;
      if (idsList.isEmpty) {
        findingErrors.add(
          '$path.evidence_ids must contain at least 1 evidence ID (minItems: 1)',
        );
      }
      if (idsList.length > 5) {
        findingErrors.add(
          '$path.evidence_ids exceeds maxItems 5 (got ${idsList.length})',
        );
      }

      final seenIds = <String>{};
      for (int i = 0; i < idsList.length; i++) {
        final idItem = idsList[i];
        if (idItem is! String) {
          findingErrors.add(
            '$path.evidence_ids[$i] must be a string, got ${idItem.runtimeType}',
          );
          continue;
        }

        if (seenIds.contains(idItem)) {
          findingErrors.add(
            '$path.evidence_ids contains duplicate ID "$idItem" (uniqueItems: true)',
          );
        }
        seenIds.add(idItem);

        if (!_evidenceIdRegex.hasMatch(idItem)) {
          findingErrors.add(
            '$path.evidence_ids[$i] "$idItem" does not match required format ^E[0-9]{3,6}\$',
          );
        }

        // CRITICAL EVIDENCE ALLOWLIST INVARIANT:
        // Evidence ID must be present in the active request allowlist.
        // Factual claims citing unsupplied/unknown IDs MUST be rejected, never retained with stripped citations.
        if (!requestMap.isAllowed(idItem)) {
          findingErrors.add(
            '$path cites unsupplied or unknown evidence ID "$idItem" (not in current request allowlist: [${requestMap.allowedIdsSorted.join(', ')}]). Unsupported factual claim rejected.',
          );
        }

        evidenceIds.add(idItem);
      }
    }

    errors.addAll(findingErrors);
    if (findingErrors.isNotEmpty) {
      return null;
    }

    return AutopsyFinding(text: text, kind: kind, evidenceIds: evidenceIds);
  }
}
