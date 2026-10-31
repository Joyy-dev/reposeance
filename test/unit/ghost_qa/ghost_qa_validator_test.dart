import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:reposeance/features/ghost_qa/data/ghost_qa_validator.dart';
import 'package:reposeance/features/autopsy/domain/models/autopsy_finding.dart';

void main() {
  group('GhostQaValidator', () {
    final defaultAllowlist = {'E001', 'E002', 'E003', 'E051'};

    test('validates grounded answer with observed and inferred claims', () {
      final jsonMap = {
        'not_found': false,
        'claims': [
          {
            'text': 'The project uses SQLite for local state persistence.',
            'kind': 'observed',
            'evidence_ids': ['E001', 'E002'],
          },
          {
            'text': 'The architecture indicates a modular local-first repository structure.',
            'kind': 'inferred',
            'evidence_ids': ['E003'],
          },
        ],
        'missing_evidence': null,
      };

      final result = GhostQaValidator.validate(
        rawJsonOrMap: jsonMap,
        suppliedEvidenceIds: defaultAllowlist,
        snapshotId: 'snap_123',
        requestId: 'req_456',
      );

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
      expect(result.answer, isNotNull);
      expect(result.answer!.notFound, isFalse);
      expect(result.answer!.claims.length, 2);
      expect(result.answer!.claims[0].kind, FindingKind.observed);
      expect(result.answer!.claims[1].kind, FindingKind.inferred);
      expect(result.answer!.claims[0].evidenceIds, ['E001', 'E002']);
    });

    test('validates valid not_found answer with honest missing_evidence', () {
      final jsonMap = {
        'not_found': true,
        'claims': [],
        'missing_evidence': 'The supplied files and commits do not document why SQLite was chosen over PostgreSQL.',
      };

      final result = GhostQaValidator.validate(
        rawJsonOrMap: jsonMap,
        suppliedEvidenceIds: defaultAllowlist,
      );

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
      expect(result.answer, isNotNull);
      expect(result.answer!.notFound, isTrue);
      expect(result.answer!.claims, isEmpty);
      expect(result.answer!.missingEvidence, contains('do not document'));
    });

    test('accepts raw valid JSON string', () {
      final jsonStr = jsonEncode({
        'not_found': false,
        'claims': [
          {
            'text': 'The initial commit establishes core configuration.',
            'kind': 'observed',
            'evidence_ids': ['E051'],
          },
        ],
        'missing_evidence': null,
      });

      final result = GhostQaValidator.validate(
        rawJsonOrMap: jsonStr,
        suppliedEvidenceIds: defaultAllowlist,
      );

      expect(result.isValid, isTrue);
      expect(result.answer!.claims.first.evidenceIds, ['E051']);
    });

    test('rejects malformed JSON string', () {
      final result = GhostQaValidator.validate(
        rawJsonOrMap: '{"not_found": false, invalid',
        suppliedEvidenceIds: defaultAllowlist,
      );

      expect(result.isValid, isFalse);
      expect(result.errors.first, contains('Malformed JSON'));
    });

    test('rejects non-object root JSON', () {
      final result = GhostQaValidator.validate(
        rawJsonOrMap: '[1, 2, 3]',
        suppliedEvidenceIds: defaultAllowlist,
      );

      expect(result.isValid, isFalse);
      expect(result.errors.first, contains('Root JSON must be an object'));
    });

    test('rejects missing top-level properties', () {
      final jsonMap = {
        'not_found': false,
        // missing 'claims' and 'missing_evidence'
      };

      final result = GhostQaValidator.validate(
        rawJsonOrMap: jsonMap,
        suppliedEvidenceIds: defaultAllowlist,
      );

      expect(result.isValid, isFalse);
      expect(
        result.errors,
        anyElement(contains('Missing required top-level property: "claims"')),
      );
      expect(
        result.errors,
        anyElement(
          contains('Missing required top-level property: "missing_evidence"'),
        ),
      );
    });

    test('rejects unexpected properties (additionalProperties: false)', () {
      final jsonMap = {
        'not_found': false,
        'claims': [
          {
            'text': 'Valid claim text.',
            'kind': 'observed',
            'evidence_ids': ['E001'],
          },
        ],
        'missing_evidence': null,
        'confidence': 'high', // Old MVP property forbidden
        'extra_field': 'not allowed',
      };

      final result = GhostQaValidator.validate(
        rawJsonOrMap: jsonMap,
        suppliedEvidenceIds: defaultAllowlist,
      );

      expect(result.isValid, isFalse);
      expect(
        result.errors,
        anyElement(contains('Unexpected top-level property: "confidence"')),
      );
      expect(
        result.errors,
        anyElement(contains('Unexpected top-level property: "extra_field"')),
      );
    });

    test('rejects not_found == true with non-empty claims', () {
      final jsonMap = {
        'not_found': true,
        'claims': [
          {
            'text': 'Claim that should not exist when not_found is true.',
            'kind': 'observed',
            'evidence_ids': ['E001'],
          },
        ],
        'missing_evidence': 'Missing evidence description.',
      };

      final result = GhostQaValidator.validate(
        rawJsonOrMap: jsonMap,
        suppliedEvidenceIds: defaultAllowlist,
      );

      expect(result.isValid, isFalse);
      expect(
        result.errors,
        anyElement(
          contains('When "not_found" is true, "claims" must be empty'),
        ),
      );
    });

    test(
      'rejects not_found == true with missing or empty missing_evidence',
      () {
        final jsonMap = {
          'not_found': true,
          'claims': [],
          'missing_evidence': '   ',
        };

        final result = GhostQaValidator.validate(
          rawJsonOrMap: jsonMap,
          suppliedEvidenceIds: defaultAllowlist,
        );

        expect(result.isValid, isFalse);
        expect(
          result.errors,
          anyElement(
            contains(
              'When "not_found" is true, "missing_evidence" must be a non-empty string',
            ),
          ),
        );
      },
    );

    test('rejects not_found == false with empty claims', () {
      final jsonMap = {
        'not_found': false,
        'claims': [],
        'missing_evidence': null,
      };

      final result = GhostQaValidator.validate(
        rawJsonOrMap: jsonMap,
        suppliedEvidenceIds: defaultAllowlist,
      );

      expect(result.isValid, isFalse);
      expect(
        result.errors,
        anyElement(
          contains(
            'When "not_found" is false, "claims" must contain at least 1 grounded claim',
          ),
        ),
      );
    });

    test('rejects claim with invalid kind enum', () {
      final jsonMap = {
        'not_found': false,
        'claims': [
          {
            'text': 'Valid claim.',
            'kind': 'speculated', // invalid
            'evidence_ids': ['E001'],
          },
        ],
        'missing_evidence': null,
      };

      final result = GhostQaValidator.validate(
        rawJsonOrMap: jsonMap,
        suppliedEvidenceIds: defaultAllowlist,
      );

      expect(result.isValid, isFalse);
      expect(
        result.errors,
        anyElement(contains('must be "observed" or "inferred"')),
      );
    });

    test('rejects claim with invalid evidence ID regex pattern', () {
      final jsonMap = {
        'not_found': false,
        'claims': [
          {
            'text': 'Valid claim.',
            'kind': 'observed',
            'evidence_ids': ['E-FILE-001'], // legacy hyphenated format invalid
          },
        ],
        'missing_evidence': null,
      };

      final result = GhostQaValidator.validate(
        rawJsonOrMap: jsonMap,
        suppliedEvidenceIds: defaultAllowlist,
      );

      expect(result.isValid, isFalse);
      expect(
        result.errors,
        anyElement(contains('does not match required format ^E[0-9]{3,6}\$')),
      );
    });

    test('rejects claim with duplicate evidence IDs', () {
      final jsonMap = {
        'not_found': false,
        'claims': [
          {
            'text': 'Valid claim.',
            'kind': 'observed',
            'evidence_ids': ['E001', 'E001'],
          },
        ],
        'missing_evidence': null,
      };

      final result = GhostQaValidator.validate(
        rawJsonOrMap: jsonMap,
        suppliedEvidenceIds: defaultAllowlist,
      );

      expect(result.isValid, isFalse);
      expect(
        result.errors,
        anyElement(contains('duplicate ID "E001" (uniqueItems: true)')),
      );
    });

    test(
      'CRITICAL: rejects claim citing unsupplied evidence ID (e.g. E999)',
      () {
        final jsonMap = {
          'not_found': false,
          'claims': [
            {
              'text': 'Claim citing hallucinated unsupplied probe evidence.',
              'kind': 'observed',
              'evidence_ids': ['E999'],
            },
          ],
          'missing_evidence': null,
        };

        final result = GhostQaValidator.validate(
          rawJsonOrMap: jsonMap,
          suppliedEvidenceIds:
              defaultAllowlist, // E999 is NOT in defaultAllowlist
        );

        expect(result.isValid, isFalse);
        expect(
          result.errors,
          anyElement(
            contains('cites unsupplied or unknown evidence ID "E999"'),
          ),
        );
        expect(
          result.errors,
          anyElement(contains('Unsupported factual claim rejected')),
        );
      },
    );

    test('rejects claim text exceeding maxLength 1200', () {
      final oversizedText = 'A' * 1201;
      final jsonMap = {
        'not_found': false,
        'claims': [
          {
            'text': oversizedText,
            'kind': 'observed',
            'evidence_ids': ['E001'],
          },
        ],
        'missing_evidence': null,
      };

      final result = GhostQaValidator.validate(
        rawJsonOrMap: jsonMap,
        suppliedEvidenceIds: defaultAllowlist,
      );

      expect(result.isValid, isFalse);
      expect(result.errors, anyElement(contains('exceeds maxLength 1200')));
    });
  });
}
