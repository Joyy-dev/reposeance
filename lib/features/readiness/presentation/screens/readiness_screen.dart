import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../controllers/readiness_controller.dart';
import '../widgets/directory_selector.dart';
import '../widgets/readiness_card.dart';
import '../widgets/status_header.dart';

/// Primary shell screen for RepoSéance single-workspace forensics workbench.
class ReadinessScreen extends StatelessWidget {
  const ReadinessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReadinessController>(
      builder: (context, controller, child) {
        final state = controller.state;

        return Scaffold(
          body: Column(
            children: [
              // 1. Top Compact Status Header
              StatusHeader(
                state: state,
                onRefresh: controller.checkSystemReadiness,
              ),

              // 2. Main Investigation Workspace Canvas
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 28,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Workspace Hero / Intro
                          _buildWorkbenchHero(),
                          const SizedBox(height: 28),

                          // Target Repository Selector Card
                          DirectorySelector(
                            state: state,
                            onPickDirectory: controller.pickDirectory,
                            onClearDirectory: controller.clearDirectory,
                          ),
                          const SizedBox(height: 24),

                          // Host Environment Diagnostics Card
                          ReadinessCard(state: state),
                          const SizedBox(height: 24),

                          // Milestone Roadmap Notice
                          _buildMilestoneFooter(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWorkbenchHero() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accentAmber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AppColors.accentAmber.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 14,
                    color: AppColors.accentAmber,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'LOCAL-ONLY PRIVACY ARCHITECTURE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.accentAmber,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accentCyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AppColors.accentCyan.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bolt_outlined,
                    size: 14,
                    color: AppColors.accentCyan,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'DIRECT DART-TO-OLLAMA (NO INTERMEDIATE BACKEND)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.accentCyan,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          'Automated Local Repository Autopsy Workbench',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Select an unfamiliar, legacy, or abandoned Git repository to perform a bounded forensic autopsy. '
          'RepoSéance extracts structural evidence and uses local Gemma to produce an evidence-grounded report with zero telemetry.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _buildMilestoneFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: AppColors.textMuted),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Active Milestone: M2 (Flutter Windows scaffold & readiness shell verified). '
              'Next: M3 Safe Git Service & Bounded Scanner candidate enumeration.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
