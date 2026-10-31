/// Configurable limit constants for bounded repository scanning.
class ScanLimits {
  final int maxCandidates;
  final int maxListingBytes;
  final int maxFiles;
  final int maxFileSize;
  final int maxTotalBytes;
  final int maxDepth;
  final int maxCommits;
  final Duration scanTimeout;

  const ScanLimits({
    this.maxCandidates = 5000,
    this.maxListingBytes = 2 * 1024 * 1024, // 2 MiB
    this.maxFiles = 50,
    this.maxFileSize = 64 * 1024, // 64 KiB
    this.maxTotalBytes = 2 * 1024 * 1024, // 2 MiB
    this.maxDepth = 4,
    this.maxCommits = 15,
    this.scanTimeout = const Duration(milliseconds: 5000),
  });

  static const ScanLimits standard = ScanLimits();
}
