import 'package:flutter/material.dart';
import 'package:reposeance/core/theme/app_colors.dart';
import 'package:reposeance/features/workbench/controllers/workbench_controller.dart';
import 'package:reposeance/features/workbench/domain/models/workbench_state.dart';

/// Loading view displaying truthful stage progression and live elapsed counter.
/// Zero fake percentage progress bars.
class WorkbenchLoadingView extends StatelessWidget {
  final WorkbenchState state;
  final WorkbenchController controller;

  const WorkbenchLoadingView({
    super.key,
    required this.state,
    required this.controller,
  });

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isGenerating = state.status == InvestigationStatus.generating;

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Stage & Live Timer
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentCyan.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: AppColors.accentCyan.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          isGenerating
                              ? 'STAGE 4/4 · LOCAL GEMMA INFERENCE'
                              : 'BOUNDED REPOSITORY INSPECTION',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AppColors.accentCyan,
                          ),
                        ),
                      ),
                      // Truthful Live Elapsed Counter
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            size: 14,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_formatDuration(state.elapsedDuration)} elapsed',
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'Consolas',
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Current Stage Message (Truthful Stage Description)
                  Text(
                    state.stageMessage.isEmpty
                        ? 'Processing repository investigation...'
                        : state.stageMessage,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Indeterminate Activity Line (Restrained, No Fake 0-100% Percentages)
                  const LinearProgressIndicator(
                    backgroundColor: AppColors.surfaceElevated,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.accentAmber,
                    ),
                    minHeight: 3,
                  ),
                  const SizedBox(height: 24),

                  // 4-Stage Truthful Progress Checklist
                  _buildStageRow(
                    stageNumber: 1,
                    title: 'Enumerating tracked Git files (null-delimited)',
                    isCurrent: state.stage == ScanStage.enumerating,
                    isDone: state.stage.index > ScanStage.enumerating.index,
                  ),
                  const SizedBox(height: 10),
                  _buildStageRow(
                    stageNumber: 2,
                    title: 'Reading prioritized candidates and recent commits',
                    isCurrent: state.stage == ScanStage.readingFiles,
                    isDone: state.stage.index > ScanStage.readingFiles.index,
                  ),
                  const SizedBox(height: 10),
                  _buildStageRow(
                    stageNumber: 3,
                    title: 'Constructing immutable evidence snapshot & hashes',
                    isCurrent: state.stage == ScanStage.constructingSnapshot,
                    isDone:
                        state.stage.index >
                        ScanStage.constructingSnapshot.index,
                  ),
                  const SizedBox(height: 10),
                  _buildStageRow(
                    stageNumber: 4,
                    title: 'Generating grounded autopsy with local Gemma CPU',
                    isCurrent: state.stage == ScanStage.runningInference,
                    isDone: state.status == InvestigationStatus.completed,
                  ),
                  const SizedBox(height: 28),

                  // Latency Disclosure Notice
                  if (isGenerating)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border, width: 1),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: AppColors.accentCyan,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Local Gemma inference via Ollama runs on host CPU with strict temperature 0.1. '
                              'This typically requires 60–120 seconds. Citations and JSON schema constraints are enforced in native Dart.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Cancellation Action
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: controller.cancelInvestigation,
                        icon: const Icon(Icons.cancel_outlined, size: 16),
                        label: const Text('Cancel Investigation'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: BorderSide(
                            color: AppColors.error.withValues(alpha: 0.5),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStageRow({
    required int stageNumber,
    required String title,
    required bool isCurrent,
    required bool isDone,
  }) {
    final Color iconColor;
    final IconData icon;

    if (isDone) {
      icon = Icons.check_circle;
      iconColor = AppColors.success;
    } else if (isCurrent) {
      icon = Icons.radio_button_checked;
      iconColor = AppColors.accentAmber;
    } else {
      icon = Icons.radio_button_unchecked;
      iconColor = AppColors.textMuted;
    }

    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Stage $stageNumber: $title',
            style: TextStyle(
              fontSize: 13,
              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
              color: isCurrent
                  ? AppColors.textPrimary
                  : (isDone ? AppColors.textSecondary : AppColors.textMuted),
            ),
          ),
        ),
      ],
    );
  }
}
