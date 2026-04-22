import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../controllers/workspace_controller.dart';
import '../models/workspace_models.dart';
import 'ui_primitives.dart';

class WorkspaceListCard extends StatelessWidget {
  const WorkspaceListCard({
    required this.controller,
    required this.dragging,
    required this.onDraggingChanged,
    super.key,
  });

  final WorkspaceController controller;
  final bool dragging;
  final ValueChanged<bool> onDraggingChanged;

  @override
  Widget build(BuildContext context) {
    final entries = controller.visibleEntries;

    return DropTarget(
      onDragEntered: (_) {
        onDraggingChanged(true);
      },
      onDragExited: (_) {
        onDraggingChanged(false);
      },
      onDragDone: (details) {
        onDraggingChanged(false);
        controller.handleDroppedPaths(details.files.map((file) => file.path));
      },
      child: WorkspacePanel(
        borderColor: dragging ? const Color(0xFF0F766E) : const Color(0xFFD8D5C9),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE6E1D3)),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'Workspace',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${entries.length} visible',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF64706B),
                        ),
                  ),
                ],
              ),
            ),
            _ListHeader(controller: controller),
            Expanded(
              child: entries.isEmpty
                  ? _WorkspaceEmptyState(hasEntries: controller.totalCount > 0)
                  : Scrollbar(
                      child: ListView.separated(
                        padding: const EdgeInsets.only(bottom: 12),
                        itemCount: entries.length,
                        separatorBuilder: (context, index) {
                          return const Divider(height: 1, color: Color(0xFFF0ECE2));
                        },
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          final focused = controller.focusedEntry?.path == entry.path;
                          return _EntryRow(
                            entry: entry,
                            focused: focused,
                            onToggleChecked: () {
                              controller.toggleChecked(entry.path);
                            },
                            onFocus: () {
                              controller.focusEntry(entry.path);
                            },
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListHeader extends StatelessWidget {
  const _ListHeader({required this.controller});

  final WorkspaceController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFFBF8F0),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE6E1D3)),
        ),
      ),
      child: Row(
        children: addHorizontalSpacing(<Widget>[
          SizedBox(
            width: 44,
            child: Tooltip(
              message: controller.allVisibleChecked
                  ? 'Unselect all visible files'
                  : 'Select all visible files',
              child: Checkbox(
                tristate: true,
                value: controller.visibleSelectionState,
                onChanged: controller.isBusy || !controller.hasVisibleEntries
                    ? null
                    : (_) {
                        controller.setCheckedForVisible(!controller.allVisibleChecked);
                      },
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: _SortLabel(
              label: 'Path',
              active: controller.sortField == EntrySortField.path,
              ascending: controller.sortAscending,
              onPressed: () {
                controller.sortBy(EntrySortField.path);
              },
            ),
          ),
          SizedBox(
            width: 92,
            child: _SortLabel(
              label: 'Current',
              active: controller.sortField == EntrySortField.current,
              ascending: controller.sortAscending,
              onPressed: () {
                controller.sortBy(EntrySortField.current);
              },
            ),
          ),
          SizedBox(
            width: 210,
            child: _SortLabel(
              label: 'Result',
              active: controller.sortField == EntrySortField.result,
              ascending: controller.sortAscending,
              onPressed: () {
                controller.sortBy(EntrySortField.result);
              },
            ),
          ),
        ], spacing: 12),
      ),
    );
  }
}

class _SortLabel extends StatelessWidget {
  const _SortLabel({
    required this.label,
    required this.active,
    required this.ascending,
    required this.onPressed,
  });

  final String label;
  final bool active;
  final bool ascending;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Row(
        children: [
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF31413B),
                  ),
            ),
          ),
          if (active)
            Icon(
              ascending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 16,
              color: const Color(0xFF0F766E),
            ),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.focused,
    required this.onToggleChecked,
    required this.onFocus,
  });

  final ExecutableEntry entry;
  final bool focused;
  final VoidCallback onToggleChecked;
  final VoidCallback onFocus;

  @override
  Widget build(BuildContext context) {
    final statusTextStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: entry.isReady ? const Color(0xFF5A6B64) : const Color(0xFF9B3C35),
        );

    return Material(
      color: focused ? const Color(0xFFF0F8F5) : Colors.white,
      child: InkWell(
        onTap: onFocus,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: addHorizontalSpacing(<Widget>[
              SizedBox(
                width: 44,
                child: Checkbox(
                  value: entry.isChecked,
                  onChanged: (_) {
                    onToggleChecked();
                  },
                ),
              ),
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.basename(entry.path),
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Tooltip(
                      message: entry.path,
                      child: Text(
                        entry.path,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF5A6B64),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 92,
                child: _StatePill(
                  label: entry.currentLabel,
                  tone: entry.isReady
                      ? (entry.currentLaa == true ? _PillTone.positive : _PillTone.neutral)
                      : _PillTone.negative,
                ),
              ),
              SizedBox(
                width: 210,
                child: Text(
                  entry.statusLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: statusTextStyle,
                ),
              ),
            ], spacing: 12),
          ),
        ),
      ),
    );
  }
}

enum _PillTone {
  positive,
  neutral,
  negative,
}

class _StatePill extends StatelessWidget {
  const _StatePill({required this.label, required this.tone});

  final String label;
  final _PillTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      _PillTone.positive => (const Color(0xFFDDEFE8), const Color(0xFF145A43)),
      _PillTone.neutral => (const Color(0xFFE9E7DE), const Color(0xFF47443C)),
      _PillTone.negative => (const Color(0xFFF6E0DC), const Color(0xFF9B3C35)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _WorkspaceEmptyState extends StatelessWidget {
  const _WorkspaceEmptyState({required this.hasEntries});

  final bool hasEntries;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasEntries ? Icons.filter_alt_off : Icons.note_add_outlined,
            size: 36,
            color: const Color(0xFF7A857C),
          ),
          const SizedBox(height: 8),
          Text(
            hasEntries
                ? 'No files match the current filter.'
                : 'Add files or drop .exe files here to begin.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}