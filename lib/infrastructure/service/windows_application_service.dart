import 'dart:io';

import 'package:fima/domain/entity/desktop_application.dart';
import 'package:fima/infrastructure/service/application_service.dart';
import 'package:flutter/foundation.dart';

class WindowsApplicationService implements ApplicationService {
  @override
  List<DesktopApplication> getInstalledApplications() {
    final apps = <DesktopApplication>[];

    final programData = Platform.environment['ProgramData'];
    final appData = Platform.environment['APPDATA'];

    final startMenuPaths = [
      if (programData != null)
        '$programData\\Microsoft\\Windows\\Start Menu\\Programs',
      if (appData != null)
        '$appData\\Microsoft\\Windows\\Start Menu\\Programs',
    ];

    for (final menuPath in startMenuPaths) {
      if (!Directory(menuPath).existsSync()) continue;
      try {
        final discovered = _resolveLnkFiles(menuPath);
        apps.addAll(discovered);
      } catch (e) {
        debugPrint('Error scanning Start Menu at $menuPath: $e');
      }
    }

    final uniqueApps = <String, DesktopApplication>{};
    for (final app in apps) {
      if (app.exec.isNotEmpty) {
        uniqueApps.putIfAbsent(app.name, () => app);
      }
    }

    return uniqueApps.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  List<DesktopApplication> _resolveLnkFiles(String folder) {
    final script = r'''
$shell = New-Object -ComObject WScript.Shell
Get-ChildItem -Path "''' +
        folder +
        r'''" -Recurse -Filter *.lnk | ForEach-Object {
  try {
    $sc = $shell.CreateShortcut($_.FullName)
    $target = $sc.TargetPath
    if ($target -and $target.EndsWith('.exe') -and (Test-Path $target)) {
      Write-Output "$($_.BaseName)|$target"
    }
  } catch {}
}
''';

    final result = Process.runSync('powershell', [
      '-ExecutionPolicy',
      'Bypass',
      '-NoProfile',
      '-Command',
      script,
    ]);

    if (result.exitCode != 0) {
      debugPrint('PowerShell error: ${result.stderr}');
      return [];
    }

    final apps = <DesktopApplication>[];
    final lines = (result.stdout as String).split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final parts = trimmed.split('|');
      if (parts.length < 2) continue;
      final name = parts[0].trim();
      final exec = parts.sublist(1).join('|').trim();
      if (name.isEmpty || exec.isEmpty) continue;
      apps.add(
        DesktopApplication(name: name, exec: exec, icon: '', path: exec),
      );
    }
    return apps;
  }
}
