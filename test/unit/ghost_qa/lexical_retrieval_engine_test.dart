import 'package:flutter_test/flutter_test.dart';
import 'package:reposeance/features/autopsy/domain/models/evidence_item.dart';
import 'package:reposeance/features/autopsy/domain/models/evidence_snapshot.dart';
import 'package:reposeance/features/ghost_qa/data/lexical_retrieval_engine.dart';

void main() {
  group('LexicalRetrievalEngine', () {
    test(
      'tokenize handles camelCase, snake_case, paths, and filters stop words',
      () {
        final tokens = LexicalRetrievalEngine.tokenize(
          'What is the sqliteDatabase in lib/core/db_helper.dart?',
        );

        expect(tokens, contains('sqlite'));
        expect(tokens, contains('database'));
        expect(tokens, contains('lib'));
        expect(tokens, contains('core'));
        expect(tokens, contains('db'));
        expect(tokens, contains('helper'));
        expect(tokens, contains('dart'));

        // Stop words filtered
        expect(tokens, isNot(contains('what')));
        expect(tokens, isNot(contains('is')));
        expect(tokens, isNot(contains('the')));
        expect(tokens, isNot(contains('in')));
      },
    );

    test(
      'retrieves relevant file evidence based on path and content symbols',
      () {
        final snapshot = EvidenceSnapshot(
          snapshotId: 'snap_test',
          repositoryRoot: 'C:/repos/test',
          evidenceMap: {
            'E001': const FileEvidence(
              id: 'E001',
              snapshotId: 'snap_test',
              repositoryRelativePath: 'lib/services/auth_service.dart',
              startLine: 1,
              endLine: 40,
              content: 'class AuthService { Future<void> signIn() async {} }',
              contentHash: 'hash1',
            ),
            'E002': const FileEvidence(
              id: 'E002',
              snapshotId: 'snap_test',
              repositoryRelativePath: 'lib/database/sqlite_store.dart',
              startLine: 1,
              endLine: 50,
              content: 'class SqliteStore { void openDatabase() {} }',
              contentHash: 'hash2',
            ),
            'E051': CommitEvidence(
              id: 'E051',
              snapshotId: 'snap_test',
              commitHash: 'commit123',
              date: DateTime.now(),
              subject: 'feat: add sqlite database persistence layer',
              author: 'Jane Developer',
            ),
          },
        );

        // Query for authentication
        final authResults = LexicalRetrievalEngine.retrieve(
          snapshot: snapshot,
          query: 'How does authentication work?',
        );

        expect(authResults, isNotEmpty);
        expect(authResults.first.item.id, 'E001');
        expect(authResults.first.matchedTokens, contains('auth'));

        // Query for database
        final dbResults = LexicalRetrievalEngine.retrieve(
          snapshot: snapshot,
          query: 'What database is used for persistence?',
        );

        expect(dbResults, isNotEmpty);
        final retrievedIds = dbResults.map((r) => r.item.id).toList();
        expect(retrievedIds, containsAll(['E002', 'E051']));
      },
    );

    test('returns empty list for completely unrelated query (zero-match short circuit)', () {
      final snapshot = EvidenceSnapshot(
        snapshotId: 'snap_test',
        repositoryRoot: 'C:/repos/test',
        evidenceMap: {
          'E001': const FileEvidence(
            id: 'E001',
            snapshotId: 'snap_test',
            repositoryRelativePath: 'lib/main.dart',
            startLine: 1,
            endLine: 20,
            content: 'void main() { runApp(); }',
            contentHash: 'hash1',
          ),
        },
      );

      final results = LexicalRetrievalEngine.retrieve(
        snapshot: snapshot,
        query: 'quantum tensor superconducting qubits teleportation',
      );

      expect(results, isEmpty);
    });

    test('respects topK bounding and enforces deterministic tie-breaking', () {
      final snapshot = EvidenceSnapshot(
        snapshotId: 'snap_test',
        repositoryRoot: 'C:/repos/test',
        evidenceMap: {
          'E001': const FileEvidence(
            id: 'E001',
            snapshotId: 'snap_test',
            repositoryRelativePath: 'lib/a.dart',
            startLine: 1,
            endLine: 10,
            content: 'int count = 1;',
            contentHash: 'h1',
          ),
          'E002': const FileEvidence(
            id: 'E002',
            snapshotId: 'snap_test',
            repositoryRelativePath: 'lib/b.dart',
            startLine: 1,
            endLine: 10,
            content: 'int count = 2;',
            contentHash: 'h2',
          ),
          'E003': const FileEvidence(
            id: 'E003',
            snapshotId: 'snap_test',
            repositoryRelativePath: 'lib/c.dart',
            startLine: 1,
            endLine: 10,
            content: 'int count = 3;',
            contentHash: 'h3',
          ),
          'E004': const FileEvidence(
            id: 'E004',
            snapshotId: 'snap_test',
            repositoryRelativePath: 'lib/d.dart',
            startLine: 1,
            endLine: 10,
            content: 'int count = 4;',
            contentHash: 'h4',
          ),
          'E005': const FileEvidence(
            id: 'E005',
            snapshotId: 'snap_test',
            repositoryRelativePath: 'lib/e.dart',
            startLine: 1,
            endLine: 10,
            content: 'int count = 5;',
            contentHash: 'h5',
          ),
        },
      );

      final results = LexicalRetrievalEngine.retrieve(
        snapshot: snapshot,
        query: 'count variable',
        topK: 3,
      );

      expect(results.length, 3);
      // Deterministic tie-breaking on ID: E001, E002, E003
      expect(results[0].item.id, 'E001');
      expect(results[1].item.id, 'E002');
      expect(results[2].item.id, 'E003');
    });
  });
}
