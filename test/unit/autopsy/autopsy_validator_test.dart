import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:reposeance/features/autopsy/domain/models/autopsy_finding.dart';
import 'package:reposeance/features/autopsy/domain/models/evidence_request_map.dart';
import 'package:reposeance/features/autopsy/domain/validation/autopsy_validator.dart';

void main() {
  group('AutopsyValidator Contract & Allowlist Tests', () {
    late EvidenceRequestMap validRequestMap;

    setUp(() {
      validRequestMap = EvidenceRequestMap(
        requestId: 'req_test_100',
        snapshotId: 'snap_test_1',
        suppliedEvidenceIds: {'E001', 'E002', 'E051'},
      );
    });

    Map<String, dynamic> createValidAutopsyJson() {
      return {
        'project_purpose': {
          'text': 'A barcode scanning warehouse stock utility.',
          'kind': 'observed',
          'evidence_ids': ['E001', 'E002'],
        },
        'architecture': [
          {
            'text': 'Flutter application structured around pubspec.yaml.',
            'kind': 'observed',
            'evidence_ids': ['E001'],
          },
        ],
        'findings': [
          {
            'text':
                'Initial commit created barcode scanner and sqlite database.',
            'kind': 'observed',
            'evidence_ids': ['E051'],
          },
        ],
        'revival_plan': [
          {
            'step': 'Implement SQLite migrations and write automated tests.',
            'reason': {
              'text': 'README notes SQLite migrations are incomplete and no tests exist.',
              'kind': 'inferred',
              'evidence_ids': ['E002'],
            },
          },
        ],
        'unknowns': [
          'Remote cloud API endpoints and sync credentials are not present in evidence.',
        ],
      };
    }

    test('valid synthetic autopsy JSON passes validation and produces AutopsyReport', () {
      final jsonMap = createValidAutopsyJson();
      final result = AutopsyValidator.validate(
        rawJsonOrMap: jsonMap,
        requestMap: validRequestMap,
        rawModelResponse: jsonEncode(jsonMap),
        latency: const Duration(seconds: 2),
      );

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
      expect(result.report, isNotNull);

      final report = result.report!;
      expect(report.projectPurpose?.kind, equals(FindingKind.observed));
      expect(report.projectPurpose?.evidenceIds, equals(['E001', 'E002']));
      expect(report.architecture.length, equals(1));
      expect(report.findings.length, equals(1));
      expect(report.revivalPlan.length, equals(1));
      expect(report.revivalPlan.first.step, contains('SQLite migrations'));
      expect(
        report.revivalPlan.first.reason.kind,
        equals(FindingKind.inferred),
      );
      expect(report.unknowns.length, equals(1));
    });

    test('project_purpose can be null if unsupported by evidence', () {
      final jsonMap = createValidAutopsyJson();
      jsonMap['project_purpose'] = null;

      final result = AutopsyValidator.validate(
        rawJsonOrMap: jsonMap,
        requestMap: validRequestMap,
        rawModelResponse: jsonEncode(jsonMap),
        latency: const Duration(seconds: 1),
      );

      expect(result.isValid, isTrue);
      expect(result.report?.projectPurpose, isNull);
    });

    test('malformed JSON string returns failure', () {
      final result = AutopsyValidator.validate(
        rawJsonOrMap: '{ this is not valid json',
        requestMap: validRequestMap,
        rawModelResponse: '{ this is not valid json',
        latency: Duration.zero,
      );

      expect(result.isValid, isFalse);
      expect(result.errors.first, contains('Malformed JSON'));
    });

    test('missing required top-level property returns failure', () {
      final jsonMap = createValidAutopsyJson();
      jsonMap.remove('unknowns');

      final result = AutopsyValidator.validate(
        rawJsonOrMap: jsonMap,
        requestMap: validRequestMap,
        rawModelResponse: jsonEncode(jsonMap),
        latency: Duration.zero,
      );

      expect(result.isValid, isFalse);
      expect(
        result.errors.any(
          (e) => e.contains('Missing required top-level property: "unknowns"'),
        ),
        isTrue,
      );
    });

    test(
      'unexpected top-level property triggers additionalProperties violation',
      () {
        final jsonMap = createValidAutopsyJson();
        jsonMap['confidence_score'] = 0.95; // Prohibited property

        final result = AutopsyValidator.validate(
          rawJsonOrMap: jsonMap,
          requestMap: validRequestMap,
          rawModelResponse: jsonEncode(jsonMap),
          latency: Duration.zero,
        );

        expect(result.isValid, isFalse);
        expect(
          result.errors.any(
            (e) =>
                e.contains('Unexpected top-level property: "confidence_score"'),
          ),
          isTrue,
        );
      },
    );

    test('string length limits are enforced', () {
      final jsonMap = createValidAutopsyJson();

      // Finding text > 1200 chars
      jsonMap['findings'] = [
        {
          'text': 'A' * 1201,
          'kind': 'observed',
          'evidence_ids': ['E001'],
        },
      ];

      // Revival step > 400 chars
      jsonMap['revival_plan'] = [
        {
          'step': 'B' * 401,
          'reason': {
            'text': 'Valid reason',
            'kind': 'inferred',
            'evidence_ids': ['E001'],
          },
        },
      ];

      // Unknown > 500 chars
      jsonMap['unknowns'] = ['C' * 501];

      final result = AutopsyValidator.validate(
        rawJsonOrMap: jsonMap,
        requestMap: validRequestMap,
        rawModelResponse: jsonEncode(jsonMap),
        latency: Duration.zero,
      );

      expect(result.isValid, isFalse);
      expect(
        result.errors.any(
          (e) => e.contains('findings[0].text exceeds maxLength 1200'),
        ),
        isTrue,
      );
      expect(
        result.errors.any(
          (e) => e.contains('revival_plan[0].step exceeds maxLength 400'),
        ),
        isTrue,
      );
      expect(
        result.errors.any(
          (e) => e.contains('unknowns[0] exceeds maxLength 500'),
        ),
        isTrue,
      );
    });

    test('array item count limits are strictly enforced', () {
      final jsonMap = createValidAutopsyJson();

      // architecture maxItems: 6 -> supply 7
      jsonMap['architecture'] = List.generate(
        7,
        (i) => {
          'text': 'Architecture component $i',
          'kind': 'observed',
          'evidence_ids': ['E001'],
        },
      );

      // findings maxItems: 8 -> supply 9
      jsonMap['findings'] = List.generate(
        9,
        (i) => {
          'text': 'Finding $i',
          'kind': 'observed',
          'evidence_ids': ['E001'],
        },
      );

      // revival_plan maxItems: 3 -> supply 4
      jsonMap['revival_plan'] = List.generate(
        4,
        (i) => {
          'step': 'Step $i',
          'reason': {
            'text': 'Reason $i',
            'kind': 'inferred',
            'evidence_ids': ['E001'],
          },
        },
      );

      // unknowns maxItems: 8 -> supply 9
      jsonMap['unknowns'] = List.generate(9, (i) => 'Unknown $i');

      final result = AutopsyValidator.validate(
        rawJsonOrMap: jsonMap,
        requestMap: validRequestMap,
        rawModelResponse: jsonEncode(jsonMap),
        latency: Duration.zero,
      );

      expect(result.isValid, isFalse);
      expect(
        result.errors.any(
          (e) => e.contains('Property "architecture" exceeds maxItems 6'),
        ),
        isTrue,
      );
      expect(
        result.errors.any(
          (e) => e.contains('Property "findings" exceeds maxItems 8'),
        ),
        isTrue,
      );
      expect(
        result.errors.any(
          (e) => e.contains('Property "revival_plan" exceeds maxItems 3'),
        ),
        isTrue,
      );
      expect(
        result.errors.any(
          (e) => e.contains('Property "unknowns" exceeds maxItems 8'),
        ),
        isTrue,
      );
    });

    test(
      'cites unsupplied evidence ID E999 triggers rejection of factual claim',
      () {
        final jsonMap = createValidAutopsyJson();
        // Valid regex format ^E[0-9]{3,6}$ but NOT in validRequestMap ({E001, E002, E051})
        jsonMap['findings'] = [
          {
            'text': 'Cloud credentials leaked in test files.',
            'kind': 'observed',
            'evidence_ids': ['E999'],
          },
        ];

        final result = AutopsyValidator.validate(
          rawJsonOrMap: jsonMap,
          requestMap: validRequestMap,
          rawModelResponse: jsonEncode(jsonMap),
          latency: Duration.zero,
        );

        expect(result.isValid, isFalse);
        expect(
          result.errors.any(
            (e) =>
                e.contains('cites unsupplied or unknown evidence ID "E999"') &&
                e.contains('Unsupported factual claim rejected.'),
          ),
          isTrue,
        );
      },
    );

    test('finding kind must strictly be observed or inferred', () {
      final jsonMap = createValidAutopsyJson();
      jsonMap['findings'] = [
        {
          'text': 'Finding text',
          'kind': 'hallucinated_kind',
          'evidence_ids': ['E001'],
        },
      ];

      final result = AutopsyValidator.validate(
        rawJsonOrMap: jsonMap,
        requestMap: validRequestMap,
        rawModelResponse: jsonEncode(jsonMap),
        latency: Duration.zero,
      );

      expect(result.isValid, isFalse);
      expect(
        result.errors.any(
          (e) =>
              e.contains('findings[0].kind must be "observed" or "inferred"'),
        ),
        isTrue,
      );
    });
  });
}
