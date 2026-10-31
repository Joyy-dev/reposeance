import '../../../core/services/ollama_service.dart';
import '../../../core/utils/git_checker.dart';

/// Diagnostic summary of host system readiness for repository autopsy.
class SystemReadinessState {
  final bool isChecking;
  final GitCheckResult gitResult;
  final OllamaHealthResult ollamaResult;
  final String? selectedDirectory;
  final DateTime? lastChecked;

  const SystemReadinessState({
    required this.isChecking,
    required this.gitResult,
    required this.ollamaResult,
    this.selectedDirectory,
    this.lastChecked,
  });

  factory SystemReadinessState.initial() {
    return const SystemReadinessState(
      isChecking: true,
      gitResult: GitCheckResult.notInstalled('Not checked yet'),
      ollamaResult: OllamaHealthResult(status: OllamaHealthStatus.checking),
      selectedDirectory: null,
      lastChecked: null,
    );
  }

  bool get isGitReady => gitResult.isInstalled;
  bool get isOllamaReady => ollamaResult.isReady;
  bool get isSystemReady => isGitReady && isOllamaReady;
  bool get hasDirectorySelected =>
      selectedDirectory != null && selectedDirectory!.trim().isNotEmpty;
  bool get canProceedToScan => isSystemReady && hasDirectorySelected;

  SystemReadinessState copyWith({
    bool? isChecking,
    GitCheckResult? gitResult,
    OllamaHealthResult? ollamaResult,
    String? selectedDirectory,
    bool clearDirectory = false,
    DateTime? lastChecked,
  }) {
    return SystemReadinessState(
      isChecking: isChecking ?? this.isChecking,
      gitResult: gitResult ?? this.gitResult,
      ollamaResult: ollamaResult ?? this.ollamaResult,
      selectedDirectory: clearDirectory
          ? null
          : (selectedDirectory ?? this.selectedDirectory),
      lastChecked: lastChecked ?? this.lastChecked,
    );
  }
}
