import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:reposeance/core/services/ollama_service.dart';
import 'package:reposeance/core/utils/git_checker.dart';
import 'package:reposeance/features/autopsy/data/autopsy_service.dart';
import 'package:reposeance/features/autopsy/domain/models/evidence_snapshot.dart';
import 'package:reposeance/features/ghost_qa/data/ghost_qa_service.dart';
import 'package:reposeance/features/ghost_qa/domain/models/ghost_question.dart';
import 'package:reposeance/features/repository/data/git_service.dart';
import 'package:reposeance/features/repository/data/repository_scanner.dart';
import 'package:reposeance/features/workbench/domain/models/workbench_state.dart';

/// Main controller coordinating repository selection, bounded scanning,
/// local autopsy generation, stage progression, evidence drawer, and Ask the Ghost Q&A.
class WorkbenchController extends ChangeNotifier {
  final GitService _gitService;
  final RepositoryScanner _scanner;
  final OllamaService _ollamaService;
  final AutopsyService _autopsyService;
  final GhostQaService _ghostQaService;
  final Future<GitCheckResult> Function() _gitChecker;

  WorkbenchState _state;
  Timer? _elapsedTimer;
  Timer? _ghostQaElapsedTimer;
  bool _isDisposed = false;
  bool _isCancelled = false;

  WorkbenchController({
    GitService? gitService,
    RepositoryScanner? scanner,
    OllamaService? ollamaService,
    AutopsyService? autopsyService,
    GhostQaService? ghostQaService,
    Future<GitCheckResult> Function()? gitChecker,
    WorkbenchState? initialState,
    bool autoCheckReadiness = true,
  }) : _gitService = gitService ?? GitService(),
       _scanner = scanner ?? RepositoryScanner(),
       _ollamaService = ollamaService ?? OllamaService(),
       _autopsyService =
           autopsyService ??
           AutopsyService(ollamaService: ollamaService ?? OllamaService()),
       _ghostQaService =
           ghostQaService ??
           GhostQaService(ollamaService: ollamaService ?? OllamaService()),
       _gitChecker = gitChecker ?? GitChecker.checkGit,
       _state = initialState ?? WorkbenchState.initial() {
    if (autoCheckReadiness) {
      checkSystemReadiness();
    }
  }

  WorkbenchState get state => _state;
  GitService get gitService => _gitService;
  RepositoryScanner get scanner => _scanner;
  OllamaService get ollamaService => _ollamaService;
  AutopsyService get autopsyService => _autopsyService;
  GhostQaService get ghostQaService => _ghostQaService;

  @override
  void dispose() {
    _isDisposed = true;
    _elapsedTimer?.cancel();
    _ghostQaElapsedTimer?.cancel();
    _autopsyService.cancelCurrentRequest();
    _ghostQaService.cancelCurrentRequest();
    super.dispose();
  }

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  /// Runs host environment diagnostics for Git and Ollama loopback connectivity.
  Future<void> checkSystemReadiness() async {
    _state = _state.copyWith(
      readinessState: _state.readinessState.copyWith(isChecking: true),
    );
    _safeNotifyListeners();

    try {
      final gitFuture = _gitChecker();
      final ollamaFuture = _ollamaService.checkHealth();

      final results = await Future.wait([gitFuture, ollamaFuture]);
      final gitResult = results[0] as GitCheckResult;
      final ollamaResult = results[1] as OllamaHealthResult;

      _state = _state.copyWith(
        readinessState: _state.readinessState.copyWith(
          isChecking: false,
          gitResult: gitResult,
          ollamaResult: ollamaResult,
          lastChecked: DateTime.now(),
        ),
      );
    } catch (e) {
      _state = _state.copyWith(
        readinessState: _state.readinessState.copyWith(
          isChecking: false,
          gitResult: GitCheckResult.notInstalled(e.toString()),
          ollamaResult: OllamaHealthResult(
            status: OllamaHealthStatus.unreachable,
            error: e.toString(),
          ),
          lastChecked: DateTime.now(),
        ),
      );
    }

    _safeNotifyListeners();
  }

