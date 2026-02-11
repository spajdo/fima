import 'package:fima/domain/entity/user_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Hidden Files Settings Tests', () {
    test('default settings should have showHiddenFiles as false', () {
      final defaultSettings = UserSettings.defaultSettings();
      expect(defaultSettings.showHiddenFiles, false);
    });

    test('copyWith should preserve showHiddenFiles when not specified', () {
      final settings = UserSettings.defaultSettings();
      final updated = settings.copyWith(leftPanelPath: '/new/path');
      expect(updated.showHiddenFiles, false);
    });

    test('copyWith should update showHiddenFiles when specified', () {
      final settings = UserSettings.defaultSettings();
      final updated = settings.copyWith(showHiddenFiles: true);
      expect(updated.showHiddenFiles, true);
    });

    test('fromJson should handle showHiddenFiles field', () {
      final json = {
        'leftPanelPath': '/test',
        'rightPanelPath': '/test2',
        'panelSplitRatio': 0.6,
        'fontSize': 16.0,
        'showHiddenFiles': true,
      };

      final settings = UserSettings.fromJson(json);
      expect(settings.showHiddenFiles, true);
    });

    test('fromJson should default showHiddenFiles to false when missing', () {
      final json = {
        'leftPanelPath': '/test',
        'rightPanelPath': '/test2',
        'panelSplitRatio': 0.6,
        'fontSize': 16.0,
      };

      final settings = UserSettings.fromJson(json);
      expect(settings.showHiddenFiles, false);
    });

    test('toJson should include showHiddenFiles', () {
      final settings = UserSettings.defaultSettings().copyWith(
        showHiddenFiles: true,
      );
      final json = settings.toJson();

      expect(json['showHiddenFiles'], true);
    });

    test('fromJson and toJson should be consistent', () {
      final original = UserSettings.defaultSettings().copyWith(
        showHiddenFiles: true,
        leftPanelPath: '/test/path',
      );

      final json = original.toJson();
      final recreated = UserSettings.fromJson(json);

      expect(recreated.showHiddenFiles, original.showHiddenFiles);
      expect(recreated.leftPanelPath, original.leftPanelPath);
    });
  });
}
