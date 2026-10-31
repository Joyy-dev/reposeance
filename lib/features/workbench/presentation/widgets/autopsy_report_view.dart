import 'package:flutter/material.dart';
import 'package:reposeance/core/theme/app_colors.dart';
import 'package:reposeance/features/autopsy/domain/models/autopsy_report.dart';
import 'package:reposeance/features/export/presentation/widgets/export_report_dialog.dart';
import 'package:reposeance/features/ghost_qa/presentation/widgets/ghost_qa_view.dart';
import 'package:reposeance/features/workbench/controllers/workbench_controller.dart';
import 'package:reposeance/features/workbench/domain/models/workbench_state.dart';

import 'commit_timeline_view.dart';
import 'finding_card.dart';
import 'partial_scan_banner.dart';
import 'revival_plan_view.dart';
import 'unknowns_card.dart';

/// Full autopsy report presentation view rendering findings, commit timeline,
/// revival plan, unknowns, and M6 preview in a responsive multi-column layout.
class AutopsyReportView extends StatelessWidget {
  final WorkbenchState state;
  final WorkbenchController controller;

  const AutopsyReportView({
    super.key,
    required this.state,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final report = state.autopsyReport;
    if (report == null) {
      return const SizedBox.shrink();
    }

    final repoName = state.repositoryInfo?.name ?? 'Repository';
    final branchName = state.repositoryInfo?.currentBranch ?? 'HEAD';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1360),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Partial Scan Banner (if scan limits were reached)
              if (state.scanResult != null)
                PartialScanBanner(scanResult: state.scanResult!),

              // 2. Report Topline Header
              _buildReportHeader(context, repoName, branchName, report),
              const SizedBox(height: 24),

              // 3. Responsive 2-Column or Stacked Grid
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 1050;

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column (Findings & Revival Plan)
                        Expanded(flex: 3, child: _buildFindingsColumn(report)),
                        const SizedBox(width: 24),

                        // Right Column (Timeline, Unknowns & Discipline)
                        Expanded(flex: 2, child: _buildContextColumn(report)),
                      ],
                    );
                  } else {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFindingsColumn(report),
                        const SizedBox(height: 24),
                        _buildContextColumn(report),
                      ],
                    );
                  }
                },
              ),

              const SizedBox(height: 32),

              // 4. Ask the Ghost Interactive Q&A Assistant (M6)
              const GhostQaView(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportHeader(
    BuildContext context,
    String repoName,
    String branchName,
    AutopsyReport report,
  ) {
    final latencySec = (report.latency.inMilliseconds / 1000).toStringAsFixed(
      1,
    );

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
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
                        'SNAPSHOT ${report.snapshotId.length > 8 ? report.snapshotId.substring(0, 8) : report.snapshotId}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'Consolas',
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentCyan,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Branch: $branchName',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  repoName,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Local autopsy generated via gemma4:e2b in ${latencySec}s · Direct loopback 127.0.0.1:11434',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Export Report Button
          OutlinedButton.icon(
            key: const Key('export-report-button'),
            onPressed: () => _handleExport(context),
            icon: const Icon(Icons.file_download_outlined, size: 16),
            label: const Text('Export Report'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFindingsColumn(AutopsyReport report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Project Purpose (if identified)
        if (report.projectPurpose != null)
          FindingCard(
            heading: 'Project Purpose & Identity',
            finding: report.projectPurpose!,
            snapshot: state.evidenceSnapshot,
            onCitationClicked: controller.openEvidence,
          ),

        // 2. What the Evidence Says (Architecture & Findings)
        Container(
          margin: const EdgeInsets.only(top: 8, bottom: 12),
          child: const Text(
            'What the Evidence Says',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),

        ...report.architecture.map(
          (finding) => FindingCard(
            finding: finding,
            snapshot: state.evidenceSnapshot,
            onCitationClicked: controller.openEvidence,
          ),
        ),

        ...report.findings.map(
          (finding) => FindingCard(
            finding: finding,
            snapshot: state.evidenceSnapshot,
            onCitationClicked: controller.openEvidence,
          ),
        ),

        // 3. Three Starting Points (Revival Plan)
        RevivalPlanView(
          revivalPlan: report.revivalPlan,
          snapshot: state.evidenceSnapshot,
          onCitationClicked: controller.openEvidence,
        ),
      ],
    );
  }

  Widget _buildContextColumn(AutopsyReport report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Deterministic Commit Timeline
        CommitTimelineView(
          commits: state.scanResult?.commits ?? [],
          snapshot: state.evidenceSnapshot,
          onCitationClicked: controller.openEvidence,
        ),

        // 2. What Remains Unsaid (Unknowns)
        UnknownsCard(unknowns: report.unknowns),

        // 3. Evidence Discipline Footer
        Container(
          margin: const EdgeInsets.only(top: 20),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EVIDENCE, NOT MEMORY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.textMuted,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Citations open captured snapshot excerpts. Production references resolve strictly '
                'through the application-owned snapshot allowlist, not unverified model hallucinations.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleExport(BuildContext context) async {
    final options = await ExportReportDialog.show(
      context,
      workbenchState: state,
    );
    if (options == null || !context.mounted) {
      return;
    }

    final result = await controller.exportMarkdownReport(
      includeGhostQa: options.includeGhostQa,
    );

    if (!context.mounted) return;

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceElevated,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppColors.borderLight),
          ),
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: AppColors.success,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Report exported to ${result.filePath}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } else if (result.isFailed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceElevated,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppColors.error),
          ),
          content: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result.errorMessage ?? 'Export failed.',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}
