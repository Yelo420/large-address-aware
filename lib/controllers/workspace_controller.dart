import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/workspace_models.dart';
import '../services/pe_file_service.dart';
import '../services/settings_store.dart';

class WorkspaceController extends ChangeNotifier {
  WorkspaceController({
    required this.peFileService,
    required this.settingsStore,
  });

  static const int _loadProgressStride = 1;

  static const executableTypeGroup = XTypeGroup(
    label: 'Executables',
    extensions: <String>['exe'],
  );

  final PeFileService peFileService;
  final SettingsStore settingsStore;

  final List<ExecutableEntry> _entries = <ExecutableEntry>[];
  final Set<String> _savedPaths = <String>{};
  Future<void> _pendingSettingsSave = Future<void>.value();

  WorkspaceFilter _filter = WorkspaceFilter.all;
  EntrySortField _sortField = EntrySortField.path;
  bool _sortAscending = true;
  String? _focusedPath;

  BusyState _busyState = BusyState.idle;
  double? _busyProgress;
  String _statusMessage = 'Add files or scan a folder to begin.';

  Size _windowSize = const Size(1280, 760);
  String _defaultDirectory = '';
  bool _loadPreviousFiles = true;

  WorkspaceFilter get filter => _filter;
  EntrySortField get sortField => _sortField;
  bool get sortAscending => _sortAscending;
  bool get loadPreviousFiles => _loadPreviousFiles;
  bool get isBusy => _busyState != BusyState.idle;
  BusyState get busyState => _busyState;
  double? get busyProgress => _busyProgress;
  String get statusMessage => _statusMessage;
  Size get windowSize => _windowSize;

  List<ExecutableEntry> get allEntries => List<ExecutableEntry>.unmodifiable(_entries);

  List<ExecutableEntry> get visibleEntries {
    return _entries.where(_matchesFilter).toList(growable: false);
  }

  ExecutableEntry? get focusedEntry {
    final focusedPath = _focusedPath;
    if (focusedPath == null) {
      return null;
    }

    for (final entry in _entries) {
      if (entry.path == focusedPath) {
        return entry;
      }
    }

    return null;
  }

  int get totalCount => _entries.length;
  int get checkedCount => _entries.where((entry) => entry.isChecked).length;
  int get invalidCount => _entries.where((entry) => !entry.isReady).length;
  bool get hasVisibleEntries {
    for (final entry in _entries) {
      if (_matchesFilter(entry)) {
        return true;
      }
    }

    return false;
  }

  bool get allVisibleChecked {
    var hasVisible = false;
    for (final entry in _entries) {
      if (!_matchesFilter(entry)) {
        continue;
      }

      hasVisible = true;
      if (!entry.isChecked) {
        return false;
      }
    }

    return hasVisible;
  }

  bool get anyVisibleChecked {
    for (final entry in _entries) {
      if (_matchesFilter(entry) && entry.isChecked) {
        return true;
      }
    }

    return false;
  }

  bool? get visibleSelectionState {
    if (!hasVisibleEntries) {
      return false;
    }

    if (allVisibleChecked) {
      return true;
    }

    return anyVisibleChecked ? null : false;
  }

  Future<void> initialize(List<String> launchArgs) async {
    final settings = await settingsStore.load();
    _windowSize = settings.windowSize;
    _defaultDirectory = settings.defaultDirectory;
    _loadPreviousFiles = settings.loadPreviousFiles;
    _savedPaths
      ..clear()
      ..addAll(settings.recentPaths.map(_normalizePath));

    final startupPaths = <String>{};
    for (final path in launchArgs) {
      startupPaths.add(_normalizePath(path));
    }

    if (_loadPreviousFiles) {
      startupPaths.addAll(_savedPaths);
    }

    if (startupPaths.isNotEmpty) {
      await addPaths(startupPaths, announce: false, showBusy: false);
      _statusMessage = 'Loaded ${_entries.length} executable(s).';
    }

    notifyListeners();
  }

  Future<void> saveSettings() async {
    _pendingSettingsSave = _pendingSettingsSave
        .catchError((Object _) {})
        .then((_) => settingsStore.save(_buildSettingsSnapshot()));
    await _pendingSettingsSave;
  }

  void updateWindowSize(Size size) {
    _windowSize = Size(
      size.width < 980 ? 980 : size.width,
      size.height < 640 ? 640 : size.height,
    );
  }

  Future<void> addFilesFromDialog() async {
    final files = await openFiles(
      acceptedTypeGroups: const <XTypeGroup>[executableTypeGroup],
      initialDirectory: _defaultDirectory.isEmpty ? null : _defaultDirectory,
    );

    if (files.isEmpty) {
      return;
    }

    await addPaths(files.map((file) => file.path));
  }

