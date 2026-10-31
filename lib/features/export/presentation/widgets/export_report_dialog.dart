import 'package:flutter/material.dart';
import 'package:reposeance/core/theme/app_colors.dart';
import 'package:reposeance/features/export/domain/models/export_options.dart';
import 'package:reposeance/features/workbench/domain/models/workbench_state.dart';

/// Modal dialog allowing the user to configure and trigger a native Markdown report export.
class ExportReportDialog extends StatefulWidget {
  final WorkbenchState workbenchState;

  const ExportReportDialog({super.key, required this.workbenchState});

  /// Shows the dialog and returns the user-selected [ExportOptions], or `null` if cancelled.
  static Future<ExportOptions?> show(
    BuildContext context, {
    required WorkbenchState workbenchState,
  }) {
    return showDialog<ExportOptions>(
      context: context,
      barrierDismissible: true,
      builder: (context) => ExportReportDialog(workbenchState: workbenchState),
    );
  }

  @override
  State<ExportReportDialog> createState() => _ExportReportDialogState();
}

class _ExportReportDialogState extends State<ExportReportDialog> {
  late bool _includeGhostQa;

  @override
  void initState() {
    super.initState();
    _includeGhostQa = widget.workbenchState.ghostAnswer != null;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.workbenchState;
    final repoName = state.repositoryInfo?.name ?? 'Repository';
    final snapshotId = state.evidenceSnapshot?.snapshotId ?? 'snapshot';
    final shortSnapshot = snapshotId.length > 8
        ? snapshotId.substring(0, 8)
        : snapshotId;
    final fileCount =
        state.scanResult?.files.length ??
        state.evidenceSnapshot?.fileEvidence.length ??
        0;
    final commitCount =
        state.scanResult?.commits.length ??
        state.evidenceSnapshot?.commitEvidence.length ??
        0;
    final hasGhostQa = state.ghostAnswer != null;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accentCyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.accentCyan.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.file_download_outlined,
                      color: AppColors.accentCyan,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Export Autopsy Report',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Save forensic investigation as a portable Markdown (.md) document.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Scope Summary Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildScopeRow('Target Repository', repoName),
                    const SizedBox(height: 8),
                    _buildScopeRow(
                      'Snapshot ID',
                      shortSnapshot,
                      isMonospace: true,
                    ),
                    const SizedBox(height: 8),
                    _buildScopeRow(
                      'Inspected Evidence',
                      '$fileCount tracked files · $commitCount commits',
                    ),
                    const SizedBox(height: 8),
                    _buildScopeRow(
                      'Model Runtime',
                      'gemma4:e2b (local CPU inference)',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Privacy & Sanitization Notice
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.6),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: AppColors.accentCyan,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Privacy Guard: Absolute user paths, API tokens, and raw prompts are automatically scrubbed.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Optional Q&A Toggle
              if (hasGhostQa) ...[
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.accentCyan,
                  checkColor: AppColors.background,
                  title: const Text(
                    'Include Ask the Ghost Q&A inquiries',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: const Text(
                    'Attaches grounded user queries, claims with badges, and missing evidence notes.',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                  value: _includeGhostQa,
                  onChanged: (val) {
                    setState(() {
                      _includeGhostQa = val ?? true;
                    });
                  },
                ),
                const SizedBox(height: 12),
              ],

              // Actions
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textMuted,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pop(ExportOptions(includeGhostQa: _includeGhostQa));
                      },
                      icon: const Icon(Icons.save_alt_rounded, size: 16),
                      label: const Text('Save as Markdown (.md)...'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accentCyan,
                        foregroundColor: AppColors.background,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScopeRow(
    String label,
    String value, {
    bool isMonospace = false,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontFamily: isMonospace ? 'Consolas' : null,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