  /// Opens the native Windows folder picker to select a Git repository.
  Future<void> pickDirectory() async {
    try {
      final selectedPath = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select Git Repository for Autopsy',
      );

      if (selectedPath != null && selectedPath.trim().isNotEmpty) {
        await setDirectory(selectedPath.trim());
      }
    } catch (e) {
      debugPrint('Error opening directory picker: $e');
    }
  }

  /// Validates and sets target repository path.
  Future<void> setDirectory(String path) async {
    // Prevent cross-repository pollution: clear all prior Q&A and reports
    _ghostQaElapsedTimer?.cancel();
    _ghostQaService.cancelCurrentRequest();

    if (path.trim().isEmpty) {
      _state = _state.copyWith(
        clearDirectory: true,
        clearRepositoryInfo: true,
        clearScanResult: true,
        clearEvidenceSnapshot: true,
        clearAutopsyReport: true,
        clearActiveEvidence: true,
        clearErrorMessage: true,
        clearGhostQuestion: true,
        clearGhostAnswer: true,
        ghostQaStatus: GhostQaStatus.idle,
        ghostQaStageText: '',
        clearGhostQaErrorMessage: true,
        status: InvestigationStatus.idle,
        stage: ScanStage.idle,
        stageMessage: '',
      );
      _safeNotifyListeners();
      return;
    }

    final rootResult = await _gitService.resolveRepositoryRoot(path);
    switch (rootResult) {
      case GitRootSuccess(:final canonicalRoot):
        final repoInfo = await _gitService.getRepositoryInfo(canonicalRoot);

        _state = _state.copyWith(
          selectedDirectory: canonicalRoot,
          repositoryInfo: repoInfo,
          clearScanResult: true,
          clearEvidenceSnapshot: true,
          clearAutopsyReport: true,
          clearActiveEvidence: true,
          clearErrorMessage: true,
          clearGhostQuestion: true,
          clearGhostAnswer: true,
          ghostQaStatus: GhostQaStatus.idle,
          ghostQaStageText: '',
          clearGhostQaErrorMessage: true,
          status: InvestigationStatus.idle,
          stage: ScanStage.idle,
          stageMessage: '',
        );
        _safeNotifyListeners();

      case GitRootNotARepository(:final message):
        _state = _state.copyWith(
          selectedDirectory: path,
          clearRepositoryInfo: true,
          clearGhostQuestion: true,
          clearGhostAnswer: true,
          ghostQaStatus: GhostQaStatus.idle,
          errorMessage: 'Directory is not a Git repository: $message',
          status: InvestigationStatus.failed,
        );
        _safeNotifyListeners();

      case GitRootNotInstalled(:final error):
        _state = _state.copyWith(
          selectedDirectory: path,
          clearRepositoryInfo: true,
          errorMessage: 'Git is not installed: $error',
          status: InvestigationStatus.failed,
        );
        _safeNotifyListeners();

      case GitRootFailure(:final error):
        _state = _state.copyWith(
          selectedDirectory: path,
          clearRepositoryInfo: true,
          errorMessage: 'Failed to access repository: $error',
          status: InvestigationStatus.failed,
        );
        _safeNotifyListeners();
    }
  }

  /// Initiates the full investigation workflow:
  /// 1. Bounded repository scan (M3)
  /// 2. Immutable evidence snapshot construction (M4)
  /// 3. Local Gemma autopsy generation (M4)
  Future<void> startInvestigation() async {
    final root = _state.selectedDirectory;
    if (root == null || _state.repositoryInfo == null) {
      _state = _state.copyWith(
        errorMessage: 'Please select a valid Git repository first.',
        status: InvestigationStatus.failed,
      );
      _safeNotifyListeners();
      return;
    }

    _isCancelled = false;
    _elapsedTimer?.cancel();

    _state = _state.copyWith(
      status: InvestigationStatus.scanning,
      stage: ScanStage.enumerating,
      stageMessage: 'Stage 1/4: Enumerating tracked Git files...',
      elapsedDuration: Duration.zero,
      clearErrorMessage: true,
      clearActiveEvidence: true,
    );
    _safeNotifyListeners();

    // Start live elapsed timer
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isDisposed && !_isCancelled) {
        _state = _state.copyWith(
          elapsedDuration: _state.elapsedDuration + const Duration(seconds: 1),
        );
        _safeNotifyListeners();
      }
    });

    try {
      // Step A: Stage 2 - Reading priority files
      if (_isCancelled) return;
      _state = _state.copyWith(
        stage: ScanStage.readingFiles,
        stageMessage: 'Stage 2/4: Reading priority files and commits...',
      );
      _safeNotifyListeners();

      final scanResult = await _scanner.scanRepository(root);
      if (_isCancelled) return;

      // Step B: Stage 3 - Constructing immutable snapshot
      _state = _state.copyWith(
        scanResult: scanResult,
        stage: ScanStage.constructingSnapshot,
        stageMessage: 'Stage 3/4: Constructing immutable evidence snapshot...',
      );
      _safeNotifyListeners();

      final snapshot = EvidenceSnapshot.fromScanResult(scanResult);
      if (_isCancelled) return;

      // Step C: Stage 4 - Local Gemma autopsy via loopback Ollama
      _state = _state.copyWith(
        evidenceSnapshot: snapshot,
        status: InvestigationStatus.generating,
        stage: ScanStage.runningInference,
        stageMessage:
            'Stage 4/4: Generating grounded autopsy with local Gemma CPU...',
      );
      _safeNotifyListeners();

      final autopsyReport = await _autopsyService.generateAutopsy(
        snapshot: snapshot,
      );
      if (_isCancelled) return;

      _elapsedTimer?.cancel();
      _state = _state.copyWith(
        autopsyReport: autopsyReport,
        status: InvestigationStatus.completed,
        stage: ScanStage.idle,
        stageMessage: 'Investigation completed successfully.',
      );
      _safeNotifyListeners();
    } catch (e) {
      _elapsedTimer?.cancel();
      if (_isCancelled) return;

      // Preserve previous valid report if present
      final fallbackReport =
          _state.autopsyReport ?? _autopsyService.lastValidReport;
      _state = _state.copyWith(
        status: InvestigationStatus.failed,
        stage: ScanStage.idle,
        errorMessage: 'Investigation failed: $e',
        autopsyReport: fallbackReport,
      );
      _safeNotifyListeners();
    }
  }

  /// Cancels any active scan or inference request.
  void cancelInvestigation() {
    _isCancelled = true;
    _elapsedTimer?.cancel();
    _autopsyService.cancelCurrentRequest();

    final preservedReport =
        _state.autopsyReport ?? _autopsyService.lastValidReport;
    _state = _state.copyWith(
      status: InvestigationStatus.cancelled,
      stage: ScanStage.idle,
      stageMessage: 'Investigation cancelled by user.',
      autopsyReport: preservedReport,
    );
    _safeNotifyListeners();
  }

  // --- Ask the Ghost Q&A Operations (M6) ---

  /// Asks a question to the Ghost Q&A assistant against the active snapshot.
  Future<void> askGhost(String questionText) async {
    final trimmed = questionText.trim();
    if (trimmed.isEmpty) return;

    final snapshot = _state.evidenceSnapshot;
    if (snapshot == null) {
      _state = _state.copyWith(
        ghostQaStatus: GhostQaStatus.failed,
        ghostQaErrorMessage: 'Investigate a repository first to summon evidence before asking questions.',
      );
      _safeNotifyListeners();
      return;
    }

    _ghostQaElapsedTimer?.cancel();

    _state = _state.copyWith(
      ghostQuestion: GhostQuestion(text: trimmed),
      ghostQaStatus: GhostQaStatus.searching,
      ghostQaStageText: 'Searching snapshot & consulting local Gemma (CPU)...',
      ghostQaElapsedDuration: Duration.zero,
      clearGhostQaErrorMessage: true,
    );
    _safeNotifyListeners();

    // Start live elapsed timer for Q&A
    _ghostQaElapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isDisposed && _state.isGhostQaLoading) {
        _state = _state.copyWith(
          ghostQaElapsedDuration:
              _state.ghostQaElapsedDuration + const Duration(seconds: 1),
        );
        _safeNotifyListeners();
      }
    });

    try {
      final answer = await _ghostQaService.askQuestion(
        snapshot: snapshot,
        question: trimmed,
      );

      _ghostQaElapsedTimer?.cancel();
      _state = _state.copyWith(
        ghostAnswer: answer,
        ghostQaStatus: GhostQaStatus.completed,
        ghostQaStageText: answer.notFound
            ? 'Answer complete (insufficient evidence).'
            : 'Answer grounded and verified.',
      );
      _safeNotifyListeners();
    } catch (e) {
      _ghostQaElapsedTimer?.cancel();

      // Preserve previous valid answer if one existed
      final fallbackAnswer =
          _state.ghostAnswer ?? _ghostQaService.lastValidAnswer;

      _state = _state.copyWith(
        ghostQaStatus: GhostQaStatus.failed,
        ghostQaErrorMessage: 'Q&A inquiry failed: $e',
        ghostAnswer: fallbackAnswer,
      );
      _safeNotifyListeners();
    }
  }

  /// Cancels in-flight Ghost Q&A request and restores previous state.
  void cancelGhostQuestion() {
    _ghostQaElapsedTimer?.cancel();
    _ghostQaService.cancelCurrentRequest();

    final preservedAnswer =
        _state.ghostAnswer ?? _ghostQaService.lastValidAnswer;

    _state = _state.copyWith(
      ghostQaStatus: GhostQaStatus.cancelled,
      ghostQaStageText: 'Inquiry cancelled by user.',
      ghostAnswer: preservedAnswer,
    );
    _safeNotifyListeners();
  }

  /// Clears the active Ghost Q&A question and answer.
  void clearGhostAnswer() {
    _ghostQaElapsedTimer?.cancel();
    _ghostQaService.cancelCurrentRequest();
    _state = _state.copyWith(
      clearGhostQuestion: true,
      clearGhostAnswer: true,
      ghostQaStatus: GhostQaStatus.idle,
      ghostQaStageText: '',
      ghostQaElapsedDuration: Duration.zero,
      clearGhostQaErrorMessage: true,
    );
    _safeNotifyListeners();
  }

  // --- Lateral Evidence Drawer Operations ---

  /// Opens the lateral evidence drawer with the referenced evidence item.
  void openEvidence(String evidenceId) {
    final item = _state.evidenceSnapshot?.evidenceMap[evidenceId];
    if (item != null) {
      _state = _state.copyWith(activeEvidenceItem: item);
      _safeNotifyListeners();
    }
  }

  /// Closes the lateral evidence drawer.
  void closeEvidence() {
    if (_state.activeEvidenceItem != null) {
      _state = _state.copyWith(clearActiveEvidence: true);
      _safeNotifyListeners();
    }
  }

  /// Clears current investigation and returns to initial state.
  void clearInvestigation() {
    _elapsedTimer?.cancel();
    _ghostQaElapsedTimer?.cancel();
    _autopsyService.cancelCurrentRequest();
    _ghostQaService.cancelCurrentRequest();
    _state = WorkbenchState(readinessState: _state.readinessState);
    _safeNotifyListeners();
  }
}
