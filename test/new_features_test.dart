import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fima/domain/entity/bookmark.dart';
import 'package:fima/domain/entity/file_operation.dart';
import 'package:fima/domain/entity/file_system_item.dart';
import 'package:fima/domain/entity/panel_state.dart';
import 'package:fima/domain/entity/panel_tab.dart';
import 'package:fima/domain/entity/user_settings.dart';
import 'package:fima/domain/repository/file_system_repository.dart';
import 'package:fima/infrastructure/repository/local_file_system_repository.dart';
import 'package:fima/infrastructure/service/file_diff_service.dart';
import 'package:fima/infrastructure/service/settings_service.dart';
import 'package:fima/presentation/providers/file_system_provider.dart';
import 'package:fima/presentation/providers/focus_provider.dart';
import 'package:fima/presentation/providers/panel_tabs_provider.dart';
import 'package:fima/presentation/providers/settings_provider.dart';
import 'package:fima/presentation/widgets/keyboard_handler.dart';
import 'package:fima/presentation/widgets/main_screen.dart';
import 'package:fima/presentation/widgets/panel/file_context_menu.dart';
import 'package:fima/presentation/widgets/popups/file_diff_dialog.dart';
import 'package:fima/presentation/widgets/popups/item_info_dialog.dart';
import 'package:fima/presentation/widgets/popups/omni_dialog.dart';
import 'package:fima/presentation/widgets/popups/permissions_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

