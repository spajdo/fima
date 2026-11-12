import 'dart:io';

import 'package:fima/domain/entity/file_operation.dart';
import 'package:fima/domain/entity/file_system_item.dart';
import 'package:fima/domain/entity/panel_tab.dart';
import 'package:fima/domain/entity/user_settings.dart';
import 'package:fima/domain/repository/file_system_repository.dart';
import 'package:fima/infrastructure/service/settings_service.dart';
import 'package:fima/presentation/providers/file_system_provider.dart';
import 'package:fima/presentation/providers/focus_provider.dart';
import 'package:fima/presentation/providers/overlay_provider.dart';
import 'package:fima/presentation/providers/panel_tabs_provider.dart';
import 'package:fima/presentation/providers/settings_provider.dart';
import 'package:fima/presentation/widgets/keyboard_handler.dart';
import 'package:fima/presentation/widgets/main_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _InMemorySettingsService extends SettingsService {
  UserSettings stored = UserSettings.defaultSettings().copyWith(
    showWalkthroughOnStartup: false,
  );

  @override
  Future<UserSettings> load() async => stored;

  @override
  Future<void> save(UserSettings settings) async {
    stored = settings;
  }
}

class _FakeFileSystemRepository implements FileSystemRepository {
  final Map<String, List<FileSystemItem>> directories;

  _FakeFileSystemRepository(this.directories);

  @override
  Future<List<FileSystemItem>> getItems(
    String path, {
    bool showHiddenFiles = false,
  }) async {
    final items = directories[path];
    if (items == null) {
      throw FileSystemException('Directory not found', path);
    }
    return items;
  }

  @override
  Future<String> getHomeDirectory() async => '/home/user';

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

Future<WidgetRef> _pumpApp(
  WidgetTester tester,
  _FakeFileSystemRepository repo,
) async {
  final settingsService = _InMemorySettingsService()
    ..stored = UserSettings.defaultSettings().copyWith(
      showWalkthroughOnStartup: false,
      leftTabs: [PanelTab.create(path: '/home/user')],
      rightTabs: [PanelTab.create(path: '/home/other')],
    );

  late WidgetRef capturedRef;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsServiceProvider.overrideWithValue(settingsService),
        fileSystemRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) {
            capturedRef = ref;
            return const KeyboardHandler(child: MainScreen());
          },
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
  return capturedRef;
}

