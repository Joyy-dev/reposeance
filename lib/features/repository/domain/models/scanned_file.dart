/// Candidate source file inspected and bounded by RepositoryScanner.
class ScannedFile {
  final String relativePath;
  final String fullPath;
  final int byteSize;
  final int lineCount;
  final int priorityTier;
  final String content;
  final String contentHash;

  const ScannedFile({
    required this.relativePath,
    required this.fullPath,
    required this.byteSize,
    required this.lineCount,
    required this.priorityTier,
    required this.content,
    required this.contentHash,
  });

  Map<String, dynamic> toJson() {
    return {
      'relative_path': relativePath,
      'byte_size': byteSize,
      'line_count': lineCount,
      'priority_tier': priorityTier,
      'content_hash': contentHash,
    };
  }

  @override
  String toString() =>
      '$relativePath ($byteSize bytes, $lineCount lines, tier $priorityTier)';
}
