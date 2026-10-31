import 'package:flutter/material.dart';

import '../../../../core/services/ollama_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/readiness_state.dart';

/// Top bar displaying app title and compact live status badges for Git, Ollama, and Gemma.
class StatusHeader extends StatelessWidget {
  final SystemReadinessState state;
  final VoidCallback onRefresh;

  const StatusHeader({super.key, required this.state, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          // RepoSéance Brand
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.borderLight, width: 1),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 16,
                  color: AppColors.accentAmber,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'RepoSéance',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'v1.0 (M2)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentCyan,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          const Spacer(),

          // System Diagnostics Badges in scrollable row to prevent any overflow on narrow widths
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildStatusPill(
                    label: 'Git',
                    statusText: state.gitResult.isInstalled
                        ? 'Ready'
                        : 'Missing',
                    isReady: state.gitResult.isInstalled,
                    color: state.gitResult.isInstalled
                        ? AppColors.success
                        : AppColors.error,
                  ),
                  const SizedBox(width: 10),
                  _buildOllamaPill(state.ollamaResult),
                  const SizedBox(width: 10),
                  _buildGemmaPill(state.ollamaResult),
                  const SizedBox(width: 12),
                  // Refresh button
                  IconButton(
                    onPressed: state.isChecking ? null : onRefresh,
                    tooltip: 'Re-check system readiness',
                    icon: state.isChecking
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
                        : const Icon(
                            Icons.refresh,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill({
    required String label,
    required String statusText,
    required bool isReady,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            statusText,
            style: AppTheme.monoStyle.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOllamaPill(OllamaHealthResult result) {
    String text;
    Color color;

    switch (result.status) {
      case OllamaHealthStatus.checking:
        text = 'Checking...';
        color = AppColors.checking;
        break;
      case OllamaHealthStatus.ready:
      case OllamaHealthStatus.runningModelMissing:
        text = result.version != null ? 'v${result.version}' : 'Online';
        color = AppColors.success;
        break;
      case OllamaHealthStatus.unreachable:
        text = 'Offline';
        color = AppColors.error;
        break;
    }

    return _buildStatusPill(
      label: 'Ollama',
      statusText: text,
      isReady:
          result.status != OllamaHealthStatus.unreachable &&
          result.status != OllamaHealthStatus.checking,
      color: color,
    );
  }

  Widget _buildGemmaPill(OllamaHealthResult result) {
    String text;
    Color color;

    switch (result.status) {
      case OllamaHealthStatus.checking:
        text = 'Checking...';
        color = AppColors.checking;
        break;
      case OllamaHealthStatus.ready:
        text = 'gemma4:e2b';
        color = AppColors.success;
        break;
      case OllamaHealthStatus.runningModelMissing:
        text = 'Model Missing';
        color = AppColors.warning;
        break;
      case OllamaHealthStatus.unreachable:
        text = 'Unavailable';
        color = AppColors.error;
        break;
    }

    return _buildStatusPill(
      label: 'Model',
      statusText: text,
      isReady: result.status == OllamaHealthStatus.ready,
      color: color,
    );
  }
}
