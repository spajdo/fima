import 'dart:convert';
import 'dart:io';
import 'package:fima/domain/entity/user_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class SettingsService {
  static const String _settingsFileName = 'settings.json';
  String? _settingsPath;

  /// Get the path to the settings file
  Future<String> getSettingsPath() async {
    if (_settingsPath != null) {
      return _settingsPath!;
    }

    try {
      final directory = await getApplicationSupportDirectory();
      _settingsPath = p.join(directory.path, _settingsFileName);
      return _settingsPath!;
    } catch (e) {
      debugPrint('Error getting settings path: $e');
      rethrow;
    }
  }

  /// Load settings from file, or return defaults if file doesn't exist
  Future<UserSettings> load() async {
    try {
      final path = await getSettingsPath();
      final file = File(path);

      if (!await file.exists()) {
        debugPrint('Settings file not found, using defaults');
        return UserSettings.defaultSettings();
      }

      final contents = await file.readAsString();
      final json = jsonDecode(contents) as Map<String, dynamic>;
      debugPrint('Settings loaded from $path');
      return UserSettings.fromJson(json);
    } catch (e) {
      debugPrint('Error loading settings: $e, using defaults');
      return UserSettings.defaultSettings();
    }
  }

  /// Save settings to file
  Future<void> save(UserSettings settings) async {
    try {
      final path = await getSettingsPath();
      final file = File(path);

      // Create directory if it doesn't exist
      final directory = file.parent;
      if (!await directory.exists()) {
        await directory.create(recursive: true);
        debugPrint('Created settings directory: ${directory.path}');
      }

      // Write settings to file
      final json = settings.toJson();
      final contents = const JsonEncoder.withIndent('  ').convert(json);
      await file.writeAsString(contents);
      debugPrint('Settings saved to $path');
    } catch (e) {
      debugPrint('Error saving settings: $e');
      // Don't rethrow - we don't want to crash the app if settings can't be saved
    }
  }

  /// Delete settings file (useful for testing or reset)
  Future<void> delete() async {
    try {
      final path = await getSettingsPath();
      final file = File(path);
      
      if (await file.exists()) {
        await file.delete();
        debugPrint('Settings file deleted: $path');
      }
    } catch (e) {
      debugPrint('Error deleting settings: $e');
    }
  }
}
