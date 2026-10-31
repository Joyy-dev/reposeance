import 'package:flutter/material.dart';
import 'package:reposeance/core/theme/app_colors.dart';
import 'package:reposeance/features/workbench/controllers/workbench_controller.dart';
import 'package:reposeance/features/workbench/domain/models/workbench_state.dart';

/// State view rendered when local Ollama loopback is unreachable or gemma4:e2b is absent.
/// Enforces the invariant: Never silently fall back to cloud AI.
class ModelUnavailableView extends StatelessWidget {
  final WorkbenchState state;
  final WorkbenchController controller;

  const ModelUnavailableView({
    super.key,
    required this.state,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 36,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Eyebrow
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: AppColors.warning.withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: const Text(
                            'LOCAL MODEL UNAVAILABLE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Title
                        const Text(
                          'Keep the scan. Restore the connection.',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Description
                        const Text(
                          'Local Ollama daemon is unreachable at 127.0.0.1:11434, or the pinned '
                          'open-weight model gemma4:e2b is not installed.',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Terminal command hints
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.border,
                              width: 1,
                            ),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '# 1. Start native Ollama daemon:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Consolas',
                                  color: AppColors.textMuted,
                                ),
                              ),
                              SizedBox(height: 2),
                              SelectableText(
                                'ollama serve',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontFamily: 'Consolas',
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.accentCyan,
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                '# 2. Pull the pinned Gemma model:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Consolas',
                                  color: AppColors.textMuted,
                                ),
                              ),
                              SizedBox(height: 2),
                              SelectableText(
                                'ollama pull gemma4:e2b',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontFamily: 'Consolas',
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.accentCyan,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Action buttons
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: controller.checkSystemReadiness,
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Recheck Connection'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.accentAmber,
                                foregroundColor: const Color(0xFF151B27),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                              ),
                            ),
                            if (state.autopsyReport != null)
                              OutlinedButton(
                                onPressed: () {},
                                child: const Text('View Last Valid Report'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Privacy Invariant Note
                        const Text(
                          'Privacy Invariant: RepoSéance is architected strictly for local privacy. '
                          'Source excerpts are never transmitted to cloud AI APIs.',
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
