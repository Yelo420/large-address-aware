import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'controllers/workspace_controller.dart';
import 'ui/workspace_screen.dart';

class LaaApp extends StatefulWidget {
  const LaaApp({
    super.key,
    required this.controller,
    this.enableWindowManagement = true,
  });

  final WorkspaceController controller;
  final bool enableWindowManagement;

  @override
  State<LaaApp> createState() => _LaaAppState();
}

class _LaaAppState extends State<LaaApp> with WindowListener {
  @override
  void initState() {
    super.initState();
    if (widget.enableWindowManagement) {
      windowManager.addListener(this);
      unawaited(_configureWindow());
    }
  }

  Future<void> _configureWindow() async {
    await windowManager.waitUntilReadyToShow(
      WindowOptions(
        title: 'Large Address Aware',
        size: widget.controller.windowSize,
        center: true,
        backgroundColor: const Color(0xFFF6F4ED),
      ),
      () async {
        await windowManager.setTitle('Large Address Aware');
        await windowManager.setMinimumSize(const Size(980, 640));
        await windowManager.setPreventClose(true);
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }

  @override
  void dispose() {
    if (widget.enableWindowManagement) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowClose() {
    if (!widget.enableWindowManagement) {
      return;
    }

    unawaited(_closeWindow());
  }

  Future<void> _closeWindow() async {
    await widget.controller.saveSettings();
    await windowManager.destroy();
  }

  @override
  void onWindowResized() {
    if (!widget.enableWindowManagement) {
      return;
    }

    unawaited(_rememberWindowSize());
  }

  Future<void> _rememberWindowSize() async {
    final size = await windowManager.getSize();
    widget.controller.updateWindowSize(size);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Large Address Aware',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Segoe UI',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F4ED),
      ),
      home: LaaWorkspaceScreen(controller: widget.controller),
    );
  }
}
