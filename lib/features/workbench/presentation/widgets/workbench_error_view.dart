import 'package:flutter/material.dart';
import 'package:reposeance/core/theme/app_colors.dart';
import 'package:reposeance/features/workbench/controllers/workbench_controller.dart';
import 'package:reposeance/features/workbench/domain/models/workbench_state.dart';

/// Error state card rendering actionable error details with retry support.
class WorkbenchErrorView extends StatelessWidget {
  final WorkbenchState state;
  final WorkbenchController controller;

  const WorkbenchErrorView({
    super.key,
    required this.state,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final error = state.errorMessage ?? 'An unexpected error occurred.';

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
                        color: AppColors.error.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 22,
                              color: AppColors.error,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Investigation Encountered an Error',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.border,
                              width: 1,
                            ),
                          ),
                          child: SelectableText(
                            error,
                            style: const TextStyle(
                              fontSize: 13,
                              fontFamily: 'Consolas',
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: controller.startInvestigation,
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Retry Investigation'),
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
                            OutlinedButton(
                              onPressed: controller.clearInvestigation,
                              child: const Text('Back to Home'),
                            ),
                          ],
                        ),

                        if (state.autopsyReport != null) ...[
                          const SizedBox(height: 16),
                          const Divider(color: AppColors.border, height: 1),
                          const SizedBox(height: 12),
                          const Text(
                            'Notice: The previous valid autopsy report has been preserved in memory.',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
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