  Future<void> scanFolder({required bool recursive}) async {
    final selectedDirectory = await getDirectoryPath(
      initialDirectory: _defaultDirectory.isEmpty ? null : _defaultDirectory,
      confirmButtonText: recursive ? 'Scan Recursively' : 'Scan Folder',
    );

    if (selectedDirectory == null || selectedDirectory.isEmpty) {
      return;
    }

    _defaultDirectory = selectedDirectory;
    _setBusy(
      BusyState.scanning,
      recursive
          ? 'Scanning folder recursively...'
          : 'Scanning folder... ',
    );
    notifyListeners();

    final result = await Isolate.run(
      () => _scanExecutablePaths(selectedDirectory, recursive),
    );
    final paths = (result['paths'] as List<Object?>).cast<String>();
    final scanErrors = result['scanErrors'] as int;

    await addPaths(paths, announce: false, showBusy: false);
    _clearBusy();

    _statusMessage = scanErrors == 0
        ? 'Scan complete. Added ${paths.length} executable candidate(s).'
        : 'Scan complete. Added ${paths.length} executable candidate(s); $scanErrors folder item(s) could not be read.';
    notifyListeners();
  }

  Future<void> handleDroppedPaths(Iterable<String> paths) async {
    final executablePaths = paths
        .where((path) => p.extension(path).toLowerCase() == '.exe')
        .toList(growable: false);

    if (executablePaths.isEmpty) {
      _statusMessage = 'Drop one or more .exe files to load them.';
      notifyListeners();
      return;
    }

    await addPaths(executablePaths);
  }

  Future<void> addPaths(
    Iterable<String> paths, {
    bool announce = true,
    bool showBusy = true,
  }) async {
    final pathList = paths.toList(growable: false);
    final manageBusy = showBusy && _busyState == BusyState.idle;

    if (manageBusy) {
      _setBusy(
        BusyState.scanning,
        _buildLoadStatusMessage(0, pathList.length),
        progress: pathList.isEmpty ? null : 0,
      );
      notifyListeners();
      await Future<void>.delayed(Duration.zero);
    } else if (_busyState == BusyState.scanning && pathList.isNotEmpty) {
      _busyProgress = 0;
      _statusMessage = _buildLoadStatusMessage(0, pathList.length);
      notifyListeners();
      await Future<void>.delayed(Duration.zero);
    }

    var added = 0;
    var duplicates = 0;
    var missing = 0;
    var invalid = 0;
    String? firstAdded;
    var processed = 0;

    for (final rawPath in pathList) {
      final normalizedPath = _normalizePath(rawPath);
      if (_indexOfPath(normalizedPath) != -1) {
        duplicates++;
      } else {
        final probe = await peFileService.inspect(normalizedPath);
        if (probe.state == ProbeState.missing) {
          missing++;
        } else {
          final entry = ExecutableEntry(
            path: normalizedPath,
            probeState: probe.state,
            currentLaa: probe.largeAddressAware,
            characteristics: probe.characteristics,
            has32BitMachineFlag: probe.has32BitMachineFlag,
            problem: probe.message,
          );

          if (!entry.isReady) {
            invalid++;
          }

          _entries.add(entry);
          added++;
          firstAdded ??= normalizedPath;
        }
      }

      processed++;
      if (_busyState == BusyState.scanning && pathList.isNotEmpty) {
        _busyProgress = processed / pathList.length;
        if (processed == pathList.length || processed % _loadProgressStride == 0) {
          _statusMessage = _buildLoadStatusMessage(processed, pathList.length);
          notifyListeners();
          await Future<void>.delayed(Duration.zero);
        }
      }
    }

    if (firstAdded != null) {
      _focusedPath = firstAdded;
    }

    _sortEntries();
    _syncSavedPathsToEntries();
    _scheduleSettingsSave();

    if (manageBusy) {
      _clearBusy();
    }

    if (!announce) {
      return;
    }

    if (added == 0) {
      _statusMessage = duplicates > 0
          ? 'Those executables are already loaded.'
          : 'No new executable files were added.';
    } else {
      _statusMessage = 'Added $added file(s)'
          '${duplicates > 0 ? '; skipped $duplicates duplicate(s)' : ''}'
          '${invalid > 0 ? '; $invalid invalid PE file(s)' : ''}'
          '${missing > 0 ? '; $missing missing path(s)' : ''}.';
    }

    notifyListeners();
  }

  void setFilter(WorkspaceFilter filter) {
    _filter = filter;
    notifyListeners();
  }

