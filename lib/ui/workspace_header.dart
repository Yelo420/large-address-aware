import 'package:flutter/material.dart';

import '../controllers/workspace_controller.dart';
import '../models/workspace_models.dart';
import 'ui_primitives.dart';

class HeaderBand extends StatelessWidget {
  const HeaderBand({required this.controller, super.key});

  final WorkspaceController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            const Color(0xFFE7E3D5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Large Address Aware',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF14302A),
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Set the Windows PE LAA flag so compatible 32-bit executables can use more virtual memory.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF31413B),
                ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: addHorizontalSpacing(<Widget>[
                FilledButton.icon(
                  onPressed: controller.isBusy ? null : controller.addFilesFromDialog,
                  icon: const Icon(Icons.note_add_outlined),
                  label: const Text('Add Files'),
                ),
                OutlinedButton.icon(
                  onPressed: controller.isBusy
                      ? null
                      : () {
                          controller.scanFolder(recursive: false);
                        },
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Scan Folder'),
                ),
                OutlinedButton.icon(
                  onPressed: controller.isBusy
                      ? null
                      : () {
                          controller.scanFolder(recursive: true);
                        },
                  icon: const Icon(Icons.travel_explore),
                  label: const Text('Scan Recursive'),
                ),
                PopupMenuButton<LaaAction>(
                  enabled: !controller.isBusy && controller.checkedCount > 0,
                  onSelected: controller.applySelected,
                  itemBuilder: (context) {
                    return const [
                      PopupMenuItem<LaaAction>(
                        value: LaaAction.enable,
                        child: Text('Set Selected LAA On'),
                      ),
                      PopupMenuItem<LaaAction>(
                        value: LaaAction.disable,
                        child: Text('Set Selected LAA Off'),
                      ),
                    ];
                  },
                  child: const _HeaderMenuChip(
                    icon: Icons.playlist_add_check_circle_outlined,
                    label: 'Apply Selected',
                  ),
                ),
                PopupMenuButton<String>(
                  enabled: !controller.isBusy,
                  onSelected: (value) {
                    switch (value) {
                      case 'removeSelected':
                        controller.removeSelected();
                      case 'removeAll':
                        controller.removeAll();
                    }
                  },
                  itemBuilder: (context) {
                    return const [
                      PopupMenuItem<String>(
                        value: 'removeSelected',
                        child: Text('Remove Selected'),
                      ),
                      PopupMenuItem<String>(
                        value: 'removeAll',
                        child: Text('Remove All'),
                      ),
                    ];
                  },
                  child: const _HeaderMenuChip(
                    icon: Icons.delete_outline,
                    label: 'Remove',
                  ),
                ),
                _HeaderToggleChip(
                  label: 'Load Previous Files',
                  selected: controller.loadPreviousFiles,
                  onSelected: controller.isBusy
                      ? null
                      : (value) {
                          controller.setLoadPreviousFiles(value);
                        },
                ),
                ActionChip(
                  avatar: const Icon(Icons.info_outline, size: 18),
                  label: const Text('What Is LAA?'),
                  onPressed: () {
                    _showLaaInfoDialog(context);
                  },
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class WorkspaceMetrics extends StatelessWidget {
  const WorkspaceMetrics({required this.controller, super.key});

  final WorkspaceController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: addHorizontalSpacing(<Widget>[
            _MetricChip(label: 'Loaded', value: controller.totalCount.toString()),
            _MetricChip(label: 'Selected', value: controller.checkedCount.toString()),
            _MetricChip(label: 'Invalid', value: controller.invalidCount.toString()),
          ]),
        ),
      ),
    );
  }
}

class FilterRow extends StatelessWidget {
  const FilterRow({required this.controller, super.key});

  final WorkspaceController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: addHorizontalSpacing(
            WorkspaceFilter.values.map((filter) {
              return ChoiceChip(
                label: Text(filter.label),
                selected: controller.filter == filter,
                onSelected: (_) {
                  controller.setFilter(filter);
                },
              );
            }).toList(growable: false),
          ),
        ),
      ),
    );
  }
}

class _HeaderMenuChip extends StatelessWidget {
  const _HeaderMenuChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD6D1C0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

class _HeaderToggleChip extends StatelessWidget {
  const _HeaderToggleChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: const StadiumBorder(
        side: BorderSide(color: Color(0xFFD6D1C0)),
      ),
      side: const BorderSide(color: Color(0xFFD6D1C0)),
      backgroundColor: Colors.white.withValues(alpha: 0.68),
      selectedColor: const Color(0xFFD9F0ED),
      labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: selected ? const Color(0xFF0F766E) : const Color(0xFF2F3935),
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD8D5C9)),
      ),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFF2F3935),
              ),
          children: [
            TextSpan(text: '$label '),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showLaaInfoDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('What LAA Does'),
        content: const SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Large Address Aware is a Windows PE header flag.'),
              SizedBox(height: 12),
              Text(
                'When it is enabled on a compatible 32-bit executable, 64-bit Windows can give that process more virtual address space. That can help apps that crash near the 2 GB memory limit.',
              ),
              SizedBox(height: 12),
              Text(
                'It does not make the program 64-bit, it does not improve CPU speed, and it may not help every app. Keep a backup of the original executable before changing it.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}