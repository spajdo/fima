import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fima/domain/entity/app_theme.dart';
import 'package:fima/domain/entity/default_themes.dart';
import 'package:fima/domain/entity/file_operation.dart';
import 'package:fima/domain/entity/file_system_item.dart';
import 'package:fima/domain/entity/user_settings.dart';
import 'package:fima/domain/repository/file_system_repository.dart';
import 'package:fima/infrastructure/service/settings_service.dart';
import 'package:fima/infrastructure/service/theme_service.dart';
import 'package:fima/presentation/providers/file_system_provider.dart';
import 'package:fima/presentation/providers/panel_tabs_provider.dart';
import 'package:fima/presentation/providers/settings_provider.dart';
import 'package:fima/presentation/providers/theme_provider.dart';
import 'package:fima/presentation/widgets/keyboard_handler.dart';
import 'package:fima/presentation/widgets/popups/settings_dialog.dart';

class _InMemorySettingsService extends SettingsService {
  UserSettings stored;

  _InMemorySettingsService([UserSettings? initial])
    : stored = initial ?? UserSettings.defaultSettings();

  @override
  Future<UserSettings> load() async => stored;

  @override
  Future<void> save(UserSettings settings) async {
    stored = settings;
  }
}

class _InMemoryThemeService extends ThemeService {
  @override
  Future<List<FimaTheme>> loadThemes() async => [DefaultThemes.light];

  @override
  Future<FimaTheme?> loadThemeByName(String name) async => DefaultThemes.light;
}

class _FakeFileSystemRepository implements FileSystemRepository {
  final List<FileSystemItem> fakeItems;

  _FakeFileSystemRepository(this.fakeItems);

  @override
  Future<List<FileSystemItem>> getItems(
    String path, {
    bool showHiddenFiles = false,
  }) async => fakeItems;

  @override
  Future<String> getHomeDirectory() async => '/home';

  @override
  Future<void> deleteItem(String path) async {}

  @override
  Future<void> createDirectory(String path) async {}

  @override
  Future<void> createFile(String path) async {}

  @override
  Future<void> renameItem(String oldPath, String newPath) async {}

  @override
  Future<void> copyItem(String sourcePath, String destinationPath) async {}

  @override
  Future<void> moveItem(String sourcePath, String destinationPath) async {}

  @override
  Future<void> moveToTrash(String path) async {}

  @override
  Stream<OperationStatus> copyItems(
    List<String> sourcePaths,
    String destinationPath,
    CancellationToken token,
  ) => const Stream.empty();

  @override
  Stream<OperationStatus> moveItems(
    List<String> sourcePaths,
    String destinationPath,
    CancellationToken token,
  ) => const Stream.empty();
}

List<FileSystemItem> _buildSampleItems(int count) {
  final modified = DateTime(2026, 1, 1);
  return [
    for (int i = 0; i < count; i++)
      FileSystemItem(
        path: '/test/item_$i.txt',
        name: 'item_$i.txt',
        size: 100,
        modified: modified,
        isDirectory: false,
      ),
  ];
}

