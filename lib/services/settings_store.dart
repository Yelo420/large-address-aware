import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:path/path.dart' as p;

class AppSettings {
  const AppSettings({
    required this.windowSize,
    required this.defaultDirectory,
    required this.loadPreviousFiles,
    required this.recentPaths,
  });

  factory AppSettings.defaults() {
    return const AppSettings(
      windowSize: Size(1280, 760),
      defaultDirectory: '',
      loadPreviousFiles: true,
      recentPaths: <String>[],
    );
  }

  final Size windowSize;
  final String defaultDirectory;
  final bool loadPreviousFiles;
  final List<String> recentPaths;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'windowWidth': windowSize.width,
      'windowHeight': windowSize.height,
      'defaultDirectory': defaultDirectory,
      'loadPreviousFiles': loadPreviousFiles,
      'recentPaths': recentPaths,
    };
  }
}

class SettingsStore {
  SettingsStore({String? settingsPath})
      : settingsPath = settingsPath ??
            p.join(_resolveSettingsDirectory(), 'settings.json');

  final String settingsPath;

  Future<AppSettings> load() async {
    final file = File(settingsPath);
    if (!await file.exists()) {
      return AppSettings.defaults();
    }

    try {
      final raw = await file.readAsString();
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object.');
      }

      final recentPaths = <String>[];
      final recentPathsJson = json['recentPaths'];
      if (recentPathsJson is List) {
        for (final path in recentPathsJson) {
          if (path is String && path.isNotEmpty) {
            recentPaths.add(path);
          }
        }
      } else {
        final originalsJson = json['rememberedOriginals'];
        if (originalsJson is Map) {
          for (final entry in originalsJson.entries) {
            if (entry.key is String && (entry.key as String).isNotEmpty) {
              recentPaths.add(entry.key as String);
            }
          }
        }
      }

      final width = (json['windowWidth'] as num?)?.toDouble() ?? 1280;
      final height = (json['windowHeight'] as num?)?.toDouble() ?? 760;

      return AppSettings(
        windowSize: Size(
          width < 980 ? 980 : width,
          height < 640 ? 640 : height,
        ),
        defaultDirectory: json['defaultDirectory'] as String? ?? '',
        loadPreviousFiles: json['loadPreviousFiles'] as bool? ?? true,
        recentPaths: recentPaths,
      );
    } catch (_) {
      return AppSettings.defaults();
    }
  }

  Future<void> save(AppSettings settings) async {
    final file = File(settingsPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(settings.toJson()),
      flush: true,
    );
  }

  static String _resolveSettingsDirectory() {
    final appData = Platform.environment['APPDATA'];
    if (appData != null && appData.isNotEmpty) {
      return p.join(appData, 'laa');
    }

    return File(Platform.resolvedExecutable).parent.path;
  }
}