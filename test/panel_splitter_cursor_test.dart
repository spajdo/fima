import 'dart:io';

import 'package:fima/domain/entity/file_operation.dart';
import 'package:fima/domain/entity/file_system_item.dart';
import 'package:fima/domain/entity/panel_tab.dart';
import 'package:fima/domain/entity/user_settings.dart';
import 'package:fima/domain/repository/file_system_repository.dart';
import 'package:fima/infrastructure/service/settings_service.dart';
import 'package:fima/presentation/providers/file_system_provider.dart';
import 'package:fima/presentation/providers/settings_provider.dart';
import 'package:fima/presentation/widgets/main_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _InMemorySettingsService extends SettingsService {
  UserSettings stored = UserSettings.defaultSettings().copyWith(
    showWalkthroughOnStartup: false,
    leftTabs: [PanelTab.create(path: '/home/user')],
    rightTabs: [PanelTab.create(path: '/home/other')],
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

void main() {
  testWidgets(
    'Hovering over panel splitter shows resizeLeftRight cursor when resizable',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _FakeFileSystemRepository({
        '/home/user': const [],
        '/home/other': const [],
      });
      final settingsService = _InMemorySettingsService();

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
                return const MainScreen();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final mainScreenSize = tester.getSize(find.byType(MainScreen));
      final splitterCenter = Offset(
        mainScreenSize.width * 0.5 + 2,
        mainScreenSize.height * 0.5,
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      await gesture.moveTo(splitterCenter);
      await tester.pump();

      expect(
        RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
        SystemMouseCursors.resizeLeftRight,
      );

      // Dragging the splitter updates the split ratio
      await tester.dragFrom(splitterCenter, const Offset(80, 0));
      await tester.pumpAndSettle();
      expect(
        capturedRef.read(userSettingsProvider).panelSplitRatio,
        greaterThan(0.5),
      );

      // When a modal barrier blocks the splitter, hovering its previous
      // coordinates no longer shows the resize cursor.
      showDialog<void>(
        context: tester.element(find.byType(MainScreen)),
        builder: (context) => const AlertDialog(content: Text('Blocked')),
      );
      await tester.pumpAndSettle();

      await gesture.moveTo(splitterCenter);
      await tester.pump();

      expect(
        RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
        isNot(SystemMouseCursors.resizeLeftRight),
      );
    },
  );
}
