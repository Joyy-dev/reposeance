import 'package:flutter/material.dart';
import 'package:reposeance/core/theme/app_colors.dart';
import 'package:reposeance/features/repository/domain/models/scan_result.dart';

/// Warning banner displayed prominently when scanner limits are reached.
/// Discloses partial scope and reinforces data truthfulness.
class PartialScanBanner extends StatelessWidget {
  final ScanResult scanResult;

  const PartialScanBanner({super.key, required this.scanResult});

  @override
  Widget build(BuildContext context) {
    if (!scanResult.isPartial) {
      return const SizedBox.shrink();
    }

    final warnings = scanResult.partialWarnings;
    final warningText = warnings.isNotEmpty
        ? warnings.join(' · ')
        : 'Inspection limits reached (${scanResult.files.length} files selected, ${scanResult.commits.length} commits inspected).';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.accentAmber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.accentAmber.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 20,
            color: AppColors.accentAmber,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PARTIAL SCOPE INSPECTION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.accentAmber,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  warningText,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Caveat: Excluded, uninspected, or untracked files may change the interpretation. '
                  'Findings represent only what is proved by the bounded snapshot excerpts.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.35,
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
