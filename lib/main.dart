import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'controllers/workspace_controller.dart';
import 'services/pe_file_service.dart';
import 'services/settings_store.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  final controller = WorkspaceController(
    peFileService: PeFileService(),
    settingsStore: SettingsStore(),
  );
  await controller.initialize(args);

  runApp(LaaApp(controller: controller));
}
