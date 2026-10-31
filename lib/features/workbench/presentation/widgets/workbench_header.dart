import 'package:flutter/material.dart';
import 'package:reposeance/core/theme/app_colors.dart';
import 'package:reposeance/features/workbench/controllers/workbench_controller.dart';
import 'package:reposeance/features/workbench/domain/models/workbench_state.dart';

/// Top header bar for RepoSéance workbench with real-time toolchain indicators
/// and target repository action bar. Resilient to high DPI and text scaling.
class WorkbenchHeader extends StatelessWidget {
  final WorkbenchState state;
  final WorkbenchController controller;

  const WorkbenchHeader({
    super.key,
    required this.state,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 1120;

        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(
              bottom: BorderSide(color: AppColors.border, width: 1),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Brand & Diagnostic Health Pills
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RichText(
                              text: const TextSpan(
                                text: 'Repo',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                  color: AppColors.textPrimary,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Séance',
                                    style: TextStyle(
                                      color: AppColors.accentAmber,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isCompact) ...[
                              const SizedBox(height: 2),
                              const Text(
                                'Summon the story behind forgotten code.',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(width: 14),
                        _buildToolchainStatus(isCompact: isCompact),
                      ],
                    ),

                    const SizedBox(width: 16),

                    // Repository Action Bar
                    _buildRepositoryBar(context, isCompact: isCompact),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildToolchainStatus({required bool isCompact}) {
    final gitReady = state.readinessState.isGitReady;
    final ollamaReady = state.readinessState.isOllamaReady;
    final isChecking = state.readinessState.isChecking;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatusDot(
            label: 'Git',
            isReady: gitReady,
            isChecking: isChecking,
          ),
          const SizedBox(width: 8),
          _buildStatusDot(
            label: isCompact ? 'Ollama' : '127.0.0.1',
            isReady: ollamaReady,
            isChecking: isChecking,
          ),
          const SizedBox(width: 8),
          _buildStatusDot(
            label: isCompact ? 'Gemma' : 'Gemma 4:e2b',
            isReady: ollamaReady,
            isChecking: isChecking,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDot({
    required String label,
    required bool isReady,
    required bool isChecking,
  }) {
    final Color color;
    if (isChecking) {
      color = AppColors.checking;
    } else if (isReady) {
      color = AppColors.success;
    } else {
      color = AppColors.error;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: isReady
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildRepositoryBar(BuildContext context, {required bool isCompact}) {
    final hasRepo = state.selectedDirectory != null;
    final repoName = state.repositoryInfo?.name ?? 'No repo selected';

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (hasRepo) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.folder_outlined,
                  size: 14,
                  color: AppColors.accentCyan,
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isCompact ? 120 : 200),
                  child: Text(
                    repoName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],

        // Select / Change Directory Button
        OutlinedButton.icon(
          onPressed: state.isLoading ? null : controller.pickDirectory,
          icon: const Icon(Icons.folder_open, size: 15),
          label: Text(hasRepo ? 'Change' : 'Select Repository'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStyle: const TextStyle(fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),

        // Primary "Investigate" / "Re-run" Action Button
        if (hasRepo)
          FilledButton.icon(
            onPressed: state.isLoading ? null : controller.startInvestigation,
            icon: const Icon(Icons.psychology_outlined, size: 15),
            label: Text(state.autopsyReport != null ? 'Re-run' : 'Investigate'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentAmber,
              foregroundColor: const Color(0xFF151B27),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
          ),
      ],
    );
  }
}
