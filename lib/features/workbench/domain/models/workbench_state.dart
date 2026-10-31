import 'package:flutter/foundation.dart';
import 'package:reposeance/features/autopsy/domain/models/autopsy_report.dart';
import 'package:reposeance/features/autopsy/domain/models/evidence_item.dart';
import 'package:reposeance/features/autopsy/domain/models/evidence_snapshot.dart';
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
  });

  factory WorkbenchState.initial() =>
      WorkbenchState(readinessState: SystemReadinessState.initial());

  bool get isLoading =>
      status == InvestigationStatus.scanning ||
      status == InvestigationStatus.generating;

  bool get isPartialScan => scanResult?.isPartial ?? false;

  bool get isModelUnavailable => !readinessState.isOllamaReady;

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
    );
  }
}
