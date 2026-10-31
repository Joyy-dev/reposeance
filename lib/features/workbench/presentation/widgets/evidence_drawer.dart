import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:reposeance/core/theme/app_colors.dart';
import 'package:reposeance/features/autopsy/domain/models/evidence_item.dart';
import 'package:reposeance/features/workbench/controllers/workbench_controller.dart';
import 'package:reposeance/features/workbench/domain/models/workbench_state.dart';

/// Lateral slide-out evidence drawer with accessible keyboard focus and Escape handling.
/// Renders tagged union EvidenceItem (FileEvidence vs CommitEvidence).
class EvidenceDrawer extends StatefulWidget {
  final WorkbenchState state;
  final WorkbenchController controller;

  const EvidenceDrawer({
    super.key,
    required this.state,
    required this.controller,
  });

  @override
  State<EvidenceDrawer> createState() => _EvidenceDrawerState();
}

class _EvidenceDrawerState extends State<EvidenceDrawer> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      widget.controller.closeEvidence();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final activeItem = widget.state.activeEvidenceItem;
    if (activeItem == null) {
      return const SizedBox.shrink();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = screenWidth > 640 ? 520.0 : screenWidth;

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          width: drawerWidth,
          height: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: const Border(
              left: BorderSide(color: AppColors.borderLight, width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 30,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Column(
            children: [
              // Top Bar
              _buildTopBar(context),
              const Divider(color: AppColors.border, height: 1),

              // Scrollable Evidence Details
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildEvidenceDetails(activeItem),
                      const SizedBox(height: 24),
                      _buildGroundingDisclaimer(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: AppColors.surfaceElevated,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.accentCyan,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'CAPTURED EVIDENCE INSPECTOR',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.accentCyan,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: widget.controller.closeEvidence,
            tooltip: 'Close Evidence (Esc)',
            icon: const Icon(Icons.close, size: 18),
            style: IconButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              padding: const EdgeInsets.all(6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceDetails(EvidenceItem item) {
    switch (item) {
      case FileEvidence(
        :final id,
        :final repositoryRelativePath,
        :final startLine,
        :final endLine,
        :final content,
        :final contentHash,
      ):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Evidence ID & Path
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentCyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: AppColors.accentCyan.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    id,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'Consolas',
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentCyan,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'File Evidence',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Text(
              repositoryRelativePath,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),

            Text(
              'Captured lines $startLine–$endLine · SHA-256: ${contentHash.length > 16 ? contentHash.substring(0, 16) : contentHash}...',
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'Consolas',
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),

            // Monospaced Source Code Viewer with Line Numbers
            _buildCodeViewer(content, startLine),
          ],
        );

      case CommitEvidence(
        :final id,
        :final commitHash,
        :final date,
        :final subject,
        :final author,
      ):
        final shortHash = commitHash.length > 7
            ? commitHash.substring(0, 7)
            : commitHash;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Evidence ID & Commit short hash
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentAmber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: AppColors.accentAmber.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    id,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'Consolas',
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentAmber,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Commit Evidence',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Text(
              'Commit $shortHash',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),

            Text(
              'Date: ${date.toIso8601String()} · Author: $author',
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'Consolas',
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),

            // Commit Excerpt Viewer
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Subject:',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'Consolas',
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    subject,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Full Commit Hash:',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'Consolas',
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    commitHash,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'Consolas',
                      color: AppColors.accentCyan,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCodeViewer(String content, int startLine) {
    final lines = content.split('\n');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: SelectableText.rich(
        TextSpan(
          children: lines.asMap().entries.map((entry) {
            final lineNum = (startLine + entry.key).toString().padLeft(3, ' ');
            final isLast = entry.key == lines.length - 1;
            return TextSpan(
              children: [
                TextSpan(
                  text: '$lineNum  ',
                  style: const TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                TextSpan(
                  text: '${entry.value}${isLast ? '' : '\n'}',
                  style: const TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 12,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildGroundingDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.shield_outlined,
                size: 14,
                color: AppColors.accentAmber,
              ),
              SizedBox(width: 8),
              Text(
                'EVIDENCE PROVENANCE INVARIANT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppColors.accentAmber,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Showing captured snapshot excerpt. Production references resolve strictly '
            'through the immutable snapshot allowlist, not live unversioned files on disk.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'A valid reference proves where an excerpt was captured—not that an AI interpretation is correct.',
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
}
