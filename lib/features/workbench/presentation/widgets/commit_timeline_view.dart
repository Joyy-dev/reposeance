import 'package:flutter/material.dart';
import 'package:reposeance/core/theme/app_colors.dart';
import 'package:reposeance/features/autopsy/domain/models/evidence_item.dart';
import 'package:reposeance/features/autopsy/domain/models/evidence_snapshot.dart';
import 'package:reposeance/features/repository/domain/models/git_commit.dart';

/// Renders the deterministic recent commit timeline from Git HEAD.
/// Enforces the invariant: Commit subjects record messages, never proving code changes or author intent.
class CommitTimelineView extends StatelessWidget {
  final List<GitCommit> commits;
  final EvidenceSnapshot? snapshot;
  final void Function(String evidenceId) onCitationClicked;

  const CommitTimelineView({
    super.key,
    required this.commits,
    required this.snapshot,
    required this.onCitationClicked,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            'RECORDED, NOT RECONSTRUCTED',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),

          // Heading
          const Text(
            'Development History',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),

          // Subtitle
          const Text(
            'Recent commit subjects in reverse-chronological order.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),

          // Commits List
          if (commits.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No commits found in repository.',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            )
          else
            ...commits.map((commit) => _buildCommitItem(commit)),

          const SizedBox(height: 12),

          // Mandatory Grounding Caveat
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 14,
                  color: AppColors.accentAmber,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Commit subjects record developer log messages. Without diff inspection, '
                    'the exact code change or author intent is not established.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommitItem(GitCommit commit) {
    // Look up commit in snapshot to find its assigned evidence ID
    String? matchedEvidenceId;
    if (snapshot != null) {
      for (final entry in snapshot!.evidenceMap.entries) {
        if (entry.value is CommitEvidence) {
          final ce = entry.value as CommitEvidence;
          if (ce.commitHash == commit.hash) {
            matchedEvidenceId = ce.id;
            break;
          }
        }
      }
    }

    final dateStr = commit.date.toIso8601String().split('T').first;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.only(left: 12),
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: AppColors.borderLight, width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                commit.shortHash,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'Consolas',
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentCyan,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                dateStr,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '· ${commit.author}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
              const Spacer(),
              if (matchedEvidenceId != null)
                InkWell(
                  onTap: () => onCitationClicked(matchedEvidenceId!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentCyan.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: AppColors.accentCyan.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '$matchedEvidenceId ↗',
                      style: const TextStyle(
                        fontSize: 10,
                        fontFamily: 'Consolas',
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentCyan,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            commit.subject,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