  void sortBy(EntrySortField field) {
    if (_sortField == field) {
      _sortAscending = !_sortAscending;
    } else {
      _sortField = field;
      _sortAscending = true;
    }

    _sortEntries();
    notifyListeners();
  }

  void focusEntry(String path) {
    _focusedPath = path;
    notifyListeners();
  }

  void toggleChecked(String path) {
    final entry = _entryForPath(path);
    if (entry == null) {
      return;
    }

    entry.isChecked = !entry.isChecked;
    notifyListeners();
  }

  void setCheckedForVisible(bool checked) {
    var changed = false;
    for (final entry in _entries) {
      if (!_matchesFilter(entry)) {
        continue;
      }

      entry.isChecked = checked;
      changed = true;
    }

    if (!changed) {
      return;
    }

    notifyListeners();
  }

  Future<void> applySelected(LaaAction action) async {
    final selectedEntries = _entries.where((entry) => entry.isChecked).toList();
    if (selectedEntries.isEmpty) {
      _statusMessage = 'Select one or more files first.';
      notifyListeners();
      return;
    }

    await _applyEntries(selectedEntries, action);
  }

  Future<void> applyFocused(LaaAction action) async {
    final entry = focusedEntry;
    if (entry == null) {
      _statusMessage = 'Select a file first.';
      notifyListeners();
      return;
    }

    await _applyEntries(<ExecutableEntry>[entry], action);
  }

  Future<void> _applyEntries(List<ExecutableEntry> entries, LaaAction action) async {
    final readyEntries = entries.where((entry) => entry.isReady).toList(growable: false);

    if (readyEntries.isEmpty) {
      _statusMessage = entries.length == 1
          ? entries.first.problem
          : 'No valid PE executables were available in the current selection.';
      notifyListeners();
      return;
    }

    _setBusy(BusyState.applying, 'Applying changes...', progress: 0);
    notifyListeners();

    var successCount = 0;
    var unchangedCount = 0;
    var failureCount = 0;
    for (var index = 0; index < readyEntries.length; index++) {
      final entry = readyEntries[index];
      final desiredValue = _desiredValueFor(action);

      if (desiredValue == entry.currentLaa) {
        entry.lastResult = desiredValue ? 'Already On' : 'Already Off';
        unchangedCount++;
        _busyProgress = (index + 1) / readyEntries.length;
        notifyListeners();
        continue;
      }

      final result = await peFileService.setLargeAddressAware(entry.path, desiredValue);

      if (result.success && result.probe != null) {
        _applyProbe(entry, result.probe!);
        entry.lastResult = 'Updated';
        successCount++;
      } else {
        entry.lastResult = result.message;
        failureCount++;
      }

      _busyProgress = (index + 1) / readyEntries.length;
      notifyListeners();
    }

    _clearBusy();
    _statusMessage = _buildApplyResultMessage(
      successCount: successCount,
      unchangedCount: unchangedCount,
      failureCount: failureCount,
    );
    notifyListeners();
  }

  bool _desiredValueFor(LaaAction action) {
    switch (action) {
      case LaaAction.enable:
        return true;
      case LaaAction.disable:
        return false;
    }
  }

  String _buildLoadStatusMessage(int processed, int total) {
    if (total == 0) {
      return 'Inspecting files...';
    }

    return 'Inspecting $processed of $total file(s)...';
  }

  String _buildApplyResultMessage({
    required int successCount,
    required int unchangedCount,
    required int failureCount,
  }) {
    if (successCount > 0) {
      var message = 'Updated $successCount file(s)';
      if (unchangedCount > 0) {
        message += '; $unchangedCount already matched';
      }
      if (failureCount > 0) {
        message += '; $failureCount failed';
      }
      return '$message.';
    }

    if (failureCount > 0 && unchangedCount == 0) {
      return '$failureCount file(s) failed.';
    }

    if (failureCount > 0) {
      return '$unchangedCount file(s) already matched the requested state; $failureCount failed.';
    }

    return '$unchangedCount file(s) already matched the requested state.';
  }

  void removeSelected() {
    final selectedEntries = _entries.where((entry) => entry.isChecked).toList();
    if (selectedEntries.isEmpty) {
      _statusMessage = 'Select one or more files first.';
      notifyListeners();
      return;
    }

    final selectedPaths = selectedEntries.map((entry) => entry.path).toSet();
    _entries.removeWhere((entry) => selectedPaths.contains(entry.path));
    _repairFocus();
    _syncSavedPathsToEntries();
    _scheduleSettingsSave();
    _statusMessage = _buildRemovalStatusMessage(selectedEntries.length);
    notifyListeners();
  }

