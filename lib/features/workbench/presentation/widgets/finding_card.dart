import 'package:flutter/material.dart';
import 'package:reposeance/core/theme/app_colors.dart';
import 'package:reposeance/features/autopsy/domain/models/autopsy_finding.dart';
import 'package:reposeance/features/autopsy/domain/models/evidence_item.dart';
import 'package:reposeance/features/autopsy/domain/models/evidence_snapshot.dart';

/// Card rendering an individual autopsy finding with factual kind badge,
/// text content, and clickable citation buttons.
class FindingCard extends StatelessWidget {
  final AutopsyFinding finding;
  final EvidenceSnapshot? snapshot;
  final void Function(String evidenceId) onCitationClicked;
  final String? heading;

  const FindingCard({
    super.key,
    required this.finding,
    required this.snapshot,
    required this.onCitationClicked,
    this.heading,
  });

  @override
  Widget build(BuildContext context) {
    final isObserved = finding.kind == FindingKind.observed;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kind Badge (Observed vs Inferred)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isObserved
                      ? AppColors.accentCyan.withValues(alpha: 0.12)
                      : AppColors.accentAmber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isObserved
                        ? AppColors.accentCyan.withValues(alpha: 0.4)
                        : AppColors.accentAmber.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Text(
                  isObserved ? 'Observed' : 'Inferred',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: isObserved
                        ? AppColors.accentCyan
                        : AppColors.accentAmber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Optional Heading
          if (heading != null) ...[
            Text(
              heading!,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
          ],

          // Finding Text
          Text(
            finding.text,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),

          // Clickable Citation Pills
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: finding.evidenceIds.map((id) {
              return _buildCitationPill(id);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCitationPill(String id) {
    String label = id;
    final item = snapshot?.evidenceMap[id];
    if (item != null) {
      switch (item) {
        case FileEvidence(:final repositoryRelativePath):
          final filename = repositoryRelativePath.split(RegExp(r'[\\/]')).last;
          label = '$id · $filename';
        case CommitEvidence(:final commitHash):
          final shortHash = commitHash.length > 7
              ? commitHash.substring(0, 7)
              : commitHash;
          label = '$id · Commit $shortHash';
        default:
          break;
      }
    }

    return OutlinedButton.icon(
      onPressed: () => onCitationClicked(id),
      icon: const Icon(Icons.north_east, size: 12),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.accentCyan,
        side: BorderSide(
          color: AppColors.accentCyan.withValues(alpha: 0.4),
          width: 1,
        ),
        backgroundColor: AppColors.surfaceElevated.withValues(alpha: 0.5),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        textStyle: const TextStyle(
          fontSize: 12,
          fontFamily: 'Consolas',
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }
}
