import 'dart:io';

import 'package:fima/domain/entity/desktop_application.dart';
import 'package:fima/infrastructure/service/application_service.dart';
import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';

class MacosApplicationService implements ApplicationService {
  @override
  List<DesktopApplication> getInstalledApplications() {
    final apps = <DesktopApplication>[];
    final home = Platform.environment['HOME'];

    final searchPaths = [
      '/Applications',
      '/System/Applications',
      if (home != null) '$home/Applications',
    ];

    for (final searchPath in searchPaths) {
      final dir = Directory(searchPath);
      if (!dir.existsSync()) continue;

      try {
        final entries = dir.listSync();
        for (final entry in entries) {
          if (entry is Directory && entry.path.endsWith('.app')) {
            final app = _parseAppBundle(entry);
            if (app != null) apps.add(app);
          }
        }
      } catch (e) {
        debugPrint('Error scanning $searchPath: $e');
      }
    }

    final uniqueApps = <String, DesktopApplication>{};
    for (final app in apps) {
      uniqueApps.putIfAbsent(app.name, () => app);
    }

    return uniqueApps.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  DesktopApplication? _parseAppBundle(Directory appDir) {
    try {
      final plistFile = File('${appDir.path}/Contents/Info.plist');
      if (!plistFile.existsSync()) return null;

      String? xmlContent;

      // Try reading as XML first; if it fails, convert binary plist to XML
      try {
        final raw = plistFile.readAsStringSync();
        if (raw.trimLeft().startsWith('<?xml') ||
            raw.trimLeft().startsWith('<!DOCTYPE')) {
          xmlContent = raw;
        }
      } catch (_) {}

      if (xmlContent == null) {
        final result = Process.runSync('plutil', [
          '-convert',
          'xml1',
          '-o',
          '-',
          plistFile.path,
        ]);
      if (result.exitCode != 0) return null;
        xmlContent = result.stdout as String;
      }

      final name = _extractPlistValue(xmlContent, 'CFBundleDisplayName') ??
          _extractPlistValue(xmlContent, 'CFBundleName');

      if (name == null || name.isEmpty) return null;

      final iconFileName = _extractPlistValue(xmlContent, 'CFBundleIconFile');
      String iconPath = '';
      if (iconFileName != null && iconFileName.isNotEmpty) {
        final withExt = iconFileName.endsWith('.icns')
            ? iconFileName
            : '$iconFileName.icns';
        final candidate = '${appDir.path}/Contents/Resources/$withExt';
        if (File(candidate).existsSync()) iconPath = candidate;
      }

      return DesktopApplication(
        name: name,
        exec: appDir.path, // Full bundle path for `open -a <path> <file>`
        icon: iconPath,
        path: appDir.path,
      );
    } catch (e) {
      debugPrint('Error parsing app bundle ${appDir.path}: $e');
      return null;
    }
  }

  String? _extractPlistValue(String xmlContent, String key) {
    try {
      final document = XmlDocument.parse(xmlContent);
      final keys = document.findAllElements('key');
      for (final keyEl in keys) {
        if (keyEl.innerText == key) {
          final next = keyEl.nextElementSibling;
          if (next != null) return next.innerText;
        }
      }
    } catch (e) {
      debugPrint('Error parsing plist XML: $e');
    }
    return null;
  }
}
