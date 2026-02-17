import 'dart:convert';
import 'dart:io';

import 'package:fima/domain/entity/app_theme.dart';
import 'package:fima/domain/entity/default_themes.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ThemeService {
  static const String _themesFolderName = 'themes';
  static const String _themeFileExtension = '.theme';
  String? _themesPath;

  Future<String> getThemesPath() async {
    if (_themesPath != null) {
      return _themesPath!;
    }

    try {
      final directory = await getApplicationSupportDirectory();
      _themesPath = p.join(directory.path, _themesFolderName);
      return _themesPath!;
    } catch (e) {
      debugPrint('Error getting themes path: $e');
      rethrow;
    }
  }

  Future<List<FimaTheme>> loadThemes() async {
    final themes = <FimaTheme>[];

    try {
      final path = await getThemesPath();
      final themesDir = Directory(path);

      if (!await themesDir.exists()) {
        await themesDir.create(recursive: true);
        debugPrint('Created themes directory: $path');
        await _createDefaultThemeFiles(themesDir);
      }

      final files = await themesDir
          .list()
          .where(
            (entity) =>
                entity is File &&
                entity.path.toLowerCase().endsWith(_themeFileExtension),
          )
          .toList();

      if (files.isEmpty) {
        debugPrint('No theme files found, creating default theme');
        await _createDefaultThemeFiles(themesDir);
        final createdFiles = await themesDir
            .list()
            .where((entity) => entity is File)
            .toList();
        for (final fileEntity in createdFiles) {
          final file = fileEntity as File;
          try {
            final content = await file.readAsString();
            final json = jsonDecode(content) as Map<String, dynamic>;
            themes.add(FimaTheme.fromFimaThemeJson(json));
          } catch (e) {
            debugPrint('Error parsing theme file ${file.path}: $e');
          }
        }
      } else {
        for (final entity in files) {
          final file = entity as File;
          try {
            final content = await file.readAsString();
            final json = jsonDecode(content) as Map<String, dynamic>;
            themes.add(FimaTheme.fromFimaThemeJson(json));
          } catch (e) {
            debugPrint('Error parsing theme file ${file.path}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading themes: $e');
      return DefaultThemes.all;
    }

    if (themes.isEmpty) {
      debugPrint('No themes loaded, using defaults');
      return DefaultThemes.all;
    }

    return themes;
  }

  Future<void> _createDefaultThemeFiles(Directory themesDir) async {
    for (final theme in DefaultThemes.all) {
      final fileName = '${theme.name.toLowerCase()}.theme';
      final filePath = p.join(themesDir.path, fileName);
      final file = File(filePath);

      if (!await file.exists()) {
        final jsonContent = theme.toJsonString();
        await file.writeAsString(jsonContent);
        debugPrint('Created default theme file: $filePath');
      }
    }
  }

  Future<FimaTheme?> loadThemeByName(String name) async {
    final themes = await loadThemes();
    try {
      return themes.firstWhere((t) => t.name == name);
    } catch (e) {
      debugPrint('Theme $name not found, returning null');
      return null;
    }
  }

  Future<void> saveTheme(FimaTheme theme) async {
    try {
      final path = await getThemesPath();
      final themesDir = Directory(path);

      if (!await themesDir.exists()) {
        await themesDir.create(recursive: true);
      }

      final fileName = '${theme.name.toLowerCase()}.theme';
      final filePath = p.join(themesDir.path, fileName);
      final file = File(filePath);

      final jsonContent = theme.toJsonString();
      await file.writeAsString(jsonContent);
      debugPrint('Saved theme: $filePath');
    } catch (e) {
      debugPrint('Error saving theme: $e');
    }
  }

  Future<List<String>> getThemeNames() async {
    final themes = await loadThemes();
    return themes.map((t) => t.name).toList();
  }
}
