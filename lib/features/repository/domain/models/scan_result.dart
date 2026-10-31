import 'git_commit.dart';
import 'repository_info.dart';
import 'scanned_file.dart';

/// Aggregated result of bounded repository inspection.
class ScanResult {
  final RepositoryInfo repositoryInfo;
  final List<ScannedFile> files;
  final List<GitCommit> commits;
  final List<String> partialWarnings;
  final int totalCandidatesEnumerated;
  final int totalBytesRead;
  final int scanDurationMs;

  const ScanResult({
    required this.repositoryInfo,
    required this.files,
    required this.commits,
    this.partialWarnings = const [],
    required this.totalCandidatesEnumerated,
    required this.totalBytesRead,
    required this.scanDurationMs,
  });

  bool get hasWarnings => partialWarnings.isNotEmpty;
  bool get isPartial => partialWarnings.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'repository': repositoryInfo.toJson(),
      'selected_file_count': files.length,
      'commit_count': commits.length,
      'total_candidates_enumerated': totalCandidatesEnumerated,
      'total_bytes_read': totalBytesRead,
      'scan_duration_ms': scanDurationMs,
      'partial_warnings': partialWarnings,
      'files': files.map((f) => f.toJson()).toList(),
      'commits': commits.map((c) => c.toJson()).toList(),
    };
  }
}