void main() {
  late _FakeFileSystemRepository repo;

  setUp(() {
    repo = _FakeFileSystemRepository({
      '/home': [
        FileSystemItem(
          path: '/home/user',
          name: 'user',
          size: 0,
          modified: DateTime(2026),
          isDirectory: true,
        ),
        FileSystemItem(
          path: '/home/other',
          name: 'other',
          size: 0,
          modified: DateTime(2026),
          isDirectory: true,
        ),
      ],
      '/home/user': [
        FileSystemItem(
          path: '/home/user/docs',
          name: 'docs',
          size: 0,
          modified: DateTime(2026),
          isDirectory: true,
        ),
      ],
      '/home/other': [
        FileSystemItem(
          path: '/home/other/file.txt',
          name: 'file.txt',
          size: 10,
          modified: DateTime(2026),
          isDirectory: false,
        ),
      ],
      '/tmp/target': [
        FileSystemItem(
          path: '/tmp/target/item.txt',
          name: 'item.txt',
          size: 42,
          modified: DateTime(2026),
          isDirectory: false,
        ),
      ],
    });
  });

  testWidgets('Pencil icon is removed from path bar and breadcrumbs render', (
    tester,
  ) async {
    await _pumpApp(tester, repo);

    expect(find.byIcon(Icons.edit), findsNothing);
    expect(find.text('user'), findsOneWidget);
    expect(find.text('other'), findsOneWidget);
  });

  testWidgets('Clicking a breadcrumb segment navigates to that directory', (
    tester,
  ) async {
    final ref = await _pumpApp(tester, repo);

    await tester.tap(find.text('home').first);
    await tester.pumpAndSettle();

    final leftTabId = ref.read(panelTabsProvider('left')).activeTabId;
    final leftState = ref.read(panelStateProvider(leftTabId));
    expect(leftState.currentPath, '/home');
    expect(leftState.isEditingPath, isFalse);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets(
    'Clicking empty path bar area activates edit mode and selects all text',
    (tester) async {
      final ref = await _pumpApp(tester, repo);

      final rightEdge = tester.getTopRight(
        find.byKey(const Key('path_bar_edit_area_left')),
      );
      await tester.tapAt(rightEdge + const Offset(-10, 10));
      await tester.pumpAndSettle();

      final leftTabId = ref.read(panelTabsProvider('left')).activeTabId;
      expect(ref.read(panelStateProvider(leftTabId)).isEditingPath, isTrue);
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, '/home/user');
      expect(
        textField.controller?.selection,
        const TextSelection(baseOffset: 0, extentOffset: '/home/user'.length),
      );
    },
  );

  testWidgets('Shortcut Cmd+L / Ctrl+L activates path bar and selects all', (
    tester,
  ) async {
    final ref = await _pumpApp(tester, repo);
    ref.read(focusProvider.notifier).setActivePanel(ActivePanel.left);
    await tester.pump();

    final modifier = Platform.isMacOS
        ? LogicalKeyboardKey.metaLeft
        : LogicalKeyboardKey.controlLeft;

    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyL);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyL);
    await tester.sendKeyUpEvent(modifier);
    await tester.pumpAndSettle();

    final leftTabId = ref.read(panelTabsProvider('left')).activeTabId;
    expect(ref.read(panelStateProvider(leftTabId)).isEditingPath, isTrue);
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text, '/home/user');
    expect(
      textField.controller?.selection,
      const TextSelection(baseOffset: 0, extentOffset: '/home/user'.length),
    );
  });

  testWidgets('Pressing Enter on valid path navigates to that directory', (
    tester,
  ) async {
    final ref = await _pumpApp(tester, repo);

    final rightEdge = tester.getTopRight(
      find.byKey(const Key('path_bar_edit_area_left')),
    );
    await tester.tapAt(rightEdge + const Offset(-10, 10));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '/tmp/target');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    final leftTabId = ref.read(panelTabsProvider('left')).activeTabId;
    final leftState = ref.read(panelStateProvider(leftTabId));
    expect(leftState.currentPath, '/tmp/target');
    expect(leftState.isEditingPath, isFalse);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('item.txt'), findsOneWidget);
  });

  testWidgets('Pressing Enter on nonexistent path shows error toast', (
    tester,
  ) async {
    final ref = await _pumpApp(tester, repo);

    final rightEdge = tester.getTopRight(
      find.byKey(const Key('path_bar_edit_area_left')),
    );
    await tester.tapAt(rightEdge + const Offset(-10, 10));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '/does/not/exist');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final leftTabId = ref.read(panelTabsProvider('left')).activeTabId;
    final leftState = ref.read(panelStateProvider(leftTabId));
    expect(leftState.currentPath, '/home/user');
    expect(leftState.isEditingPath, isTrue);

    final overlayState = ref.read(overlayProvider);
    expect(overlayState.isToastError, isTrue);
    expect(
      overlayState.toastMessage,
      'Directory does not exist: /does/not/exist',
    );
    expect(
      find.text('Directory does not exist: /does/not/exist'),
      findsOneWidget,
    );

    // Let toast timer complete cleanly before test ends.
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('Leaving path bar without Enter reverts to current open path', (
    tester,
  ) async {
    final ref = await _pumpApp(tester, repo);

    final rightEdge = tester.getTopRight(
      find.byKey(const Key('path_bar_edit_area_left')),
    );
    await tester.tapAt(rightEdge + const Offset(-10, 10));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '/some/typed/path');
    await tester.pump();

    // Click outside the path bar (e.g. on an item in the panel).
    await tester.tap(find.text('docs'));
    await tester.pumpAndSettle();

    final leftTabId = ref.read(panelTabsProvider('left')).activeTabId;
    final leftState = ref.read(panelStateProvider(leftTabId));
    expect(leftState.currentPath, '/home/user');
    expect(leftState.isEditingPath, isFalse);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('user'), findsOneWidget);
  });

  testWidgets('Pressing Escape reverts path bar to current open path', (
    tester,
  ) async {
    final ref = await _pumpApp(tester, repo);

    final rightEdge = tester.getTopRight(
      find.byKey(const Key('path_bar_edit_area_left')),
    );
    await tester.tapAt(rightEdge + const Offset(-10, 10));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '/some/other/path');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    final leftTabId = ref.read(panelTabsProvider('left')).activeTabId;
    final leftState = ref.read(panelStateProvider(leftTabId));
    expect(leftState.currentPath, '/home/user');
    expect(leftState.isEditingPath, isFalse);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('user'), findsOneWidget);
  });

  testWidgets(
    'Clicking opposite panel path bar cancels first and edits second',
    (tester) async {
      final ref = await _pumpApp(tester, repo);

      // Start editing left panel path bar
      final leftEdge = tester.getTopRight(
        find.byKey(const Key('path_bar_edit_area_left')),
      );
      await tester.tapAt(leftEdge + const Offset(-10, 10));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '/edited/left');
      await tester.pump();

      // Click right panel path bar
      final rightEdge = tester.getTopRight(
        find.byKey(const Key('path_bar_edit_area_right')),
      );
      await tester.tapAt(rightEdge + const Offset(-10, 10));
      await tester.pumpAndSettle();

      final leftTabId = ref.read(panelTabsProvider('left')).activeTabId;
      final rightTabId = ref.read(panelTabsProvider('right')).activeTabId;
      final leftState = ref.read(panelStateProvider(leftTabId));
      final rightState = ref.read(panelStateProvider(rightTabId));
      expect(leftState.isEditingPath, isFalse);
      expect(leftState.currentPath, '/home/user');
      expect(rightState.isEditingPath, isTrue);
      expect(ref.read(focusProvider).activePanel, ActivePanel.right);

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, '/home/other');
      expect(
        textField.controller?.selection,
        const TextSelection(baseOffset: 0, extentOffset: '/home/other'.length),
      );
    },
  );

  testWidgets('Pressing Cmd+L / Ctrl+L again while editing selects all text', (
    tester,
  ) async {
    await _pumpApp(tester, repo);

    final rightEdge = tester.getTopRight(
      find.byKey(const Key('path_bar_edit_area_left')),
    );
    await tester.tapAt(rightEdge + const Offset(-10, 10));
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(find.byType(TextField));
    textField.controller?.selection = const TextSelection.collapsed(offset: 2);
    await tester.pump();

    final modifier = Platform.isMacOS
        ? LogicalKeyboardKey.metaLeft
        : LogicalKeyboardKey.controlLeft;

    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyL);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyL);
    await tester.sendKeyUpEvent(modifier);
    await tester.pumpAndSettle();

    expect(
      textField.controller?.selection,
      const TextSelection(baseOffset: 0, extentOffset: '/home/user'.length),
    );
  });
}