void main() {
  group('UserSettings key repeat persistence', () {
    test('defaults to system key repeat enabled and valid custom bounds', () {
      final defaults = UserSettings.defaultSettings();
      expect(defaults.useSystemKeyRepeat, isTrue);
      expect(defaults.keyRepeatDelayMs, UserSettings.defaultKeyRepeatDelayMs);
      expect(
        defaults.keyRepeatIntervalMs,
        UserSettings.defaultKeyRepeatIntervalMs,
      );
    });

    test('fromJson and toJson clamp and preserve key repeat values', () {
      final parsed = UserSettings.fromJson({
        'useSystemKeyRepeat': false,
        'keyRepeatDelayMs': 9999,
        'keyRepeatIntervalMs': 2,
      });

      expect(parsed.useSystemKeyRepeat, isFalse);
      expect(parsed.keyRepeatDelayMs, UserSettings.maxKeyRepeatDelayMs);
      expect(parsed.keyRepeatIntervalMs, UserSettings.minKeyRepeatIntervalMs);

      final roundTrip = UserSettings.fromJson(
        parsed
            .copyWith(
              useSystemKeyRepeat: false,
              keyRepeatDelayMs: 120,
              keyRepeatIntervalMs: 25,
            )
            .toJson(),
      );

      expect(roundTrip.useSystemKeyRepeat, isFalse);
      expect(roundTrip.keyRepeatDelayMs, 120);
      expect(roundTrip.keyRepeatIntervalMs, 25);
    });

    test('SettingsController.setKeyRepeatSettings clamps and saves', () {
      final service = _InMemorySettingsService();
      final controller = SettingsController(service);

      controller.setKeyRepeatSettings(
        useSystemKeyRepeat: false,
        keyRepeatDelayMs: 90,
        keyRepeatIntervalMs: 20,
      );

      expect(controller.state.useSystemKeyRepeat, isFalse);
      expect(controller.state.keyRepeatDelayMs, 90);
      expect(controller.state.keyRepeatIntervalMs, 20);
      expect(service.stored.keyRepeatIntervalMs, 20);
    });
  });

  group('SettingsDialogContent Navigation controls', () {
    testWidgets(
      'checkbox enables custom delay and interval sliders and persists on OK',
      (tester) async {
        final settingsService = _InMemorySettingsService();
        bool closed = false;

        late ProviderContainer container;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsServiceProvider.overrideWithValue(settingsService),
              themeServiceProvider.overrideWithValue(_InMemoryThemeService()),
            ],
            child: Builder(
              builder: (context) {
                container = ProviderScope.containerOf(context);
                return MaterialApp(
                  home: Scaffold(
                    body: SettingsDialogContent(
                      width: 720,
                      height: 620,
                      onClose: () => closed = true,
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        final checkboxFinder = find.byType(Checkbox);
        expect(checkboxFinder, findsOneWidget);
        expect(tester.widget<Checkbox>(checkboxFinder).value, isTrue);

        // Font size (1) + 2 key repeat sliders (disabled while using system settings)
        final initialSliders = tester
            .widgetList<Slider>(find.byType(Slider))
            .toList();
        expect(initialSliders.length, 3);
        expect(initialSliders[1].onChanged, isNull);
        expect(initialSliders[2].onChanged, isNull);

        await tester.ensureVisible(checkboxFinder);
        await tester.tap(checkboxFinder);
        await tester.pumpAndSettle();

        expect(tester.widget<Checkbox>(checkboxFinder).value, isFalse);
        final unlockedSliders = tester
            .widgetList<Slider>(find.byType(Slider))
            .toList();
        expect(unlockedSliders[1].onChanged, isNotNull);
        expect(unlockedSliders[2].onChanged, isNotNull);

        // Save via OK
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(closed, isTrue);
        expect(
          container.read(userSettingsProvider).useSystemKeyRepeat,
          isFalse,
        );
        expect(settingsService.stored.useSystemKeyRepeat, isFalse);
      },
    );
  });

  group('KeyboardHandler arrow repeat modes', () {
    testWidgets('system key repeat mode processes KeyRepeatEvent immediately', (
      tester,
    ) async {
      final fakeRepo = _FakeFileSystemRepository(_buildSampleItems(20));
      final settingsService = _InMemorySettingsService(
        UserSettings.defaultSettings().copyWith(useSystemKeyRepeat: true),
      );

      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fileSystemRepositoryProvider.overrideWithValue(fakeRepo),
            settingsServiceProvider.overrideWithValue(settingsService),
          ],
          child: Builder(
            builder: (context) {
              container = ProviderScope.containerOf(context);
              return const MaterialApp(
                home: Scaffold(body: KeyboardHandler(child: SizedBox())),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await container.read(userSettingsProvider.notifier).load();

      final leftTabId = container.read(panelTabsProvider('left')).activeTabId;
      await container
          .read(panelStateProvider(leftTabId).notifier)
          .loadPath('/test');
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(container.read(panelStateProvider(leftTabId)).focusedIndex, 1);

      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(container.read(panelStateProvider(leftTabId)).focusedIndex, 3);

      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    });

    testWidgets(
      'custom key repeat mode absorbs KeyRepeatEvent and uses configured delay/interval',
      (tester) async {
        final fakeRepo = _FakeFileSystemRepository(_buildSampleItems(20));
        final settingsService = _InMemorySettingsService(
          UserSettings.defaultSettings().copyWith(
            useSystemKeyRepeat: false,
            keyRepeatDelayMs: 60,
            keyRepeatIntervalMs: 25,
          ),
        );

        late ProviderContainer container;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              fileSystemRepositoryProvider.overrideWithValue(fakeRepo),
              settingsServiceProvider.overrideWithValue(settingsService),
            ],
            child: Builder(
              builder: (context) {
                container = ProviderScope.containerOf(context);
                return const MaterialApp(
                  home: Scaffold(body: KeyboardHandler(child: SizedBox())),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        await container.read(userSettingsProvider.notifier).load();

        final leftTabId = container.read(panelTabsProvider('left')).activeTabId;
        await container
            .read(panelStateProvider(leftTabId).notifier)
            .loadPath('/test');
        await tester.pumpAndSettle();

        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(container.read(panelStateProvider(leftTabId)).focusedIndex, 1);

        // OS KeyRepeatEvent must be absorbed when custom timing is active.
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(container.read(panelStateProvider(leftTabId)).focusedIndex, 1);

        // Initial delay (60 ms) + 2 intervals (50 ms) = 110 ms -> 3 more steps (total 4).
        await tester.pump(const Duration(milliseconds: 115));
        expect(
          container.read(panelStateProvider(leftTabId)).focusedIndex,
          greaterThanOrEqualTo(3),
        );

        await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
      },
    );
  });
}
