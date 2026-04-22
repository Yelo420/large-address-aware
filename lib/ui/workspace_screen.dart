import 'package:flutter/material.dart';

import '../controllers/workspace_controller.dart';
import 'workspace_details.dart';
import 'workspace_header.dart';
import 'workspace_list.dart';

class LaaWorkspaceScreen extends StatefulWidget {
  const LaaWorkspaceScreen({super.key, required this.controller});

  final WorkspaceController controller;

  @override
  State<LaaWorkspaceScreen> createState() => _LaaWorkspaceScreenState();
}

class _LaaWorkspaceScreenState extends State<LaaWorkspaceScreen> {
  bool _dragging = false;

  void _setDragging(bool value) {
    if (_dragging == value) {
      return;
    }

    setState(() {
      _dragging = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                HeaderBand(controller: controller),
                if (controller.isBusy)
                  LinearProgressIndicator(value: controller.busyProgress),
                WorkspaceMetrics(controller: controller),
                FilterRow(controller: controller),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _WorkspaceContent(
                      controller: controller,
                      dragging: _dragging,
                      onDraggingChanged: _setDragging,
                    ),
                  ),
                ),
                StatusBar(controller: controller),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WorkspaceContent extends StatelessWidget {
  const _WorkspaceContent({
    required this.controller,
    required this.dragging,
    required this.onDraggingChanged,
  });

  final WorkspaceController controller;
  final bool dragging;
  final ValueChanged<bool> onDraggingChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wideLayout = constraints.maxWidth >= 1160;

        if (wideLayout) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 7,
                child: WorkspaceListCard(
                  controller: controller,
                  dragging: dragging,
                  onDraggingChanged: onDraggingChanged,
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 360,
                child: DetailsPanel(controller: controller),
              ),
            ],
          );
        }

        return Column(
          children: [
            Expanded(
              flex: 5,
              child: WorkspaceListCard(
                controller: controller,
                dragging: dragging,
                onDraggingChanged: onDraggingChanged,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              flex: 3,
              child: DetailsPanel(controller: controller),
            ),
          ],
        );
      },
    );
  }
}