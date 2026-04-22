import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:laa/controllers/workspace_controller.dart';
import 'package:laa/services/pe_file_service.dart';
import 'package:laa/services/settings_store.dart';

void main() {
  test('workspace changes autosave the previous-file snapshot', () async {
    final tempDirectory = await Directory.systemTemp.createTemp('laa-autosave-');
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final firstFile = await _createTestExecutable(tempDirectory.path, 'first.exe');
    final secondFile = await _createTestExecutable(tempDirectory.path, 'second.exe');
    final thirdFile = await _createTestExecutable(tempDirectory.path, 'third.exe');
    final settingsStore = _RecordingSettingsStore();
    final controller = WorkspaceController(
      peFileService: PeFileService(),
      settingsStore: settingsStore,
    );

    await controller.addPaths(
      <String>[firstFile.path, secondFile.path],
      announce: false,
      showBusy: false,
    );
    await settingsStore.waitForSaveCount(1);
    expect(
      settingsStore.saved.last.recentPaths.map(p.basename).toSet(),
      equals(<String>{'first.exe', 'second.exe'}),
    );

    controller.toggleChecked(firstFile.path);
    controller.removeSelected();
    await settingsStore.waitForSaveCount(2);
    expect(
      settingsStore.saved.last.recentPaths.map(p.basename).toSet(),
      equals(<String>{'second.exe'}),
    );

    await controller.addPaths(
      <String>[thirdFile.path],
      announce: false,
      showBusy: false,
    );
    await settingsStore.waitForSaveCount(3);
    expect(
      settingsStore.saved.last.recentPaths.map(p.basename).toSet(),
      equals(<String>{'second.exe', 'third.exe'}),
    );
  });

  test('load previous files follows the current workspace snapshot', () async {
    final tempDirectory = await Directory.systemTemp.createTemp('laa-controller-');
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final firstFile = await _createTestExecutable(tempDirectory.path, 'first.exe');
    final secondFile = await _createTestExecutable(tempDirectory.path, 'second.exe');
    final thirdFile = await _createTestExecutable(tempDirectory.path, 'third.exe');
    final settingsPath = p.join(tempDirectory.path, 'settings.json');

    final controller = WorkspaceController(
      peFileService: PeFileService(),
      settingsStore: SettingsStore(settingsPath: settingsPath),
    );

    await controller.addPaths(
      <String>[firstFile.path, secondFile.path],
      announce: false,
      showBusy: false,
    );
    controller.toggleChecked(firstFile.path);
    controller.removeSelected();

    await controller.setLoadPreviousFiles(false);
    await controller.addPaths(
      <String>[thirdFile.path],
      announce: false,
      showBusy: false,
    );
    await controller.setLoadPreviousFiles(true);

    expect(
      controller.allEntries.map((entry) => p.basename(entry.path)).toSet(),
      equals(<String>{'second.exe', 'third.exe'}),
    );

    await controller.saveSettings();

    final reloadedController = WorkspaceController(
      peFileService: PeFileService(),
      settingsStore: SettingsStore(settingsPath: settingsPath),
    );

    await reloadedController.initialize(const <String>[]);

    expect(
      reloadedController.allEntries.map((entry) => p.basename(entry.path)).toSet(),
      equals(<String>{'second.exe', 'third.exe'}),
    );

    await reloadedController.saveSettings();
  });
}

Future<File> _createTestExecutable(String directoryPath, String name) async {
  final file = File(p.join(directoryPath, name));
  final bytes = Uint8List(128);
  final data = ByteData.sublistView(bytes);

  bytes[0] = 0x4D;
  bytes[1] = 0x5A;
  data.setUint32(60, 64, Endian.little);
  bytes[64] = 0x50;
  bytes[65] = 0x45;
  data.setUint16(86, PeFileService.imageFile32BitMachine, Endian.little);

  await file.writeAsBytes(bytes, flush: true);
  return file;
}

class _RecordingSettingsStore extends SettingsStore {
  _RecordingSettingsStore() : super(settingsPath: 'memory://settings.json');

  final List<AppSettings> saved = <AppSettings>[];
  final List<_SaveCountWaiter> _waiters = <_SaveCountWaiter>[];

  @override
  Future<AppSettings> load() async {
    return AppSettings.defaults();
  }

  @override
  Future<void> save(AppSettings settings) async {
    saved.add(settings);

    for (final waiter in _waiters.toList(growable: false)) {
      if (saved.length < waiter.count || waiter.completer.isCompleted) {
        continue;
      }

      waiter.completer.complete();
      _waiters.remove(waiter);
    }
  }

  Future<void> waitForSaveCount(int count) {
    if (saved.length >= count) {
      return Future<void>.value();
    }

    final completer = Completer<void>();
    _waiters.add(_SaveCountWaiter(count, completer));
    return completer.future;
  }
}

class _SaveCountWaiter {
  const _SaveCountWaiter(this.count, this.completer);

  final int count;
  final Completer<void> completer;
}