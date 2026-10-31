import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reposeance/features/workbench/controllers/workbench_controller.dart';
import 'package:reposeance/features/workbench/domain/models/workbench_state.dart';

import '../widgets/autopsy_report_view.dart';
import '../widgets/empty_workbench_view.dart';
import '../widgets/evidence_drawer.dart';
import '../widgets/model_unavailable_view.dart';
import '../widgets/workbench_error_view.dart';
import '../widgets/workbench_header.dart';
import '../widgets/workbench_loading_view.dart';

/// Primary single-workspace scaffold for RepoSéance repository forensics.
class WorkbenchScreen extends StatelessWidget {
  const WorkbenchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkbenchController>(
      builder: (context, controller, child) {
        final state = controller.state;

        return Scaffold(
          body: Stack(
            children: [
              // Main Screen Column
              Column(
                children: [
                  // 1. Top Workbench Header (Brand, Toolchain, Directory Bar)
                  WorkbenchHeader(state: state, controller: controller),

                  // 2. Main Investigation Canvas
                  Expanded(child: _buildCanvas(context, state, controller)),
                ],
              ),

              // 3. Lateral Evidence Drawer Overlay (if evidence item is inspected)
              if (state.activeEvidenceItem != null) ...[
                // Modal Backdrop
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: controller.closeEvidence,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.4),
                    ),
                  ),
                ),

                // Lateral Slide-Out Panel
                Positioned(
                  top: 0,
                  right: 0,
                  bottom: 0,
                  child: EvidenceDrawer(state: state, controller: controller),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCanvas(
    BuildContext context,
    WorkbenchState state,
    WorkbenchController controller,
  ) {
    // 1. Loading State (Scanning or Generating)
    if (state.isLoading) {
      return WorkbenchLoadingView(state: state, controller: controller);
    }

    // 2. Fatal Error State (without prior valid report)
    if (state.status == InvestigationStatus.failed &&
        state.autopsyReport == null) {
      return WorkbenchErrorView(state: state, controller: controller);
    }

    // 3. Model Unavailable State (Ollama offline or gemma missing without report)
    if (state.isModelUnavailable && state.autopsyReport == null) {
      return ModelUnavailableView(state: state, controller: controller);
    }

    // 4. Completed Report State (or Failed/Cancelled with preserved prior report)
    if (state.autopsyReport != null) {
      return AutopsyReportView(state: state, controller: controller);
    }

    // 5. Default: Empty Workbench Landing View
    return EmptyWorkbenchView(state: state, controller: controller);
  }
}
