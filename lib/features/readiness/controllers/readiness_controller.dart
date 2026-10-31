import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/ollama_service.dart';
import '../../../core/utils/git_checker.dart';
import '../models/readiness_state.dart';

/// Controller coordinating system readiness diagnostics and target repository selection.
class ReadinessController extends ChangeNotifier {
  final OllamaService _ollamaService;
  final Future<GitCheckResult> Function() _gitChecker;
  SystemReadinessState _state;

  ReadinessController({
    OllamaService? ollamaService,
    Future<GitCheckResult> Function()? gitChecker,
    bool autoCheck = true,
    SystemReadinessState? initialState,
  }) : _ollamaService = ollamaService ?? OllamaService(),
       _gitChecker = gitChecker ?? GitChecker.checkGit,
       _state = initialState ?? SystemReadinessState.initial() {
    if (autoCheck) {
      checkSystemReadiness();
    }
  }

  SystemReadinessState get state => _state;
  OllamaService get ollamaService => _ollamaService;

  /// Runs live diagnostics for Git toolchain and Ollama service reachability.
  Future<void> checkSystemReadiness() async {
    _state = _state.copyWith(isChecking: true);
    notifyListeners();

    try {
      // Concurrently query Git version and Ollama health
      final gitFuture = _gitChecker();
      final ollamaFuture = _ollamaService.checkHealth();

      final results = await Future.wait([gitFuture, ollamaFuture]);
      final gitResult = results[0] as GitCheckResult;
      final ollamaResult = results[1] as OllamaHealthResult;

      _state = _state.copyWith(
        isChecking: false,
        gitResult: gitResult,
        ollamaResult: ollamaResult,
        lastChecked: DateTime.now(),
      );
    } catch (e) {
      _state = _state.copyWith(
        isChecking: false,
        gitResult: GitCheckResult.notInstalled(e.toString()),
        ollamaResult: OllamaHealthResult(
          status: OllamaHealthStatus.unreachable,
          error: e.toString(),
        ),
        lastChecked: DateTime.now(),
      );
    }

    notifyListeners();
  }

  /// Triggers native Windows directory picker dialog.
  Future<void> pickDirectory() async {
    try {
      final selectedPath = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select Git Repository for Autopsy',
      );

      if (selectedPath != null && selectedPath.trim().isNotEmpty) {
        _state = _state.copyWith(selectedDirectory: selectedPath.trim());
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error opening directory picker: $e');
    }
  }

  /// Manually set or update repository directory path.
  void setDirectory(String path) {
    if (path.trim().isEmpty) {
      _state = _state.copyWith(clearDirectory: true);
    } else {
      _state = _state.copyWith(selectedDirectory: path.trim());
    }
    notifyListeners();
  }

  /// Clears currently selected repository path.
  void clearDirectory() {
    _state = _state.copyWith(clearDirectory: true);
    notifyListeners();
  }

  @override
  void dispose() {
    _ollamaService.dispose();
    super.dispose();
  }
}
