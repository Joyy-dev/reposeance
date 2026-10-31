import 'dart:collection';

/// Explicit allowlist mapping the exact evidence IDs supplied in an inference request.
class EvidenceRequestMap {
  final String requestId;
  final String snapshotId;
  final Set<String> _suppliedEvidenceIds;
  final DateTime createdAt;

  EvidenceRequestMap({
    required this.requestId,
    required this.snapshotId,
    required Set<String> suppliedEvidenceIds,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       _suppliedEvidenceIds = UnmodifiableSetView(
         Set.from(suppliedEvidenceIds),
       );

  Set<String> get suppliedEvidenceIds => _suppliedEvidenceIds;

  bool isAllowed(String id) => _suppliedEvidenceIds.contains(id);

  List<String> get allowedIdsSorted => _suppliedEvidenceIds.toList()..sort();
}
