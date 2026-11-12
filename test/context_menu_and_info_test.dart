import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:fima/domain/entity/file_operation.dart';
import 'package:fima/domain/entity/file_system_item.dart';
import 'package:fima/domain/entity/panel_tab.dart';
import 'package:fima/domain/entity/user_settings.dart';
import 'package:fima/domain/repository/file_system_repository.dart';
import 'package:fima/infrastructure/repository/local_file_system_repository.dart';
import 'package:fima/infrastructure/service/settings_service.dart';
import 'package:fima/presentation/providers/file_system_provider.dart';
import 'package:fima/presentation/providers/focus_provider.dart';
import 'package:fima/presentation/providers/panel_tabs_provider.dart';
import 'package:fima/presentation/providers/settings_provider.dart';
import 'package:fima/presentation/widgets/keyboard_handler.dart';
import 'package:fima/presentation/widgets/main_screen.dart';
import 'package:fima/presentation/widgets/panel/file_context_menu.dart';
import 'package:fima/presentation/widgets/popups/item_info_dialog.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

class _InMemorySettingsService extends SettingsService {
  UserSettings stored;

  _InMemorySettingsService(this.stored);

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
    return directories[path] ?? const [];
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

Future<WidgetRef> _pumpMainApp(
  WidgetTester tester,
  _FakeFileSystemRepository repo, {
  String leftPath = '/left',
  String rightPath = '/right',
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final settingsService = _InMemorySettingsService(
    UserSettings.defaultSettings().copyWith(
      showWalkthroughOnStartup: false,
      leftTabs: [PanelTab.create(path: leftPath)],
      rightTabs: [PanelTab.create(path: rightPath)],
    ),
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

Future<void> _pumpDialogUntilText(WidgetTester tester, String target) async {
  await tester.pump();
  for (int i = 0; i < 40; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump();
    if (find.text(target).evaluate().isNotEmpty) {
      break;
    }
  }
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('fima_ctx_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('pasteboard'),
          (call) async => <String>[],
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('pasteboard'), null);
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('FileContextMenu.buildEntries deduction', () {
    test('returns appropriate actions for a regular local file', () {
      final file = FileSystemItem(
        path: '/tmp/notes.txt',
        name: 'notes.txt',
        size: 120,
        modified: DateTime(2026, 1, 1),
        isDirectory: false,
      );

      final entries = FileContextMenu.buildEntries(
        currentPath: '/tmp',
        clickedItem: file,
        targetItems: [file],
        hasSelection: false,
        showHiddenFiles: false,
        canPaste: false,
      );

      final actions = entries
          .where((e) => !e.isDivider)
          .map((e) => e.action)
          .toList();

      expect(
        actions,
        containsAll([
          ContextMenuAction.open,
          ContextMenuAction.openWith,
          ContextMenuAction.preview,
          ContextMenuAction.copyToOpposite,
          ContextMenuAction.moveToOpposite,
          ContextMenuAction.copyToClipboard,
          ContextMenuAction.cutToClipboard,
          ContextMenuAction.copyPath,
          ContextMenuAction.rename,
          ContextMenuAction.compress,
          ContextMenuAction.openDefaultManager,
          ContextMenuAction.moveToTrash,
          ContextMenuAction.permanentDelete,
          ContextMenuAction.info,
        ]),
      );
      expect(actions.last, ContextMenuAction.info);
      expect(actions, isNot(contains(ContextMenuAction.extractHere)));
      expect(actions, isNot(contains(ContextMenuAction.openTerminalHere)));
    });

    test(
      'returns archive actions for a .zip file and omits preview/compress',
      () {
        final zip = FileSystemItem(
          path: '/tmp/bundle.zip',
          name: 'bundle.zip',
          size: 2048,
          modified: DateTime(2026, 1, 1),
          isDirectory: false,
        );

        final entries = FileContextMenu.buildEntries(
          currentPath: '/tmp',
          clickedItem: zip,
          targetItems: [zip],
          hasSelection: false,
          showHiddenFiles: false,
          canPaste: false,
        );

        final actions = entries
            .where((e) => !e.isDivider)
            .map((e) => e.action)
            .toList();

        expect(
          actions,
          containsAll([
            ContextMenuAction.open,
            ContextMenuAction.openInNewTab,
            ContextMenuAction.extractHere,
            ContextMenuAction.extractToFolder,
            ContextMenuAction.extractToOpposite,
            ContextMenuAction.rename,
            ContextMenuAction.info,
          ]),
        );
        expect(actions.last, ContextMenuAction.info);
        expect(actions, isNot(contains(ContextMenuAction.preview)));
        expect(actions, isNot(contains(ContextMenuAction.compress)));
      },
    );

    test('returns directory actions and omits preview/openWith', () {
      final dir = FileSystemItem(
        path: '/tmp/docs',
        name: 'docs',
        size: 0,
        modified: DateTime(2026, 1, 1),
        isDirectory: true,
      );

      final entries = FileContextMenu.buildEntries(
        currentPath: '/tmp',
        clickedItem: dir,
        targetItems: [dir],
        hasSelection: false,
        showHiddenFiles: false,
        canPaste: false,
      );

      final actions = entries
          .where((e) => !e.isDivider)
          .map((e) => e.action)
          .toList();

      expect(
        actions,
        containsAll([
          ContextMenuAction.open,
          ContextMenuAction.openInNewTab,
          ContextMenuAction.openInOppositePanel,
          ContextMenuAction.compress,
          ContextMenuAction.openTerminalHere,
          ContextMenuAction.openDefaultManager,
          ContextMenuAction.info,
        ]),
      );
      expect(actions.last, ContextMenuAction.info);
      expect(actions, isNot(contains(ContextMenuAction.preview)));
      expect(actions, isNot(contains(ContextMenuAction.openWith)));
    });

    test('returns batch actions for multi-selection', () {
      final f1 = FileSystemItem(
        path: '/tmp/a.txt',
        name: 'a.txt',
        size: 10,
        modified: DateTime(2026, 1, 1),
        isDirectory: false,
      );
      final f2 = FileSystemItem(
        path: '/tmp/b.txt',
        name: 'b.txt',
        size: 20,
        modified: DateTime(2026, 1, 1),
        isDirectory: false,
      );

      final entries = FileContextMenu.buildEntries(
        currentPath: '/tmp',
        clickedItem: f1,
        targetItems: [f1, f2],
        hasSelection: true,
        showHiddenFiles: false,
        canPaste: false,
      );

      final actions = entries
          .where((e) => !e.isDivider)
          .map((e) => e.action)
          .toList();

      expect(
        actions,
        containsAll([
          ContextMenuAction.copyToOpposite,
          ContextMenuAction.moveToOpposite,
          ContextMenuAction.copyToClipboard,
          ContextMenuAction.cutToClipboard,
          ContextMenuAction.copyPath,
          ContextMenuAction.compress,
          ContextMenuAction.moveToTrash,
          ContextMenuAction.permanentDelete,
          ContextMenuAction.info,
        ]),
      );
      expect(actions, isNot(contains(ContextMenuAction.rename)));
      expect(actions, isNot(contains(ContextMenuAction.open)));
      expect(actions, isNot(contains(ContextMenuAction.preview)));
      expect(actions.last, ContextMenuAction.info);
    });

    test('omits write actions inside ZIP archive and trash on SSH', () {
      final zipEntry = FileSystemItem(
        path: '/tmp/archive.zip/readme.txt',
        name: 'readme.txt',
        size: 50,
        modified: DateTime(2026, 1, 1),
        isDirectory: false,
      );
      final zipEntries = FileContextMenu.buildEntries(
        currentPath: '/tmp/archive.zip',
        clickedItem: zipEntry,
        targetItems: [zipEntry],
        hasSelection: false,
        showHiddenFiles: false,
        canPaste: false,
      );
      final zipActions = zipEntries
          .where((e) => !e.isDivider)
          .map((e) => e.action)
          .toList();
      expect(
        zipActions,
        equals([
          ContextMenuAction.copyToOpposite,
          ContextMenuAction.copyPath,
          ContextMenuAction.info,
        ]),
      );

      final sshFile = FileSystemItem(
        path: 'ssh://conn1/var/log/app.log',
        name: 'app.log',
        size: 500,
        modified: DateTime(2026, 1, 1),
        isDirectory: false,
      );
      final sshEntries = FileContextMenu.buildEntries(
        currentPath: 'ssh://conn1/var/log',
        clickedItem: sshFile,
        targetItems: [sshFile],
        hasSelection: false,
        showHiddenFiles: false,
        canPaste: false,
      );
      final sshActions = sshEntries
          .where((e) => !e.isDivider)
          .map((e) => e.action)
          .toList();
      expect(sshActions, isNot(contains(ContextMenuAction.moveToTrash)));
      expect(sshActions, isNot(contains(ContextMenuAction.openTerminalHere)));
      expect(sshActions, contains(ContextMenuAction.permanentDelete));
      expect(sshActions.last, ContextMenuAction.info);
    });

    test('returns background actions when right-clicking empty space', () {
      final entries = FileContextMenu.buildEntries(
        currentPath: '/tmp',
        clickedItem: null,
        targetItems: const [],
        hasSelection: true,
        showHiddenFiles: false,
        canPaste: true,
      );

      final actions = entries
          .where((e) => !e.isDivider)
          .map((e) => e.action)
          .toList();

      expect(
        actions,
        containsAll([
          ContextMenuAction.pasteFromClipboard,
          ContextMenuAction.createDirectory,
          ContextMenuAction.createFile,
          ContextMenuAction.selectAll,
          ContextMenuAction.deselectAll,
          ContextMenuAction.toggleHiddenFiles,
          ContextMenuAction.refresh,
          ContextMenuAction.openTerminalHere,
          ContextMenuAction.openDefaultManager,
          ContextMenuAction.info,
        ]),
      );
      expect(actions.last, ContextMenuAction.info);
    });
  });

  group('Right-click context menu UI in FilePanel', () {
    testWidgets(
      'right-clicking a file shows file actions and opens Info dialog',
      (tester) async {
        final repo = _FakeFileSystemRepository({
          '/left': [
            FileSystemItem(
              path: '/left/hello.txt',
              name: 'hello.txt',
              size: 20,
              modified: DateTime(2026, 5, 1, 12, 30),
              isDirectory: false,
            ),
          ],
          '/right': const [],
        });

        await _pumpMainApp(tester, repo);

        await tester.tap(
          find.text('hello.txt'),
          buttons: kSecondaryMouseButton,
        );
        await tester.pumpAndSettle();

        expect(find.text('Preview'), findsOneWidget);
        expect(find.text('Rename'), findsOneWidget);
        expect(find.text('Compress to ZIP'), findsOneWidget);
        expect(find.text('Info'), findsOneWidget);
        expect(find.text('Extract Here'), findsNothing);

        await tester.tap(find.text('Info'));
        await tester.pumpAndSettle();

        expect(find.byType(ItemInfoDialog), findsOneWidget);
        expect(find.text('Info — hello.txt'), findsOneWidget);
        expect(find.text('Plain Text Document'), findsWidgets);
        expect(find.text('/left/hello.txt'), findsOneWidget);

        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(find.byType(ItemInfoDialog), findsNothing);
      },
    );

    testWidgets('right-clicking a .zip file shows extraction options', (
      tester,
    ) async {
      final repo = _FakeFileSystemRepository({
        '/left': [
          FileSystemItem(
            path: '/left/bundle.zip',
            name: 'bundle.zip',
            size: 4096,
            modified: DateTime(2026, 5, 1),
            isDirectory: false,
          ),
        ],
        '/right': const [],
      });

      await _pumpMainApp(tester, repo);

      await tester.tap(find.text('bundle.zip'), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      expect(find.text('Browse Archive'), findsOneWidget);
      expect(find.text('Extract Here'), findsOneWidget);
      expect(find.text('Extract to "bundle/"'), findsOneWidget);
      expect(find.text('Extract to Opposite Panel'), findsOneWidget);
      expect(find.text('Preview'), findsNothing);
    });

    testWidgets('right-clicking a directory shows folder options', (
      tester,
    ) async {
      final repo = _FakeFileSystemRepository({
        '/left': [
          FileSystemItem(
            path: '/left/projects',
            name: 'projects',
            size: 0,
            modified: DateTime(2026, 5, 1),
            isDirectory: true,
          ),
        ],
        '/right': const [],
      });

      await _pumpMainApp(tester, repo);

      await tester.tap(find.text('projects'), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      expect(find.text('Open Terminal Here'), findsOneWidget);
      expect(find.text('Open in New Tab'), findsOneWidget);
      expect(find.text('Open in Opposite Panel'), findsOneWidget);
      expect(find.text('Preview'), findsNothing);
    });

    testWidgets(
      'right-click preserves multi-selection or resets stale selection',
      (tester) async {
        final repo = _FakeFileSystemRepository({
          '/left': [
            FileSystemItem(
              path: '/left/one.txt',
              name: 'one.txt',
              size: 1,
              modified: DateTime(2026, 5, 1),
              isDirectory: false,
            ),
            FileSystemItem(
              path: '/left/two.txt',
              name: 'two.txt',
              size: 2,
              modified: DateTime(2026, 5, 1),
              isDirectory: false,
            ),
            FileSystemItem(
              path: '/left/three.txt',
              name: 'three.txt',
              size: 3,
              modified: DateTime(2026, 5, 1),
              isDirectory: false,
            ),
          ],
          '/right': const [],
        });

        final ref = await _pumpMainApp(tester, repo);

        final tabId = ref.read(panelTabsProvider('left')).activeTabId;
        final controller = ref.read(panelStateProvider(tabId).notifier);
        controller.selectItemOnly('/left/one.txt');
        controller.toggleSelection('/left/two.txt');
        await tester.pump();

        await tester.tap(find.text('one.txt'), buttons: kSecondaryMouseButton);
        await tester.pumpAndSettle();

        expect(find.text('Copy 2 Items to Opposite Panel'), findsOneWidget);
        expect(find.text('Compress 2 Items...'), findsOneWidget);

        // Dismiss menu by tapping outside.
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        // Right-clicking unselected item clears old selection and targets it.
        await tester.tap(
          find.text('three.txt'),
          buttons: kSecondaryMouseButton,
        );
        await tester.pumpAndSettle();

        expect(find.text('Rename'), findsOneWidget);
        expect(find.text('Copy 2 Items to Opposite Panel'), findsNothing);
        expect(ref.read(panelStateProvider(tabId)).selectedItems, isEmpty);
      },
    );

    testWidgets('right-clicking empty area opens background context menu', (
      tester,
    ) async {
      final repo = _FakeFileSystemRepository({
        '/left': [
          FileSystemItem(
            path: '/left/only.txt',
            name: 'only.txt',
            size: 3,
            modified: DateTime(2026, 5, 1),
            isDirectory: false,
          ),
        ],
        '/right': const [],
      });

      final ref = await _pumpMainApp(tester, repo);

      await tester.tapAt(
        const Offset(150, 500),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      expect(find.text('New Folder...'), findsOneWidget);
      expect(find.text('New File...'), findsOneWidget);
      expect(find.text('Select All'), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);
      expect(find.text('Info'), findsOneWidget);
      expect(ref.read(focusProvider).activePanel, ActivePanel.left);
    });
  });

  group('ItemInfoDialog real filesystem metadata', () {
    testWidgets(
      'displays real file metadata, permissions, and PNG dimensions',
      (tester) async {
        final image = img.Image(width: 48, height: 32);
        img.fill(image, color: img.ColorRgb8(10, 120, 220));
        final pngFile = File(p.join(tempDir.path, 'photo.png'))
          ..writeAsBytesSync(img.encodePng(image));
        final stat = pngFile.statSync();

        final item = FileSystemItem(
          path: pngFile.path,
          name: 'photo.png',
          size: stat.size,
          modified: stat.modified,
          isDirectory: false,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              fileSystemRepositoryProvider.overrideWithValue(
                LocalFileSystemRepository(),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ItemInfoDialog(items: [item], currentPath: tempDir.path),
              ),
            ),
          ),
        );

        await _pumpDialogUntilText(tester, '48 × 32 px');

        expect(find.text('Info — photo.png'), findsOneWidget);
        expect(find.text('PNG Image'), findsWidgets);
        expect(find.text('48 × 32 px'), findsOneWidget);
        expect(find.text(pngFile.path), findsOneWidget);
        expect(find.text('TIMESTAMPS'), findsOneWidget);
        expect(find.text('PERMISSIONS & ATTRIBUTES'), findsOneWidget);
      },
    );

    testWidgets('calculates recursive folder size and item counts', (
      tester,
    ) async {
      final subDir = Directory(p.join(tempDir.path, 'projects'))..createSync();
      final nestedDir = Directory(p.join(subDir.path, 'sub'))..createSync();
      File(p.join(subDir.path, 'a.txt')).writeAsBytesSync(List.filled(600, 65));
      File(
        p.join(nestedDir.path, 'b.txt'),
      ).writeAsBytesSync(List.filled(700, 66));

      final dirItem = FileSystemItem(
        path: subDir.path,
        name: 'projects',
        size: 0,
        modified: subDir.statSync().modified,
        isDirectory: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fileSystemRepositoryProvider.overrideWithValue(
              LocalFileSystemRepository(),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ItemInfoDialog(items: [dirItem], currentPath: tempDir.path),
            ),
          ),
        ),
      );

      await _pumpDialogUntilText(tester, '2 files, 1 folder');

      expect(find.text('Folder'), findsWidgets);
      expect(find.text('2 files, 1 folder'), findsOneWidget);
      expect(find.text('1.3 KB (1,300 bytes)'), findsOneWidget);
    });

    testWidgets('displays ZIP archive entry count and uncompressed size', (
      tester,
    ) async {
      final innerFile = File(p.join(tempDir.path, 'inside.txt'))
        ..writeAsStringSync('Archive payload content ' * 20);
      final zipPath = p.join(tempDir.path, 'bundle.zip');
      final encoder = ZipFileEncoder();
      encoder.create(zipPath);
      await tester.runAsync(() => encoder.addFile(innerFile, 'inside.txt'));
      await tester.runAsync(() => encoder.close());

      final zipFile = File(zipPath);
      final zipItem = FileSystemItem(
        path: zipPath,
        name: 'bundle.zip',
        size: zipFile.lengthSync(),
        modified: zipFile.statSync().modified,
        isDirectory: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fileSystemRepositoryProvider.overrideWithValue(
              LocalFileSystemRepository(),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ItemInfoDialog(items: [zipItem], currentPath: tempDir.path),
            ),
          ),
        ),
      );

      await _pumpDialogUntilText(tester, '1 file, 0 folders');

      expect(find.text('ZIP Archive'), findsWidgets);
      expect(find.text('1 file, 0 folders'), findsOneWidget);
      expect(find.text('Uncompressed'), findsOneWidget);
    });

    testWidgets(
      'fits without scrolling in tall window and scrolls when window shrinks',
      (tester) async {
        final image = img.Image(width: 48, height: 32);
        img.fill(image, color: img.ColorRgb8(10, 120, 220));
        final pngFile = File(p.join(tempDir.path, 'tall_test.png'))
          ..writeAsBytesSync(img.encodePng(image));
        final stat = pngFile.statSync();

        final item = FileSystemItem(
          path: pngFile.path,
          name: 'tall_test.png',
          size: stat.size,
          modified: stat.modified,
          isDirectory: false,
        );

        tester.view.physicalSize = const Size(1280, 1100);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              fileSystemRepositoryProvider.overrideWithValue(
                LocalFileSystemRepository(),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => showItemInfoDialog(
                      context,
                      items: [item],
                      currentPath: tempDir.path,
                    ),
                    child: const Text('Open Info'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Info'));
        await _pumpDialogUntilText(tester, '48 × 32 px');

        // Calculate checksums so content height exceeds old 680px cap.
        await tester.tap(find.text('Calculate MD5 & SHA-256'));
        await _pumpDialogUntilText(tester, 'Verify Hash');

        final scrollView = tester.widget<SingleChildScrollView>(
          find.byType(SingleChildScrollView),
        );
        expect(scrollView.controller!.position.maxScrollExtent, 0.0);
        expect(tester.getSize(find.byType(Dialog)).height, greaterThan(680.0));

        // Shrink the main window so the dialog no longer fits vertically.
        tester.view.physicalSize = const Size(1280, 460);
        await tester.pumpAndSettle();

        expect(
          scrollView.controller!.position.maxScrollExtent,
          greaterThan(0.0),
        );
      },
    );
  });
}
