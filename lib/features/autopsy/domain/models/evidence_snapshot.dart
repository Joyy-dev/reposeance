import 'package:reposeance/features/repository/domain/models/scan_result.dart';

import 'evidence_item.dart';

/// Immutable snapshot containing captured repository evidence items.
class EvidenceSnapshot {
  final String snapshotId;
  final String repositoryRoot;
  final String? headCommit;
  final DateTime createdAt;
  final Map<String, EvidenceItem> _evidenceMap;
  final ScanResult? scanResult;

  EvidenceSnapshot({
    required this.snapshotId,
    required this.repositoryRoot,
    this.headCommit,
    DateTime? createdAt,
    required Map<String, EvidenceItem> evidenceMap,
    this.scanResult,
  }) : createdAt = createdAt ?? DateTime.now(),
       _evidenceMap = Map.unmodifiable(evidenceMap);

  Map<String, EvidenceItem> get evidenceMap => _evidenceMap;

  List<String> get allEvidenceIds => _evidenceMap.keys.toList()..sort();

  List<FileEvidence> get fileEvidence =>
      _evidenceMap.values.whereType<FileEvidence>().toList();

  List<CommitEvidence> get commitEvidence =>
      _evidenceMap.values.whereType<CommitEvidence>().toList();

  EvidenceItem? getEvidence(String id) => _evidenceMap[id];

  bool hasEvidence(String id) => _evidenceMap.containsKey(id);

  /// Deterministically creates an immutable snapshot from a ScanResult.
  /// Files are mapped to IDs E001..E050.
  /// Commits are mapped to IDs E051..E065.
  factory EvidenceSnapshot.fromScanResult(
    ScanResult scanResult, {
    String? snapshotId,
    DateTime? createdAt,
  }) {
    final id = snapshotId ?? 'snap_${DateTime.now().millisecondsSinceEpoch}';
    final map = <String, EvidenceItem>{};

    int fileCounter = 1;
    for (final file in scanResult.files) {
      final evidenceId = 'E${fileCounter.toString().padLeft(3, '0')}';
      map[evidenceId] = FileEvidence(
        id: evidenceId,
        snapshotId: id,
        repositoryRelativePath: file.relativePath,
        startLine: 1,
        endLine: file.lineCount > 0 ? file.lineCount : 1,
        content: file.content,
        contentHash: file.contentHash,
      );
      fileCounter++;
    }

    int commitCounter = 1;
    for (final commit in scanResult.commits) {
      final commitNum = 50 + commitCounter;
      final evidenceId = 'E${commitNum.toString().padLeft(3, '0')}';
      map[evidenceId] = CommitEvidence(
        id: evidenceId,
        snapshotId: id,
        commitHash: commit.hash,
        date: commit.date,
        subject: commit.subject,
        author: commit.author,
      );
      commitCounter++;
    }

    return EvidenceSnapshot(
      snapshotId: id,
      repositoryRoot: scanResult.repositoryInfo.rootPath,
      headCommit:
          scanResult.repositoryInfo.headCommitHash ??
          (scanResult.commits.isNotEmpty
              ? scanResult.commits.first.hash
              : null),
      createdAt: createdAt,
      evidenceMap: map,
      scanResult: scanResult,
    );
  }
}
