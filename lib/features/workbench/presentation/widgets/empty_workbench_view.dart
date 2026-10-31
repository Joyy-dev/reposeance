import 'package:flutter/material.dart';
import 'package:reposeance/core/theme/app_colors.dart';
import 'package:reposeance/features/workbench/controllers/workbench_controller.dart';
import 'package:reposeance/features/workbench/domain/models/workbench_state.dart';

/// Landing screen displayed when no investigation is active.
/// Truthful local-first explanation without synthetic mock data.
class EmptyWorkbenchView extends StatelessWidget {
  final WorkbenchState state;
  final WorkbenchController controller;

  const EmptyWorkbenchView({
    super.key,
    required this.state,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final hasRepo = state.selectedDirectory != null;
    final repoName = state.repositoryInfo?.name ?? 'Selected Repository';
    final branchName = state.repositoryInfo?.currentBranch ?? 'HEAD';

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 40,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Eyebrow Tag
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
                        child: const Text(
                          'LOCAL-FIRST SOFTWARE FORENSICS WORKBENCH',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AppColors.accentCyan,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Headline
                      const Text(
                        'The code survived.\nRecover the context.',
                        style: TextStyle(
                          fontSize: 38,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.8,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Subtitle
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 780),
                        child: const Text(
                          'Inspect an unfamiliar or abandoned local Git repository. RepoSéance safely extracts '
                          'structural evidence and invokes local Gemma to separate what the code proves from what remains unsaid.',
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.55,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Repository Target Card or Primary Action Buttons
                      if (hasRepo) ...[
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.accentCyan.withValues(
                                alpha: 0.35,
                              ),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.accentCyan.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.folder_outlined,
                                  color: AppColors.accentCyan,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          repoName,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceElevated,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            border: Border.all(
                                              color: AppColors.border,
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            branchName,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontFamily: 'Consolas',
                                              color: AppColors.accentAmber,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      state.selectedDirectory!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontFamily: 'Consolas',
                                        color: AppColors.textSecondary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              FilledButton.icon(
                                onPressed: controller.startInvestigation,
                                icon: const Icon(
                                  Icons.psychology_outlined,
                                  size: 18,
                                ),
                                label: const Text('Start Investigation'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.accentAmber,
                                  foregroundColor: const Color(0xFF151B27),
                                  textStyle: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 22,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton.icon(
                                onPressed: controller.pickDirectory,
                                icon: const Icon(Icons.folder_open, size: 16),
                                label: const Text('Change'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.textPrimary,
                                  side: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Wrap(
                          spacing: 14,
                          runSpacing: 10,
                          children: [
                            FilledButton.icon(
                              onPressed: controller.pickDirectory,
                              icon: const Icon(Icons.folder_open, size: 18),
                              label: const Text('Select Git Repository'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.accentAmber,
                                foregroundColor: const Color(0xFF151B27),
                                textStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: controller.checkSystemReadiness,
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Recheck Toolchain'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                                side: const BorderSide(color: AppColors.border),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 36),

                      // 3-Step Explanatory Pillars
                      LayoutBuilder(
                        builder: (context, pillarConstraints) {
                          final isWide = pillarConstraints.maxWidth >= 680;

                          if (isWide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildPillarCard(
                                    number: '01',
                                    title: 'Bounded Scan',
                                    description: 'Tracked files only, safe non-shell Git invocation, depth limit, null-delimited paths, and secret exclusion.',
                                    icon: Icons.shield_outlined,
                                  ),
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  child: _buildPillarCard(
                                    number: '02',
                                    title: 'Local Inference',
                                    description: 'Direct loopback HTTP to native Ollama (gemma4:e2b) on CPU. Zero cloud fallback and zero telemetry.',
                                    icon: Icons.terminal_outlined,
                                  ),
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  child: _buildPillarCard(
                                    number: '03',
                                    title: 'Evidence-Grounded',
                                    description: 'All claims carry verified citations (E001..E065) from an immutable snapshot with honest unknowns.',
                                    icon: Icons.verified_outlined,
                                  ),
                                ),
                              ],
                            );
                          } else {
                            return Column(
                              children: [
                                _buildPillarCard(
                                  number: '01',
                                  title: 'Bounded Scan',
                                  description: 'Tracked files only, safe non-shell Git invocation, depth limit, null-delimited paths, and secret exclusion.',
                                  icon: Icons.shield_outlined,
                                ),
                                const SizedBox(height: 12),
                                _buildPillarCard(
                                  number: '02',
                                  title: 'Local Inference',
                                  description: 'Direct loopback HTTP to native Ollama (gemma4:e2b) on CPU. Zero cloud fallback and zero telemetry.',
                                  icon: Icons.terminal_outlined,
                                ),
                                const SizedBox(height: 12),
                                _buildPillarCard(
                                  number: '03',
                                  title: 'Evidence-Grounded',
                                  description: 'All claims carry verified citations (E001..E065) from an immutable snapshot with honest unknowns.',
                                  icon: Icons.verified_outlined,
                                ),
                              ],
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 28),

                      // Safe Forensics Assurance Footer
                      Row(
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 14,
                            color: AppColors.accentCyan.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Strict local-only forensics: Non-shell Git enumeration • Loopback HTTP (127.0.0.1) • Zero cloud egress',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                letterSpacing: 0.2,
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
      },
    );
  }

  Widget _buildPillarCard({
    required String number,
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                number,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'Consolas',
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentAmber,
                ),
              ),
              Icon(
                icon,
                size: 16,
                color: AppColors.accentCyan.withValues(alpha: 0.6),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
