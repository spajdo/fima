import 'package:fima/domain/entity/file_operation.dart';
import 'package:fima/domain/entity/file_system_item.dart';
import 'package:fima/domain/entity/user_settings.dart';
import 'package:fima/domain/repository/file_system_repository.dart';
import 'package:fima/infrastructure/service/settings_service.dart';
import 'package:fima/presentation/providers/file_system_provider.dart';
import 'package:fima/presentation/providers/settings_provider.dart';
import 'package:fima/presentation/widgets/popups/omni_dialog.dart';
import 'package:fima/presentation/widgets/popups/text_input_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _InMemorySettingsService extends SettingsService {
  UserSettings stored = UserSettings.defaultSettings();

  @override
  Future<UserSettings> load() async => stored;

  @override
  Future<void> save(UserSettings settings) async {
    stored = settings;
  }
}

class _FakeFileSystemRepository implements FileSystemRepository {
  @override
  Future<List<FileSystemItem>> getItems(
    String path, {
    bool showHiddenFiles = false,
  }) async => [];

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

void main() {
  testWidgets(
    'Saving workspace from Omni menu persists workspace after OmniDialog disposes',
    (WidgetTester tester) async {
      final fakeSettingsService = _InMemorySettingsService();
      final fakeRepo = _FakeFileSystemRepository();
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsServiceProvider.overrideWithValue(fakeSettingsService),
            fileSystemRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          barrierColor: Colors.transparent,
                          builder: (_) => const OmniDialog(
                            initialText: '>Save as Workspace',
                          ),
                        );
                      },
                      child: const Text('Open Omni'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await capturedRef
          .read(panelStateProvider('left').notifier)
          .loadPath('/tmp/left', addToVisited: false);
      await capturedRef
          .read(panelStateProvider('right').notifier)
          .loadPath('/tmp/right', addToVisited: false);
      await tester.pumpAndSettle();

      // Open OmniDialog with ">Save as Workspace"
      await tester.tap(find.text('Open Omni'));
      await tester.pumpAndSettle();
      expect(find.byType(OmniDialog), findsOneWidget);
      expect(find.text('Save as Workspace'), findsOneWidget);

      // Submit the action with Enter (which pops OmniDialog and opens TextInputDialog)
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // OmniDialog is now completely disposed; TextInputDialog is visible
      expect(find.byType(OmniDialog), findsNothing);
      expect(find.byType(TextInputDialog), findsOneWidget);
      expect(find.text('Save Workspace'), findsOneWidget);

      // Enter workspace name and press Enter
      await tester.enterText(find.byType(TextField), 'My Layout');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.byType(TextInputDialog), findsNothing);

      final workspaces = capturedRef.read(userSettingsProvider).workspaces;
      expect(workspaces.length, 1);
      expect(workspaces.first.name, 'My Layout');
      expect(workspaces.first.leftPanelPath, '/tmp/left');
      expect(workspaces.first.rightPanelPath, '/tmp/right');
      expect(fakeSettingsService.stored.workspaces.length, 1);

      // Verify opening OmniDialog in workspace mode ("w ") lists the saved workspace
      showDialog(
        context: tester.element(find.text('Open Omni')),
        barrierColor: Colors.transparent,
        builder: (_) => const OmniDialog(initialText: 'w '),
      );
      await tester.pumpAndSettle();
      expect(find.text('My Layout'), findsOneWidget);
    },
  );
}
