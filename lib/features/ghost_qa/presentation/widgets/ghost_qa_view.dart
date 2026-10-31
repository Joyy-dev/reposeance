import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reposeance/core/theme/app_colors.dart';
import 'package:reposeance/features/autopsy/domain/models/autopsy_finding.dart';
import 'package:reposeance/features/autopsy/domain/models/evidence_item.dart';
import 'package:reposeance/features/workbench/controllers/workbench_controller.dart';
import 'package:reposeance/features/workbench/domain/models/workbench_state.dart';

/// Interactive Ask the Ghost Q&A interface embedded in the RepoSéance workbench.
/// Bounded strictly to the in-memory EvidenceSnapshot with citation previewing in EvidenceDrawer.
class GhostQaView extends StatefulWidget {
  const GhostQaView({super.key});

  @override
  State<GhostQaView> createState() => _GhostQaViewState();
}

class _GhostQaViewState extends State<GhostQaView> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  static const List<String> _suggestedQuestions = [
    'What database or persistence layer is configured?',
    'What dependencies are declared in manifests?',
    'How is authentication or authorization structured?',
    'Why was SQLite chosen over PostgreSQL?',
  ];

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitQuestion(WorkbenchController controller) {
    final query = _textController.text.trim();
    if (query.isNotEmpty && !controller.state.isGhostQaLoading) {
      controller.askGhost(query);
    }
  }

  void _useSuggestion(WorkbenchController controller, String question) {
    _textController.text = question;
    controller.askGhost(question);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WorkbenchController>();
    final state = controller.state;
    final isLoading = state.isGhostQaLoading;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isLoading
              ? AppColors.accentAmber.withValues(alpha: 0.5)
              : AppColors.border,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Eyebrow
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accentCyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppColors.accentCyan.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: const Text(
                  'Interactive Software Archaeology',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.accentCyan,
                  ),
                ),
              ),
              if (state.ghostAnswer != null && !isLoading)
                TextButton.icon(
                  onPressed: controller.clearGhostAnswer,
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('New Inquiry'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Title & Description
          const Text(
            'Ask the Ghost (Interactive Q&A)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ask a targeted question about this repository. Queries use deterministic lexical retrieval over snapshot evidence with strict refusal of unrecorded developer motives.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),

          // Suggested Question Chips (shown when idle or answered)
          if (!isLoading) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _suggestedQuestions.map((q) {
                return ActionChip(
                  label: Text(q),
                  onPressed: () => _useSuggestion(controller, q),
                  backgroundColor: AppColors.surfaceElevated,
                  side: const BorderSide(
                    color: AppColors.borderLight,
                    width: 0.8,
                  ),
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Input Form Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  enabled: !isLoading,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submitQuestion(controller),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. What database is used, or what dependencies are declared?',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(
                        color: AppColors.borderLight,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(
                        color: AppColors.accentCyan,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (isLoading)
                OutlinedButton.icon(
                  onPressed: controller.cancelGhostQuestion,
                  icon: const Icon(Icons.close, size: 14),
                  label: const Text('Cancel'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(
                      color: AppColors.error.withValues(alpha: 0.6),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: () => _submitQuestion(controller),
                  icon: const Icon(Icons.send, size: 14),
                  label: const Text('Ask Ghost'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentAmber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),

          // Loading View (truthful stage text + live elapsed duration timer)
          if (isLoading) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.accentAmber,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                state.ghostQaStageText,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _formatDuration(state.ghostQaElapsedDuration),
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'Consolas',
                          color: AppColors.accentAmber,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.accentAmber,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Error View
          if (state.ghostQaStatus == GhostQaStatus.failed &&
              state.ghostQaErrorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 18,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      state.ghostQaErrorMessage!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Cancelled View
          if (state.ghostQaStatus == GhostQaStatus.cancelled) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.cancel_outlined,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    state.ghostQaStageText,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Answer View
          if (state.ghostAnswer != null && !isLoading) ...[
            const SizedBox(height: 20),
            _buildAnswerCard(controller, state),
          ],
        ],
      ),
    );
  }

  Widget _buildAnswerCard(
    WorkbenchController controller,
    WorkbenchState state,
  ) {
    final answer = state.ghostAnswer!;
    final question = state.ghostQuestion?.text;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: answer.notFound
              ? AppColors.warning.withValues(alpha: 0.4)
              : AppColors.accentCyan.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question header
          if (question != null) ...[
            Row(
              children: [
                const Icon(
                  Icons.help_outline,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Inquiry: "$question"',
                    style: const TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(color: AppColors.border, height: 24),
          ],

          // Answer Body
          if (answer.notFound) ...[
            // Honest Not Found Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.5),
                ),
              ),
              child: const Text(
                'Insufficient Repository Evidence',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.warning,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              answer.missingEvidence ?? 'The supplied repository files and commits do not establish an answer to this inquiry.',
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'No private developer motives or uninspected architecture are assumed or confabulated.',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: AppColors.textMuted,
              ),
            ),
          ] else ...[
            // Grounded Claims List
            for (int i = 0; i < answer.claims.length; i++) ...[
              _buildClaimItem(
                claim: answer.claims[i],
                index: i + 1,
                snapshot: state.evidenceSnapshot,
                onCitationTap: controller.openEvidence,
              ),
              if (i < answer.claims.length - 1) const SizedBox(height: 14),
            ],
          ],

          // Latency & Token Provenance Footer
          if (answer.latency != null || answer.evalCount != null) ...[
            const SizedBox(height: 16),
            const Divider(color: AppColors.border, height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Supplied Evidence: ${answer.suppliedEvidenceIds.length} items',
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'Consolas',
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  '${answer.latency != null ? '${(answer.latency!.inMilliseconds / 1000).toStringAsFixed(1)}s' : ''}'
                  '${answer.evalCount != null ? ' · ${answer.evalCount} tokens' : ''}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'Consolas',
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildClaimItem({
    required AutopsyFinding claim,
    required int index,
    required dynamic snapshot,
    required void Function(String id) onCitationTap,
  }) {
    final isObserved = claim.kind == FindingKind.observed;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderLight, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isObserved
                      ? AppColors.accentCyan.withValues(alpha: 0.12)
                      : AppColors.accentAmber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isObserved
                        ? AppColors.accentCyan.withValues(alpha: 0.4)
                        : AppColors.accentAmber.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  isObserved ? 'Observed' : 'Inferred',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isObserved
                        ? AppColors.accentCyan
                        : AppColors.accentAmber,
                  ),
                ),
              ),
              Text(
                'Claim $index',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            claim.text,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: claim.evidenceIds.map((id) {
              String label = id;
              final item = snapshot?.evidenceMap[id];
              if (item is FileEvidence) {
                final filename = item.repositoryRelativePath
                    .split(RegExp(r'[\\/]'))
                    .last;
                label = '$id · $filename';
              } else if (item is CommitEvidence) {
                final shortHash = item.commitHash.length > 7
                    ? item.commitHash.substring(0, 7)
                    : item.commitHash;
                label = '$id · Commit $shortHash';
              }

              return OutlinedButton.icon(
                onPressed: () => onCitationTap(id),
                icon: const Icon(Icons.north_east, size: 11),
                label: Text(label),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accentCyan,
                  side: BorderSide(
                    color: AppColors.accentCyan.withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                  backgroundColor: AppColors.surfaceElevated.withValues(
                    alpha: 0.6,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'Consolas',
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds elapsed';
  }
}
