import 'package:path/path.dart' as p;

/// Target repository identity and branch/HEAD status.
class RepositoryInfo {
  final String rootPath;
  final String name;
  final String? currentBranch;
  final bool isDetachedHead;
  final bool isEmpty;
  final String? headCommitHash;

  const RepositoryInfo({
    required this.rootPath,
    required this.name,
    this.currentBranch,
    this.isDetachedHead = false,
    this.isEmpty = false,
    this.headCommitHash,
  });

  factory RepositoryInfo.fromPath(
    String rootPath, {
    String? currentBranch,
    bool isDetachedHead = false,
    bool isEmpty = false,
    String? headCommitHash,
  }) {
    final normalized = p.normalize(rootPath);
    final name = p.basename(normalized);
    return RepositoryInfo(
      rootPath: normalized,
      name: name.isEmpty ? 'repository' : name,
      currentBranch: currentBranch,
      isDetachedHead: isDetachedHead,
      isEmpty: isEmpty,
      headCommitHash: headCommitHash,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'root_path': rootPath,
      'name': name,
      'current_branch': currentBranch,
      'is_detached_head': isDetachedHead,
      'is_empty': isEmpty,
      'head_commit_hash': headCommitHash,
    };
  }
}
