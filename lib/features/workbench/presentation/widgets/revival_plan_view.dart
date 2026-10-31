import 'package:flutter/material.dart';
import 'package:reposeance/core/theme/app_colors.dart';
import 'package:reposeance/features/autopsy/domain/models/evidence_snapshot.dart';
import 'package:reposeance/features/autopsy/domain/models/revival_step.dart';

/// Renders the 3 starting points / revival plan steps.
/// Enforces the invariant: Next steps are suggested for the human maintainer;
/// the application never executes them automatically.
class RevivalPlanView extends StatelessWidget {
  final List<RevivalStep> revivalPlan;
  final EvidenceSnapshot? snapshot;
  final void Function(String evidenceId) onCitationClicked;

  const RevivalPlanView({
    super.key,
    required this.revivalPlan,
    required this.snapshot,
    required this.onCitationClicked,
  });

  @override
  Widget build(BuildContext context) {
    if (revivalPlan.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 20, bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Eyebrow
          const Text(
            'REVIVAL PLAN',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.accentAmber,
            ),
          ),
          const SizedBox(height: 6),

          // Heading
          const Text(
            'Three Starting Points',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),

          // Subtitle
          const Text(
            'Evidence-grounded initial steps for a developer resuming this project.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),

          // Numbered Steps
          ...revivalPlan.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final item = entry.value;
            return _buildStepItem(index, item);
          }),

          const SizedBox(height: 10),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 10),

          // App Execution Safety Caveat
          const Text(
            'Advisory only: These steps are proposed for the maintainer. RepoSéance never executes '
            'scripts, builds, or dependencies automatically.',
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(int number, RevivalStep item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Number badge
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accentAmber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: AppColors.accentAmber.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'Consolas',
                fontWeight: FontWeight.w700,
                color: AppColors.accentAmber,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Step details and reason
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.step,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.reason.text,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (item.reason.evidenceIds.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: item.reason.evidenceIds.map((id) {
                      return InkWell(
                        onTap: () => onCitationClicked(id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accentCyan.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: AppColors.accentCyan.withValues(
                                alpha: 0.3,
                              ),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '$id ↗',
                            style: const TextStyle(
                              fontSize: 10,
                              fontFamily: 'Consolas',
                              fontWeight: FontWeight.w600,
                              color: AppColors.accentCyan,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
