enum EvidenceType { file, commit }

/// Base tagged union for evidence items stored in an immutable snapshot.
abstract class EvidenceItem {
  String get id;
  String get snapshotId;
  EvidenceType get type;
}

/// A captured repository file excerpt with provenance metadata.
class FileEvidence implements EvidenceItem {
  @override
  final String id;

  @override
  final String snapshotId;

  @override
  EvidenceType get type => EvidenceType.file;

  final String repositoryRelativePath;
  final int startLine;
  final int endLine;
  final String content;
  final String contentHash;

  const FileEvidence({
    required this.id,
    required this.snapshotId,
    required this.repositoryRelativePath,
    required this.startLine,
    required this.endLine,
    required this.content,
    required this.contentHash,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'snapshotId': snapshotId,
    'type': 'file',
    'repositoryRelativePath': repositoryRelativePath,
    'startLine': startLine,
    'endLine': endLine,
    'content': content,
    'contentHash': contentHash,
  };
}

/// A captured Git commit record. Commits are distinct from file line references.
class CommitEvidence implements EvidenceItem {
  @override
  final String id;

  @override
  final String snapshotId;

  @override
  EvidenceType get type => EvidenceType.commit;

  final String commitHash;
  final DateTime date;
  final String subject;
  final String? author;

  const CommitEvidence({
    required this.id,
    required this.snapshotId,
    required this.commitHash,
    required this.date,
    required this.subject,
    this.author,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'snapshotId': snapshotId,
    'type': 'commit',
    'commitHash': commitHash,
    'date': date.toIso8601String(),
    'subject': subject,
    if (author != null) 'author': author,
  };
}
