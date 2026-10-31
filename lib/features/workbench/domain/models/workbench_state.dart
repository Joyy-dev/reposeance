import 'package:flutter/foundation.dart';
import 'package:reposeance/features/autopsy/domain/models/autopsy_report.dart';
import 'package:reposeance/features/autopsy/domain/models/evidence_item.dart';
import 'package:reposeance/features/autopsy/domain/models/evidence_snapshot.dart';
import 'package:reposeance/features/ghost_qa/domain/models/ghost_answer.dart';
import 'package:reposeance/features/ghost_qa/domain/models/ghost_question.dart';
import 'package:reposeance/features/readiness/models/readiness_state.dart';
import 'package:reposeance/features/repository/domain/models/repository_info.dart';
import 'package:reposeance/features/repository/domain/models/scan_result.dart';

/// Overall investigation workflow status.
enum InvestigationStatus {
  idle,
  scanning,
  generating,
  completed,
  failed,
  cancelled,
}

/// Truthful granular scan and inference stages (no fake percentages).
enum ScanStage {
  idle,
  enumerating,
  readingFiles,
  constructingSnapshot,
  runningInference,
}

/// Status for interactive Ask the Ghost Q&A operations.
enum GhostQaStatus { idle, searching, generating, completed, failed, cancelled }

/// Immutable state representation for the RepoSéance single-workspace workbench.
@immutable
class WorkbenchState {
  final String? selectedDirectory;
  final RepositoryInfo? repositoryInfo;
  final ScanResult? scanResult;
  final EvidenceSnapshot? evidenceSnapshot;
  final AutopsyReport? autopsyReport;
  final InvestigationStatus status;
  final ScanStage stage;
  final String stageMessage;
  final Duration elapsedDuration;
  final String? errorMessage;
  final EvidenceItem? activeEvidenceItem;
  final SystemReadinessState readinessState;

  // Ask the Ghost Q&A state (M6)
  final GhostQuestion? ghostQuestion;
  final GhostAnswer? ghostAnswer;
  final GhostQaStatus ghostQaStatus;
  final String ghostQaStageText;
  final Duration ghostQaElapsedDuration;
  final String? ghostQaErrorMessage;

  const WorkbenchState({
    this.selectedDirectory,
    this.repositoryInfo,
    this.scanResult,
    this.evidenceSnapshot,
    this.autopsyReport,
    this.status = InvestigationStatus.idle,
    this.stage = ScanStage.idle,
    this.stageMessage = '',
    this.elapsedDuration = Duration.zero,
    this.errorMessage,
    this.activeEvidenceItem,
    required this.readinessState,
    this.ghostQuestion,
    this.ghostAnswer,
    this.ghostQaStatus = GhostQaStatus.idle,
    this.ghostQaStageText = '',
    this.ghostQaElapsedDuration = Duration.zero,
    this.ghostQaErrorMessage,
  });

  factory WorkbenchState.initial() =>
      WorkbenchState(readinessState: SystemReadinessState.initial());

  bool get isLoading =>
      status == InvestigationStatus.scanning ||
      status == InvestigationStatus.generating;

  bool get isPartialScan => scanResult?.isPartial ?? false;

  bool get isModelUnavailable => !readinessState.isOllamaReady;

  bool get isGhostQaLoading =>
      ghostQaStatus == GhostQaStatus.searching ||
      ghostQaStatus == GhostQaStatus.generating;

  WorkbenchState copyWith({
    String? selectedDirectory,
    bool clearDirectory = false,
    RepositoryInfo? repositoryInfo,
    bool clearRepositoryInfo = false,
    ScanResult? scanResult,
    bool clearScanResult = false,
    EvidenceSnapshot? evidenceSnapshot,
    bool clearEvidenceSnapshot = false,
    AutopsyReport? autopsyReport,
    bool clearAutopsyReport = false,
    InvestigationStatus? status,
    ScanStage? stage,
    String? stageMessage,
    Duration? elapsedDuration,
    String? errorMessage,
    bool clearErrorMessage = false,
    EvidenceItem? activeEvidenceItem,
    bool clearActiveEvidence = false,
    SystemReadinessState? readinessState,
    GhostQuestion? ghostQuestion,
    bool clearGhostQuestion = false,
    GhostAnswer? ghostAnswer,
    bool clearGhostAnswer = false,
    GhostQaStatus? ghostQaStatus,
    String? ghostQaStageText,
    Duration? ghostQaElapsedDuration,
    String? ghostQaErrorMessage,
    bool clearGhostQaErrorMessage = false,
  }) {
    return WorkbenchState(
      selectedDirectory: clearDirectory
          ? null
          : (selectedDirectory ?? this.selectedDirectory),
      repositoryInfo: clearRepositoryInfo
          ? null
          : (repositoryInfo ?? this.repositoryInfo),
      scanResult: clearScanResult ? null : (scanResult ?? this.scanResult),
      evidenceSnapshot: clearEvidenceSnapshot
          ? null
          : (evidenceSnapshot ?? this.evidenceSnapshot),
      autopsyReport: clearAutopsyReport
          ? null
          : (autopsyReport ?? this.autopsyReport),
      status: status ?? this.status,
      stage: stage ?? this.stage,
      stageMessage: stageMessage ?? this.stageMessage,
      elapsedDuration: elapsedDuration ?? this.elapsedDuration,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      activeEvidenceItem: clearActiveEvidence
          ? null
          : (activeEvidenceItem ?? this.activeEvidenceItem),
      readinessState: readinessState ?? this.readinessState,
      ghostQuestion: clearGhostQuestion
          ? null
          : (ghostQuestion ?? this.ghostQuestion),
      ghostAnswer: clearGhostAnswer ? null : (ghostAnswer ?? this.ghostAnswer),
      ghostQaStatus: ghostQaStatus ?? this.ghostQaStatus,
      ghostQaStageText: ghostQaStageText ?? this.ghostQaStageText,
      ghostQaElapsedDuration:
          ghostQaElapsedDuration ?? this.ghostQaElapsedDuration,
      ghostQaErrorMessage: clearGhostQaErrorMessage
          ? null
          : (ghostQaErrorMessage ?? this.ghostQaErrorMessage),
    );
  }
}
