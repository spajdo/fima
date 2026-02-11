import 'package:fima/domain/entity/user_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Window Settings Tests', () {
    test('default settings should have window properties', () {
      final defaultSettings = UserSettings.defaultSettings();

      expect(defaultSettings.windowWidth, 1280.0);
      expect(defaultSettings.windowHeight, 720.0);
      expect(defaultSettings.windowX, null);
      expect(defaultSettings.windowY, null);
      expect(defaultSettings.windowMaximized, false);
    });

    test('copyWith should update window properties when specified', () {
      final settings = UserSettings.defaultSettings();
      final updated = settings.copyWith(
        windowWidth: 1920.0,
        windowHeight: 1080.0,
        windowX: 100.0,
        windowY: 200.0,
        windowMaximized: true,
      );

      expect(updated.windowWidth, 1920.0);
      expect(updated.windowHeight, 1080.0);
      expect(updated.windowX, 100.0);
      expect(updated.windowY, 200.0);
      expect(updated.windowMaximized, true);
    });

    test('copyWith should preserve window properties when not specified', () {
      final settings = UserSettings.defaultSettings();
      final updated = settings.copyWith(leftPanelPath: '/new/path');

      expect(updated.windowWidth, 1280.0);
      expect(updated.windowHeight, 720.0);
      expect(updated.windowX, null);
      expect(updated.windowY, null);
      expect(updated.windowMaximized, false);
    });

    test('fromJson should handle window properties', () {
      final json = {
        'leftPanelPath': '/test',
        'rightPanelPath': '/test2',
        'panelSplitRatio': 0.6,
        'fontSize': 16.0,
        'showHiddenFiles': true,
        'windowWidth': 1920.0,
        'windowHeight': 1080.0,
        'windowX': 100.0,
        'windowY': 200.0,
        'windowMaximized': true,
      };

      final settings = UserSettings.fromJson(json);

      expect(settings.windowWidth, 1920.0);
      expect(settings.windowHeight, 1080.0);
      expect(settings.windowX, 100.0);
      expect(settings.windowY, 200.0);
      expect(settings.windowMaximized, true);
    });

    test('fromJson should default window properties when missing', () {
      final json = {
        'leftPanelPath': '/test',
        'rightPanelPath': '/test2',
        'panelSplitRatio': 0.6,
        'fontSize': 16.0,
      };

      final settings = UserSettings.fromJson(json);

      expect(settings.windowWidth, null);
      expect(settings.windowHeight, null);
      expect(settings.windowX, null);
      expect(settings.windowY, null);
      expect(settings.windowMaximized, false);
    });

    test('toJson should include window properties', () {
      final settings = UserSettings.defaultSettings().copyWith(
        windowWidth: 1920.0,
        windowHeight: 1080.0,
        windowX: 100.0,
        windowY: 200.0,
        windowMaximized: true,
      );

      final json = settings.toJson();

      expect(json['windowWidth'], 1920.0);
      expect(json['windowHeight'], 1080.0);
      expect(json['windowX'], 100.0);
      expect(json['windowY'], 200.0);
      expect(json['windowMaximized'], true);
    });

    test('fromJson and toJson should be consistent for window properties', () {
      final original = UserSettings.defaultSettings().copyWith(
        windowWidth: 1366.0,
        windowHeight: 768.0,
        windowX: 50.0,
        windowY: 100.0,
        windowMaximized: false,
        showHiddenFiles: true,
      );

      final json = original.toJson();
      final recreated = UserSettings.fromJson(json);

      expect(recreated.windowWidth, original.windowWidth);
      expect(recreated.windowHeight, original.windowHeight);
      expect(recreated.windowX, original.windowX);
      expect(recreated.windowY, original.windowY);
      expect(recreated.windowMaximized, original.windowMaximized);
      expect(recreated.showHiddenFiles, original.showHiddenFiles);
    });
  });
}