  void removeAll() {
    if (_entries.isEmpty) {
      _statusMessage = 'The workspace is already empty.';
      notifyListeners();
      return;
    }

    final removedCount = _entries.length;
    _entries.clear();
    _focusedPath = null;
    _syncSavedPathsToEntries();
    _scheduleSettingsSave();
    _statusMessage = _buildRemovalStatusMessage(removedCount);
    notifyListeners();
  }

  Future<void> setLoadPreviousFiles(bool value) async {
    if (_loadPreviousFiles == value) {
      return;
    }

    _loadPreviousFiles = value;
    if (value) {
      await addPaths(_savedPaths, announce: false);
      _statusMessage = 'Load previous files is on.';
    } else {
      _statusMessage = 'Load previous files is off.';
    }

    _scheduleSettingsSave();
    notifyListeners();
  }

  String _buildRemovalStatusMessage(int removedCount) {
    return 'Removed $removedCount file(s) from the workspace.';
  }

  void _syncSavedPathsToEntries() {
    _savedPaths
      ..clear()
      ..addAll(_entries.map((entry) => entry.path));
  }

  AppSettings _buildSettingsSnapshot() {
    return AppSettings(
      windowSize: _windowSize,
      defaultDirectory: _defaultDirectory,
      loadPreviousFiles: _loadPreviousFiles,
      recentPaths: _savedPaths.toList(growable: false),
    );
  }

  void _scheduleSettingsSave() {
    unawaited(saveSettings());
  }

  String _normalizePath(String path) {
    try {
      return p.normalize(p.absolute(path));
    } catch (_) {
      return p.normalize(path);
    }
  }

  bool _matchesFilter(ExecutableEntry entry) {
    switch (_filter) {
      case WorkspaceFilter.all:
        return true;
      case WorkspaceFilter.selected:
        return entry.isChecked;
      case WorkspaceFilter.laa:
        return entry.isReady && entry.currentLaa == true;
      case WorkspaceFilter.nonLaa:
        return entry.isReady && entry.currentLaa == false;
      case WorkspaceFilter.invalid:
        return !entry.isReady;
    }
  }

  ExecutableEntry? _entryForPath(String path) {
    for (final entry in _entries) {
      if (entry.path == path) {
        return entry;
      }
    }

    return null;
  }

  int _indexOfPath(String path) {
    for (var index = 0; index < _entries.length; index++) {
      if (_entries[index].path == path) {
        return index;
      }
    }

    return -1;
  }

  void _applyProbe(ExecutableEntry entry, PeProbeResult probe) {
    entry.probeState = probe.state;
    entry.currentLaa = probe.largeAddressAware;
    entry.characteristics = probe.characteristics;
    entry.has32BitMachineFlag = probe.has32BitMachineFlag;
    entry.problem = probe.message;
  }

  void _sortEntries() {
    _entries.sort((left, right) {
      final comparison = switch (_sortField) {
        EntrySortField.path => left.path.toLowerCase().compareTo(right.path.toLowerCase()),
        EntrySortField.current => _compareNullableBool(left.currentLaa, right.currentLaa),
        EntrySortField.result => left.statusLabel.toLowerCase().compareTo(
              right.statusLabel.toLowerCase(),
            ),
      };

      return _sortAscending ? comparison : -comparison;
    });
  }

  int _compareNullableBool(bool? left, bool? right) {
    final leftValue = left == null ? -1 : (left ? 1 : 0);
    final rightValue = right == null ? -1 : (right ? 1 : 0);
    return leftValue.compareTo(rightValue);
  }

  void _repairFocus() {
    if (_focusedPath == null) {
      _focusedPath = _entries.isEmpty ? null : _entries.first.path;
      return;
    }

    if (_entries.every((entry) => entry.path != _focusedPath)) {
      _focusedPath = _entries.isEmpty ? null : _entries.first.path;
    }
  }

  void _setBusy(BusyState state, String message, {double? progress}) {
    _busyState = state;
    _busyProgress = progress;
    _statusMessage = message;
  }

  void _clearBusy() {
    _busyState = BusyState.idle;
    _busyProgress = null;
  }
}

Future<Map<String, Object>> _scanExecutablePaths(
  String selectedDirectory,
  bool recursive,
) async {
  final paths = <String>[];
  var scanErrors = 0;

  final stream = Directory(selectedDirectory)
      .list(recursive: recursive, followLinks: false)
      .handleError(
    (Object error) {
      scanErrors++;
    },
    test: (dynamic error) => true,
  );

  await for (final entity in stream) {
    if (entity is File && p.extension(entity.path).toLowerCase() == '.exe') {
      paths.add(entity.path);
    }
  }

  return <String, Object>{
    'paths': paths,
    'scanErrors': scanErrors,
  };
}