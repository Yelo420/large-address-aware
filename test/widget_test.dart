import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:laa/app.dart';
import 'package:laa/controllers/workspace_controller.dart';
import 'package:laa/services/pe_file_service.dart';
import 'package:laa/services/settings_store.dart';

void main() {
  testWidgets('shows the empty workspace state at desktop minimum size', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(980, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = WorkspaceController(
      peFileService: PeFileService(),
      settingsStore: SettingsStore(settingsPath: 'memory://settings.json'),
    );

    await tester.pumpWidget(
      LaaApp(
        controller: controller,
        enableWindowManagement: false,
      ),
    );

    await tester.pump();

    expect(find.text('Add Files'), findsOneWidget);
    expect(find.text('Workspace'), findsOneWidget);
    expect(find.text('Add files or drop .exe files here to begin.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('load previous files chip keeps the same size when toggled', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(980, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = WorkspaceController(
      peFileService: PeFileService(),
      settingsStore: SettingsStore(settingsPath: 'memory://settings.json'),
    );

    await tester.pumpWidget(
      LaaApp(
        controller: controller,
        enableWindowManagement: false,
      ),
    );
    await tester.pumpAndSettle();

    final chipFinder = find.widgetWithText(FilterChip, 'Load Previous Files');
    final initialSize = tester.getSize(chipFinder);

    await tester.tap(chipFinder);
    await tester.pumpAndSettle();

    final toggledSize = tester.getSize(chipFinder);

    expect(toggledSize.width, initialSize.width);
    expect(toggledSize.height, initialSize.height);
    expect(tester.takeException(), isNull);
  });
}
