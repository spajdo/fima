import 'dart:io';
import 'package:fima/domain/entity/desktop_application.dart';
import 'package:flutter/foundation.dart';

class LinuxApplicationService {
  List<DesktopApplication> getInstalledApplications() {
    final apps = <DesktopApplication>[];

    final home = Platform.environment['HOME'];
    final paths = [
      '/usr/share/applications',
      if (home != null) '$home/.local/share/applications',
      '/var/lib/snapd/desktop/applications',
      '/var/lib/flatpak/exports/share/applications',
    ];

    for (final path in paths) {
      final dir = Directory(path);
      if (!dir.existsSync()) continue;

      try {
        final files = dir.listSync().where((e) => e.path.endsWith('.desktop'));

        for (final file in files) {
          if (file is File) {
            final app = _parseDesktopFile(file);
            if (app != null) {
              apps.add(app);
            }
          }
        }
      } catch (e) {
        debugPrint('Error reading directory $path: $e');
      }
    }

    if (apps.isEmpty) {
      _addFallbackApps(apps);
    }

    final uniqueApps = <String, DesktopApplication>{};
    for (var app in apps) {
      uniqueApps.putIfAbsent(app.name, () => app);
    }

    final sortedApps = uniqueApps.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return sortedApps;
  }

  void _addFallbackApps(List<DesktopApplication> apps) {
    final home = Platform.environment['HOME'] ?? '';
    final commonApps = [
      ('Code', 'code', '$home/.vscode/'),
      ('Files', 'nautilus', ''),
      ('Terminal', 'gnome-terminal', ''),
      ('Text Editor', 'gedit', ''),
    ];

    for (final (name, exec, icon) in commonApps) {
      apps.add(
        DesktopApplication(name: name, exec: exec, icon: icon, path: ''),
      );
    }
  }

  DesktopApplication? _parseDesktopFile(File file) {
    try {
      final lines = file.readAsLinesSync();
      String? name;
      String? exec;
      String? icon;
      bool isHidden = false;

      for (final line in lines) {
        if (line.startsWith('Name=')) {
          name ??= line.substring(5);
        } else if (line.startsWith('Exec=')) {
          exec ??= line.substring(5);
        } else if (line.startsWith('Icon=')) {
          icon ??= line.substring(5);
        } else if (line.startsWith('NoDisplay=true')) {
          isHidden = true;
        }
      }

      if (name != null && exec != null && !isHidden) {
        return DesktopApplication(
          name: name,
          exec: exec,
          icon: icon ?? '',
          path: file.path,
        );
      }
    } catch (e) {
      debugPrint('Error parsing desktop file: $e');
    }
    return null;
  }
}
