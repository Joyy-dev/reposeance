import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../repository/data/repository_scanner.dart';
import '../../models/readiness_state.dart';

/// Target repository selector widget with native directory picker, Git validation, and path display.
class DirectorySelector extends StatefulWidget {
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
  State<DirectorySelector> createState() => _DirectorySelectorState();
}

class _DirectorySelectorState extends State<DirectorySelector> {
  bool _isScanning = false;

  Future<void> _runBoundedScan(BuildContext context, String repoPath) async {
    setState(() => _isScanning = true);
    try {
      final scanner = RepositoryScanner();
      final result = await scanner.scanRepository(repoPath);

      if (!context.mounted) return;

      final summary =
          'M3 Bounded Scan Complete: ${result.files.length} file(s) selected, '
          '${result.commits.length} commit(s), ${result.totalBytesRead} bytes read in ${result.scanDurationMs}ms.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceElevated,
          content: Text(
            summary,
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceElevated,
          content: Text(
            'Scan error: $e',
            style: const TextStyle(color: AppColors.error),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final hasDir = state.hasDirectorySelected;
    final isValidGit = state.isTargetGitRepo == true;

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
                    ? (isValidGit
                          ? AppColors.success.withValues(alpha: 0.4)
                          : AppColors.error.withValues(alpha: 0.4))
                    : AppColors.border,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  hasDir
                      ? (isValidGit
                            ? Icons.check_circle_outline
                            : Icons.error_outline)
                      : Icons.help_outline,
                  size: 18,
                  color: hasDir
                      ? (isValidGit ? AppColors.success : AppColors.error)
                      : AppColors.textMuted,
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
                    onPressed: widget.onClearDirectory,
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
          if (hasDir && !isValidGit) ...[
            const SizedBox(height: 8),
            Text(
              state.targetRepoError ??
                  'The selected folder is not a valid Git working tree.',
              style: const TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ],
          const SizedBox(height: 18),

          // Action Buttons
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: widget.onPickDirectory,
                icon: const Icon(Icons.folder_open, size: 18),
                label: Text(
                  hasDir
                      ? 'Change Repository Folder'
                      : 'Select Repository Folder',
                ),
              ),
              const SizedBox(width: 14),

              // Bounded Scanner trigger (connected in M3)
              OutlinedButton.icon(
                onPressed: (state.canProceedToScan && !_isScanning)
                    ? () => _runBoundedScan(context, state.selectedDirectory!)
                    : null,
                icon: _isScanning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.accentCyan,
                          ),
                        ),
                      )
                    : const Icon(Icons.auto_awesome, size: 16),
                label: Text(
                  _isScanning
                      ? 'Scanning Tracked Files...'
                      : 'Run Bounded Scan (M3)',
                ),
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
            child: const Row(
              children: [
                Icon(Icons.security, size: 16, color: AppColors.accentCyan),
                SizedBox(width: 10),
                Expanded(
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
