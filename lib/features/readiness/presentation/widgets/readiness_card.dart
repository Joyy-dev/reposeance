import 'package:flutter/material.dart';

import '../../../../core/services/ollama_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/readiness_state.dart';

/// Diagnostic card detailing local environment health and readiness.
class ReadinessCard extends StatelessWidget {
  final SystemReadinessState state;

  const ReadinessCard({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.analytics_outlined,
                size: 20,
                color: AppColors.accentCyan,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Host Environment Diagnostics',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (state.lastChecked != null)
                Text(
                  'Checked: ${_formatTime(state.lastChecked!)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // Responsive Diagnostic Items
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 650;

              final gitTile = _buildDiagnosticTile(
                icon: Icons.source_outlined,
                title: 'Git Binary',
                statusLabel: state.gitResult.isInstalled
                    ? 'Operational'
                    : 'Unavailable',
                statusColor: state.gitResult.isInstalled
                    ? AppColors.success
                    : AppColors.error,
                detailText: state.gitResult.isInstalled
                    ? (state.gitResult.version ?? 'Git available')
                    : (state.gitResult.error ??
                          'git executable not found in PATH'),
                extraMeta: 'Safe subprocess runner (runInShell: false)',
              );

              final ollamaTile = _buildDiagnosticTile(
                icon: Icons.computer_outlined,
                title: 'Ollama Service',
                statusLabel: _getOllamaStatusLabel(state.ollamaResult),
                statusColor: _getOllamaStatusColor(state.ollamaResult),
                detailText: 'Endpoint: http://127.0.0.1:11434',
                extraMeta:
                    state.ollamaResult.status == OllamaHealthStatus.unreachable
                    ? (state.ollamaResult.error ?? 'Service not listening')
                    : 'Latency: ${state.ollamaResult.responseTimeMs} ms • ${state.ollamaResult.models.length} model(s) installed',
              );

              final modelTile = _buildDiagnosticTile(
                icon: Icons.psychology_outlined,
                title: 'Local Model',
                statusLabel:
                    state.ollamaResult.status == OllamaHealthStatus.ready
                    ? 'Ready'
                    : (state.ollamaResult.status ==
                              OllamaHealthStatus.runningModelMissing
                          ? 'Missing'
                          : 'Unavailable'),
                statusColor:
                    state.ollamaResult.status == OllamaHealthStatus.ready
                    ? AppColors.success
                    : (state.ollamaResult.status ==
                              OllamaHealthStatus.runningModelMissing
                          ? AppColors.warning
                          : AppColors.error),
                detailText: 'Pinned: gemma4:e2b',
                extraMeta: state.ollamaResult.status == OllamaHealthStatus.ready
                    ? 'CPU inference mode verified'
                    : 'Run "ollama pull gemma4:e2b" in terminal',
              );

              if (isCompact) {
                return Column(
                  children: [
                    gitTile,
                    const SizedBox(height: 12),
                    ollamaTile,
                    const SizedBox(height: 12),
                    modelTile,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: gitTile),
                  const SizedBox(width: 14),
                  Expanded(child: ollamaTile),
                  const SizedBox(width: 14),
                  Expanded(child: modelTile),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticTile({
    required IconData icon,
    required String title,
    required String statusLabel,
    required Color statusColor,
    required String detailText,
    required String extraMeta,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            detailText,
            style: AppTheme.monoStyle.copyWith(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            extraMeta,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _getOllamaStatusLabel(OllamaHealthResult result) {
    switch (result.status) {
      case OllamaHealthStatus.checking:
        return 'Checking';
      case OllamaHealthStatus.ready:
      case OllamaHealthStatus.runningModelMissing:
        return result.version != null ? 'v${result.version}' : 'Online';
      case OllamaHealthStatus.unreachable:
        return 'Offline';
    }
  }

  Color _getOllamaStatusColor(OllamaHealthResult result) {
    switch (result.status) {
      case OllamaHealthStatus.checking:
        return AppColors.checking;
      case OllamaHealthStatus.ready:
      case OllamaHealthStatus.runningModelMissing:
        return AppColors.success;
      case OllamaHealthStatus.unreachable:
        return AppColors.error;
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
