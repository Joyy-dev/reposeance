import 'dart:convert';

import 'package:reposeance/features/autopsy/domain/models/autopsy_finding.dart';

import '../domain/models/ghost_answer.dart';

/// Validation result for GhostAnswer against schema and request allowlist.
class GhostQaValidationResult {
  final GhostAnswer? answer;
  final List<String> errors;

  const GhostQaValidationResult._({this.answer, this.errors = const []});

  factory GhostQaValidationResult.success(GhostAnswer answer) {
    return GhostQaValidationResult._(answer: answer);
  }

  factory GhostQaValidationResult.failure(List<String> errors) {
    return GhostQaValidationResult._(errors: errors);
  }

  bool get isValid => errors.isEmpty && answer != null;
}

/// Pure Dart validator enforcing contracts/ghost-answer.schema.json
/// (Draft 2020-12) and request-level evidence allowlists.
class GhostQaValidator {
  static final RegExp _evidenceIdRegex = RegExp(r'^E[0-9]{3,6}$');

  /// Validates a raw JSON string or decoded Map against ghost-answer schema and supplied allowlist.
  static GhostQaValidationResult validate({
    required dynamic rawJsonOrMap,
    required Set<String> suppliedEvidenceIds,
    String? snapshotId,
    String? requestId,
    Duration? latency,
    String? rawModelResponse,
    int? promptEvalCount,
    int? evalCount,
  }) {
    final List<String> errors = [];

    Map<String, dynamic> data;
    if (rawJsonOrMap is String) {
      try {
        final decoded = jsonDecode(rawJsonOrMap);
        if (decoded is! Map<String, dynamic>) {
          return GhostQaValidationResult.failure([
            'Root JSON must be an object, but got ${decoded.runtimeType}',
          ]);
        }
        data = decoded;
      } catch (e) {
        return GhostQaValidationResult.failure([
          'Malformed JSON: ${e.toString()}',
        ]);
      }
    } else if (rawJsonOrMap is Map<String, dynamic>) {
      data = rawJsonOrMap;
    } else {
      return GhostQaValidationResult.failure([
        'Input must be a JSON String or Map<String, dynamic>, got ${rawJsonOrMap.runtimeType}',
      ]);
    }

    // 1. Required top-level keys
    final requiredKeys = ['not_found', 'claims', 'missing_evidence'];
    for (final key in requiredKeys) {
      if (!data.containsKey(key)) {
        errors.add('Missing required top-level property: "$key"');
      }
    }

    // 2. additionalProperties: false
    for (final key in data.keys) {
      if (!requiredKeys.contains(key)) {
        errors.add(
          'Unexpected top-level property: "$key" (additionalProperties: false)',
        );
      }
    }

    if (errors.isNotEmpty) {
      return GhostQaValidationResult.failure(errors);
    }

    // 3. not_found: boolean
    if (data['not_found'] is! bool) {
      errors.add(
        'Property "not_found" must be a boolean, got ${data['not_found'].runtimeType}',
      );
      return GhostQaValidationResult.failure(errors);
    }
    final bool notFound = data['not_found'] as bool;

    // 4. missing_evidence: string or null, maxLength: 800
    final rawMissing = data['missing_evidence'];
    String? missingEvidence;
    if (rawMissing != null) {
      if (rawMissing is! String) {
        errors.add(
          'Property "missing_evidence" must be a string or null, got ${rawMissing.runtimeType}',
        );
      } else {
        missingEvidence = rawMissing;
        if (missingEvidence.length > 800) {
          errors.add(
            'Property "missing_evidence" exceeds maxLength 800 (got ${missingEvidence.length})',
          );
        }
      }
    }

    // 5. claims: array, maxItems: 5
    final rawClaims = data['claims'];
    final List<AutopsyFinding> claims = [];
    if (rawClaims is! List) {
      errors.add(
        'Property "claims" must be an array, got ${rawClaims.runtimeType}',
      );
    } else {
      if (rawClaims.length > 5) {
        errors.add(
          'Property "claims" exceeds maxItems 5 (got ${rawClaims.length})',
        );
      }
      for (int i = 0; i < rawClaims.length; i++) {
        final item = rawClaims[i];
        if (item is! Map<String, dynamic>) {
          errors.add(
            'claims[$i] must be a finding object, got ${item.runtimeType}',
          );
        } else {
          final claimFinding = _validateFinding(
            rawFinding: item,
            path: 'claims[$i]',
            suppliedEvidenceIds: suppliedEvidenceIds,
            errors: errors,
          );
          if (claimFinding != null) {
            claims.add(claimFinding);
          }
        }
      }
    }

    // 6. allOf conditional constraints
    if (notFound) {
      // If not_found == true: claims maxItems 0, missing_evidence minLength 1
      if (claims.isNotEmpty) {
        errors.add(
          'When "not_found" is true, "claims" must be empty (got ${claims.length} claims)',
        );
      }
      if (missingEvidence == null || missingEvidence.trim().isEmpty) {
        errors.add(
          'When "not_found" is true, "missing_evidence" must be a non-empty string explaining what evidence is missing',
        );
      }
    } else {
      // If not_found == false: claims minItems 1
      if (claims.isEmpty) {
        errors.add(
          'When "not_found" is false, "claims" must contain at least 1 grounded claim',
        );
      }
    }

    if (errors.isNotEmpty) {
      return GhostQaValidationResult.failure(errors);
    }

    final answer = GhostAnswer(
      notFound: notFound,
      claims: claims,
      missingEvidence: missingEvidence,
      snapshotId: snapshotId,
      requestId: requestId,
      suppliedEvidenceIds: suppliedEvidenceIds,
      answeredAt: DateTime.now(),
      latency: latency,
      rawModelResponse: rawModelResponse,
      promptEvalCount: promptEvalCount,
      evalCount: evalCount,
    );

    return GhostQaValidationResult.success(answer);
  }

  /// Validates a single Finding object against schema constraints and request allowlist.
  static AutopsyFinding? _validateFinding({
    required Map<String, dynamic> rawFinding,
    required String path,
    required Set<String> suppliedEvidenceIds,
    required List<String> errors,
  }) {
    final findingErrors = <String>[];

    // additionalProperties: false
    final allowedFindingKeys = ['text', 'kind', 'evidence_ids'];
    for (final key in rawFinding.keys) {
      if (!allowedFindingKeys.contains(key)) {
        findingErrors.add(
          '$path contains unexpected property "$key" (additionalProperties: false)',
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
        if (!suppliedEvidenceIds.contains(idItem)) {
          findingErrors.add(
            '$path cites unsupplied or unknown evidence ID "$idItem" (not in current request allowlist: [${suppliedEvidenceIds.join(', ')}]). Unsupported factual claim rejected.',
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