void main() {
  group('Feature 4: Compare Files (FileDiffService & FileDiffDialog)', () {
    test(
      'FileDiffService.diffTexts computes added, removed, and modified lines',
      () {
        final result = FileDiffService.diffTexts(
          leftPath: '/a.txt',
          rightPath: '/b.txt',
          leftContent: 'alpha\nbeta\ngamma\ndelta\n',
          rightContent: 'alpha\nBETA\ngamma\nepsilon\nzeta\n',
        );

        expect(result.error, isNull);
        expect(result.isIdentical, isFalse);
        expect(result.modifiedCount, 2); // beta->BETA, delta->epsilon
        expect(result.addedCount, 1); // zeta
        expect(result.removedCount, 0);
        expect(result.hunkStartRows, [1, 3]);
      },
    );

    test('FileDiffService.diffTexts respects ignoreWhitespace', () {
      final result = FileDiffService.diffTexts(
        leftPath: '/a.txt',
        rightPath: '/b.txt',
        leftContent: '  hello   world \n',
        rightContent: 'hello world\n',
        ignoreWhitespace: true,
      );

      expect(result.isIdentical, isTrue);
    });

    testWidgets('FileDiffDialog compares real temp files side-by-side', (
      tester,
    ) async {
      final tempDir = Directory.systemTemp.createTempSync('fima_diff_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final fileA = File(p.join(tempDir.path, 'left.txt'))
        ..writeAsStringSync('line 1\nold line\nline 3\n');
      final fileB = File(p.join(tempDir.path, 'right.txt'))
        ..writeAsStringSync('line 1\nnew line\nline 3\nextra line\n');

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: FileDiffDialog(leftPath: fileA.path, rightPath: fileB.path),
            ),
          ),
        ),
      );

      await tester.runAsync(() async {
        for (int i = 0; i < 30; i++) {
          await Future.delayed(const Duration(milliseconds: 25));
          await tester.pump();
          if (find.text('old line').evaluate().isNotEmpty) break;
        }
      });
      await tester.pump();

      expect(find.text('Compare Files'), findsOneWidget);
      expect(find.text('old line'), findsOneWidget);
      expect(find.text('new line'), findsOneWidget);
      expect(find.text('extra line'), findsOneWidget);
      expect(find.text('+1'), findsOneWidget);
      expect(find.text('~1'), findsOneWidget);
    });
  });

  group('Feature 5: Checksums in ItemInfoDialog', () {
    testWidgets('calculates MD5 and SHA-256 and verifies pasted hash', (
      tester,
    ) async {
      final tempDir = Directory.systemTemp.createTempSync('fima_hash_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      const content = 'hello world';
      final file = File(p.join(tempDir.path, 'sample.txt'))
        ..writeAsStringSync(content);
      final expectedMd5 = md5.convert(content.codeUnits).toString();
      final expectedSha256 = sha256.convert(content.codeUnits).toString();

      final item = FileSystemItem(
        path: file.path,
        name: 'sample.txt',
        size: content.length,
        modified: DateTime(2026),
        isDirectory: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ItemInfoDialog(items: [item], currentPath: tempDir.path),
            ),
          ),
        ),
      );

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 80));
        await tester.pump();
      });

      final calcBtn = find.text('Calculate MD5 & SHA-256');
      expect(calcBtn, findsOneWidget);
      await tester.ensureVisible(calcBtn);
      await tester.pump();
      await tester.tap(calcBtn);
      await tester.pump();

      await tester.runAsync(() async {
        for (int i = 0; i < 40; i++) {
          await Future.delayed(const Duration(milliseconds: 25));
          await tester.pump();
          if (find.text(expectedMd5).evaluate().isNotEmpty) break;
        }
      });
      await tester.pump();

      expect(find.text(expectedMd5), findsOneWidget);
      expect(find.text(expectedSha256), findsOneWidget);

      final verifyField = find.byType(TextField);
      await tester.ensureVisible(verifyField);
      await tester.pump();
      await tester.enterText(verifyField, expectedSha256);
      await tester.pump();
      expect(find.text('Matches SHA-256'), findsOneWidget);

      await tester.enterText(verifyField, 'deadbeef');
      await tester.pump();
      expect(find.text('Does not match'), findsOneWidget);
    });
  });

  group('Feature 6: Edit Permissions (chmod)', () {
    testWidgets(
      'PermissionsDialog updates POSIX permissions on local file',
      skip: Platform.isWindows,
      (tester) async {
        final tempDir = Directory.systemTemp.createTempSync('fima_chmod_test_');
        addTearDown(() => tempDir.deleteSync(recursive: true));

        final file = File(p.join(tempDir.path, 'script.sh'))
          ..writeAsStringSync('#!/bin/sh\necho ok\n');
        Process.runSync('chmod', ['0644', file.path]);

        final item = FileSystemItem(
          path: file.path,
          name: 'script.sh',
          size: 20,
          modified: DateTime(2026),
          isDirectory: false,
        );

        bool dialogClosed = false;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () {
                      showPermissionsDialog(
                        context,
                        item: item,
                        currentPath: tempDir.path,
                      ).then((_) => dialogClosed = true);
                    },
                    child: const Text('Open Permissions'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Permissions'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        await tester.runAsync(() async {
          for (int i = 0; i < 30; i++) {
            await Future.delayed(const Duration(milliseconds: 25));
            await tester.pump();
            if (find.text('Apply').evaluate().isNotEmpty) break;
          }
        });
        await tester.pump();

        // Enter new octal permissions 0750
        final octalField = find.byType(TextField);
        await tester.ensureVisible(octalField);
        await tester.pump();
        await tester.enterText(octalField, '0750');
        await tester.pump();

        final applyBtn = find.text('Apply');
        await tester.ensureVisible(applyBtn);
        await tester.pump();
        await tester.tap(applyBtn);
        await tester.pump();

        await tester.runAsync(() async {
          for (int i = 0; i < 60; i++) {
            await Future.delayed(const Duration(milliseconds: 25));
            await tester.pump(const Duration(milliseconds: 25));
            if (dialogClosed) break;
          }
        });
        await tester.pump();

        expect(dialogClosed, isTrue);
        final stat = FileStat.statSync(file.path);
        expect(stat.mode & 0xFFF, 0x1E8); // 0750 in octal == 0x1E8
        // Drain toast auto-dismiss timer from OverlayController.showToast.
        await tester.pump(const Duration(seconds: 3));
      },
    );
  });

  group('Feature 7: Calculate Directory Sizes in PanelController', () {
    test(
      'toggleSelectionAtFocus calculates folder size and updates SortColumn.size',
      () async {
        final tempDir = Directory.systemTemp.createTempSync(
          'fima_dirsize_test_',
        );
        addTearDown(() => tempDir.deleteSync(recursive: true));

        final smallDir = Directory(p.join(tempDir.path, 'alpha_small'))
          ..createSync();
        File(
          p.join(smallDir.path, 'a.bin'),
        ).writeAsBytesSync(List.filled(100, 1));

        final largeDir = Directory(p.join(tempDir.path, 'beta_large'))
          ..createSync();
        File(
          p.join(largeDir.path, 'b.bin'),
        ).writeAsBytesSync(List.filled(2048, 2));

        final settingsService = _InMemorySettingsService(
          UserSettings.defaultSettings().copyWith(
            showWalkthroughOnStartup: false,
          ),
        );
        final container = ProviderContainer(
          overrides: [
            settingsServiceProvider.overrideWithValue(settingsService),
            fileSystemRepositoryProvider.overrideWithValue(
              LocalFileSystemRepository(),
            ),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(
          panelStateProvider('left_tab_1').notifier,
        );
        await controller.initTab(panelId: 'left', initialPath: tempDir.path);

        // Focus alpha_small (index 1 because index 0 is '..')
        final items = container.read(panelStateProvider('left_tab_1')).items;
        final smallIdx = items.indexWhere((e) => e.name == 'alpha_small');
        expect(smallIdx, isNonNegative);
        controller.setFocusedIndex(smallIdx);

        // Space toggles selection AND calculates alpha_small size
        controller.toggleSelectionAtFocus();
        expect(
          container.read(panelStateProvider('left_tab_1')).selectedItems,
          contains(smallDir.path),
        );

        // Wait briefly for isolate size calculation
        for (int i = 0; i < 40; i++) {
          await Future.delayed(const Duration(milliseconds: 25));
          if (container
              .read(panelStateProvider('left_tab_1'))
              .directorySizes
              .containsKey(smallDir.path)) {
            break;
          }
        }

        expect(
          container
              .read(panelStateProvider('left_tab_1'))
              .directorySizes[smallDir.path],
          100,
        );

        // Calculate all directory sizes and sort by size
        await controller.calculateAllDirectorySizes();
        final sizes = container
            .read(panelStateProvider('left_tab_1'))
            .directorySizes;
        expect(sizes[smallDir.path], 100);
        expect(sizes[largeDir.path], 2048);

        controller.sort(SortColumn.size);
        var sortedDirs = container
            .read(panelStateProvider('left_tab_1'))
            .items
            .where((i) => i.isDirectory && !i.isParentDetails)
            .toList();
        expect(sortedDirs.map((e) => e.name).toList(), [
          'alpha_small',
          'beta_large',
        ]);

        // Toggle descending sort
        controller.sort(SortColumn.size);
        sortedDirs = container
            .read(panelStateProvider('left_tab_1'))
            .items
            .where((i) => i.isDirectory && !i.isParentDetails)
            .toList();
        expect(sortedDirs.map((e) => e.name).toList(), [
          'beta_large',
          'alpha_small',
        ]);
      },
    );
  });

  group('Feature 9: Bookmarks persistence & OmniDialog ("b ") UX', () {
    test('UserSettings serializes and deserializes bookmarks', () {
      final settings = UserSettings.defaultSettings().copyWith(
        bookmarks: const [
          Bookmark(name: 'Projects', path: '/Users/test/Projects'),
          Bookmark(name: 'Downloads', path: '/Users/test/Downloads'),
        ],
      );

      final roundTripped = UserSettings.fromJson(settings.toJson());
      expect(roundTripped.bookmarks.length, 2);
      expect(roundTripped.bookmarks[0].name, 'Projects');
      expect(roundTripped.bookmarks[0].path, '/Users/test/Projects');
      expect(roundTripped.bookmarks[1].name, 'Downloads');
    });

    testWidgets(
      'OmniDialog ("b ") lists, renames, deletes, and opens bookmark in active panel only',
      (tester) async {
        final repo = _FakeFileSystemRepository({
          '/left/start': [
            FileSystemItem(
              path: '/left/start/alpha.txt',
              name: 'alpha.txt',
              size: 10,
              modified: DateTime(2026),
              isDirectory: false,
            ),
          ],
          '/right/start': [
            FileSystemItem(
              path: '/right/start/beta.txt',
              name: 'beta.txt',
              size: 20,
              modified: DateTime(2026),
              isDirectory: false,
            ),
          ],
          '/bookmarks/work': [
            FileSystemItem(
              path: '/bookmarks/work/readme.md',
              name: 'readme.md',
              size: 30,
              modified: DateTime(2026),
              isDirectory: false,
            ),
          ],
        });

        final settingsService = _InMemorySettingsService(
          UserSettings.defaultSettings().copyWith(
            showWalkthroughOnStartup: false,
            leftTabs: [PanelTab.create(path: '/left/start')],
            rightTabs: [PanelTab.create(path: '/right/start')],
            bookmarks: const [
              Bookmark(name: 'Work Dir', path: '/bookmarks/work'),
              Bookmark(name: 'Temp Dir', path: '/tmp'),
            ],
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

        capturedRef
            .read(focusProvider.notifier)
            .setActivePanel(ActivePanel.left);
        await tester.pump();

        // Open Bookmarks OmniDialog via Cmd+Shift+B / Ctrl+Shift+B
        final modKey = Platform.isMacOS
            ? LogicalKeyboardKey.metaLeft
            : LogicalKeyboardKey.controlLeft;
        await tester.sendKeyDownEvent(modKey);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyB);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyB);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyUpEvent(modKey);
        await tester.pumpAndSettle();

        expect(find.byType(OmniDialog), findsOneWidget);
        expect(find.text('Work Dir'), findsOneWidget);
        expect(find.text('Temp Dir'), findsOneWidget);

        // Delete second bookmark via trash icon
        await tester.tap(find.byIcon(Icons.delete).at(1));
        await tester.pumpAndSettle();
        expect(find.text('Temp Dir'), findsNothing);

        // Rename first bookmark via pencil icon
        await tester.tap(find.byIcon(Icons.edit).first);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, 'Renamed Work');
        await tester.tap(find.text('Rename'));
        await tester.pumpAndSettle();
        expect(find.text('Renamed Work'), findsOneWidget);

        // Tap bookmark row -> navigates active (left) panel only
        await tester.tap(find.text('Renamed Work'));
        await tester.pumpAndSettle();

        final leftTabId = capturedRef
            .read(panelTabsProvider('left'))
            .activeTabId;
        final rightTabId = capturedRef
            .read(panelTabsProvider('right'))
            .activeTabId;
        expect(
          capturedRef.read(panelStateProvider(leftTabId)).currentPath,
          '/bookmarks/work',
        );
        expect(
          capturedRef.read(panelStateProvider(rightTabId)).currentPath,
          '/right/start',
        );
      },
    );

    test(
      'Context menu includes Bookmark, Compare, Calculate Size, and Permissions',
      () {
        final dirEntries = FileContextMenu.buildEntries(
          currentPath: '/tmp',
          clickedItem: FileSystemItem(
            path: '/tmp/folder',
            name: 'folder',
            size: 0,
            modified: DateTime(2026),
            isDirectory: true,
          ),
          targetItems: [
            FileSystemItem(
              path: '/tmp/folder',
              name: 'folder',
              size: 0,
              modified: DateTime(2026),
              isDirectory: true,
            ),
          ],
          hasSelection: false,
          showHiddenFiles: false,
          canPaste: false,
        );
        expect(
          dirEntries.map((e) => e.action),
          containsAll([
            ContextMenuAction.calculateDirectorySize,
            ContextMenuAction.bookmarkFolder,
            if (!Platform.isWindows) ContextMenuAction.editPermissions,
          ]),
        );

        final multiFileEntries = FileContextMenu.buildEntries(
          currentPath: '/tmp',
          clickedItem: FileSystemItem(
            path: '/tmp/a.txt',
            name: 'a.txt',
            size: 10,
            modified: DateTime(2026),
            isDirectory: false,
          ),
          targetItems: [
            FileSystemItem(
              path: '/tmp/a.txt',
              name: 'a.txt',
              size: 10,
              modified: DateTime(2026),
              isDirectory: false,
            ),
            FileSystemItem(
              path: '/tmp/b.txt',
              name: 'b.txt',
              size: 10,
              modified: DateTime(2026),
              isDirectory: false,
            ),
          ],
          hasSelection: true,
          showHiddenFiles: false,
          canPaste: false,
        );
        expect(
          multiFileEntries.map((e) => e.action),
          contains(ContextMenuAction.compareFiles),
        );
      },
    );
  });
}
