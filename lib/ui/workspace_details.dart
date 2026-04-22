import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../controllers/workspace_controller.dart';
import '../models/workspace_models.dart';
import 'ui_primitives.dart';

class DetailsPanel extends StatelessWidget {
  const DetailsPanel({required this.controller, super.key});

  final WorkspaceController controller;

  @override
  Widget build(BuildContext context) {
    final entry = controller.focusedEntry;

    return WorkspacePanel(
      child: entry == null
          ? const Center(
              child: Text('Select a file to inspect details.'),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.basename(entry.path),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    entry.path,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF5B6B64),
                        ),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: entry.isChecked,
                    title: const Text('Include this file in batch actions'),
                    onChanged: (_) {
                      controller.toggleChecked(entry.path);
                    },
                  ),
                  const SizedBox(height: 8),
                  _DetailField(label: 'Parse status', value: entry.statusLabel),
                  _DetailField(label: 'Current LAA', value: entry.currentLabel),
                  _DetailField(
                    label: 'Characteristics',
                    value: entry.characteristics == null
                        ? 'Unavailable'
                        : '0x${entry.characteristics!.toRadixString(16).padLeft(4, '0').toUpperCase()}',
                  ),
                  _DetailField(
                    label: '32-bit machine flag',
                    value: entry.has32BitMachineFlag == null
                        ? 'Unavailable'
                        : (entry.has32BitMachineFlag! ? 'Present' : 'Not present'),
                  ),
                  const SizedBox(height: 16),
                  if (entry.problem.isNotEmpty && !entry.isReady)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8E2DE),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        entry.problem,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF9B3C35),
                            ),
                      ),
                    ),
                  if (entry.isReady) ...[
                    Text(
                      'LAA actions',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: controller.isBusy
                              ? null
                              : () {
                                  controller.applyFocused(LaaAction.enable);
                                },
                          child: const Text('Set On'),
                        ),
                        OutlinedButton(
                          onPressed: controller.isBusy
                              ? null
                              : () {
                                  controller.applyFocused(LaaAction.disable);
                                },
                          child: const Text('Set Off'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F0E5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE1DCCF)),
                      ),
                      child: Text(
                        'LAA mostly matters for 32-bit executables. It does not turn a program into 64-bit, but it can let a compatible process access more virtual memory.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF5C5648),
                            ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class StatusBar extends StatelessWidget {
  const StatusBar({required this.controller, super.key});

  final WorkspaceController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFECE8DC),
        border: Border(
          top: BorderSide(color: Color(0xFFD6D1C0)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              controller.statusMessage,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Text(
            '${controller.checkedCount} selected',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _DetailField extends StatelessWidget {
  const _DetailField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF62706B),
                ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}