import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/readiness_state.dart';

/// Target repository selector widget with native directory picker and path display.
class DirectorySelector extends StatelessWidget {
  final SystemReadinessState state;
  final VoidCallback onPickDirectory;
  final VoidCallback onClearDirectory;

  const DirectorySelector({
    super.key,
    required this.state,
    required this.onPickDirectory,
    required this.onClearDirectory,
  });

  @override
  Widget build(BuildContext context) {
    final hasDir = state.hasDirectorySelected;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.folder_open_outlined,
                size: 22,
                color: AppColors.accentAmber,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Target Repository for Autopsy',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasDir ? 'Selected local repository working tree' : 'Choose an unfamiliar or abandoned local Git repository to examine',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Path Display Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: hasDir
                    ? AppColors.accentAmber.withValues(alpha: 0.4)
                    : AppColors.border,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  hasDir ? Icons.check_circle_outline : Icons.help_outline,
                  size: 18,
                  color: hasDir ? AppColors.success : AppColors.textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasDir
                        ? state.selectedDirectory!
                        : 'No repository folder selected yet',
                    style: AppTheme.monoStyle.copyWith(
                      fontSize: 13,
                      color: hasDir
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                      fontWeight: hasDir ? FontWeight.w500 : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasDir) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onClearDirectory,
                    icon: const Icon(
                      Icons.close,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    tooltip: 'Deselect repository',
                    splashRadius: 18,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Action Buttons
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: onPickDirectory,
                icon: const Icon(Icons.folder_open, size: 18),
                label: Text(
                  hasDir
                      ? 'Change Repository Folder'
                      : 'Select Repository Folder',
                ),
              ),
              const SizedBox(width: 14),

              // Placeholder for Autopsy trigger (coming in M3/M4/M5)
              OutlinedButton.icon(
                onPressed: state.canProceedToScan
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: AppColors.surfaceElevated,
                            content: Text(
                              'M2 Scaffold Verified: Bounded scanner will be connected in Milestone 3.',
                              style: TextStyle(color: AppColors.textPrimary),
                            ),
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                    : null,
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('Summon Autopsy (M3 Engine)'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Privacy & Safety Disclosure
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.security,
                  size: 16,
                  color: AppColors.accentCyan,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Privacy Guarantee: RepoSéance executes zero code inside the target repository. '
                    'All evidence extraction is strictly read-only and bounded, and all inference runs locally on CPU via Ollama.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
