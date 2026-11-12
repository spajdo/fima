import 'dart:convert';
import 'dart:io';

import 'package:fima/domain/entity/file_operation.dart';
import 'package:fima/domain/entity/file_system_item.dart';
import 'package:fima/domain/entity/panel_tab.dart';
import 'package:fima/domain/entity/remote_connection.dart';
import 'package:fima/domain/entity/user_settings.dart';
import 'package:fima/domain/entity/workspace.dart';
import 'package:fima/domain/repository/file_system_repository.dart';
import 'package:fima/infrastructure/repository/compound_file_system_repository.dart';
import 'package:fima/infrastructure/repository/ssh_file_system_repository.dart';
import 'package:fima/infrastructure/repository/zip_file_system_repository.dart';
import 'package:fima/infrastructure/service/settings_service.dart';
import 'package:fima/presentation/providers/file_system_provider.dart';
import 'package:fima/presentation/providers/focus_provider.dart';
import 'package:fima/presentation/providers/panel_tabs_provider.dart';
import 'package:fima/presentation/providers/settings_provider.dart';
import 'package:fima/presentation/widgets/keyboard_handler.dart';
import 'package:fima/presentation/widgets/main_screen.dart';
import 'package:fima/presentation/widgets/panel/panel_tab_bar.dart';
import 'package:fima/presentation/widgets/popups/connect_server_dialog.dart';
import 'package:fima/presentation/widgets/popups/omni_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _InMemorySettingsService extends SettingsService {
  UserSettings stored;
  int saveCount = 0;

  _InMemorySettingsService(this.stored);

  @override
  Future<UserSettings> load() async => stored;

  @override
  Future<void> save(UserSettings settings) async {
    stored = settings;
    saveCount++;
  }
}

class _TempFileSettingsService extends SettingsService {
  final String filePath;

  _TempFileSettingsService(this.filePath);

  @override
  Future<String> getSettingsPath() async => filePath;
}

class _FakeFileSystemRepository implements FileSystemRepository {
  final Map<String, List<FileSystemItem>> directories;
  final List<String> requestedPaths = [];

  _FakeFileSystemRepository(this.directories);

  @override
  Future<List<FileSystemItem>> getItems(
    String path, {
    bool showHiddenFiles = false,
  }) async {
    requestedPaths.add(path);
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

class _FakeCompoundRepository implements CompoundFileSystemRepository {
  @override
  final FileSystemRepository defaultRepository;

  @override
  final SshFileSystemRepository sshRepository = SshFileSystemRepository();

  @override
  late final ZipFileSystemRepository zipRepository = ZipFileSystemRepository(
    defaultRepository,
  );

  _FakeCompoundRepository(this.defaultRepository);

  @override
  Future<List<FileSystemItem>> getItems(
    String path, {
    bool showHiddenFiles = false,
  }) => defaultRepository.getItems(path, showHiddenFiles: showHiddenFiles);

  @override
  Future<String> getHomeDirectory() => defaultRepository.getHomeDirectory();

  @override
  Future<void> deleteItem(String path) => defaultRepository.deleteItem(path);

  @override
  Future<void> createDirectory(String path) =>
      defaultRepository.createDirectory(path);

  @override
  Future<void> createFile(String path) => defaultRepository.createFile(path);

  @override
  Future<void> renameItem(String oldPath, String newPath) =>
      defaultRepository.renameItem(oldPath, newPath);

  @override
  Future<void> copyItem(String sourcePath, String destinationPath) =>
      defaultRepository.copyItem(sourcePath, destinationPath);

  @override
  Future<void> moveItem(String sourcePath, String destinationPath) =>
      defaultRepository.moveItem(sourcePath, destinationPath);

  @override
  Future<void> moveToTrash(String path) => defaultRepository.moveToTrash(path);

  @override
  Stream<OperationStatus> copyItems(
    List<String> sourcePaths,
    String destinationPath,
    CancellationToken token,
  ) => defaultRepository.copyItems(sourcePaths, destinationPath, token);

  @override
  Stream<OperationStatus> moveItems(
    List<String> sourcePaths,
    String destinationPath,
    CancellationToken token,
  ) => defaultRepository.moveItems(sourcePaths, destinationPath, token);
}

Future<void> _sendCombo(
  WidgetTester tester,
  List<LogicalKeyboardKey> modifiers,
  LogicalKeyboardKey key,
) async {
  for (final mod in modifiers) {
    await tester.sendKeyDownEvent(mod);
  }
  await tester.sendKeyDownEvent(key);
  await tester.sendKeyUpEvent(key);
  for (final mod in modifiers.reversed) {
    await tester.sendKeyUpEvent(mod);
  }
  await tester.pumpAndSettle();
}

Future<WidgetRef> _pumpApp(
  WidgetTester tester, {
  required _InMemorySettingsService settingsService,
  required FileSystemRepository repo,
  Size windowSize = const Size(1280, 800),
}) async {
  tester.view.physicalSize = windowSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

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
  group('Settings and Workspace migration', () {
    test(
      'SettingsService.load migrates legacy settings and workspaces and saves new format',
      () async {
        final tempDir = await Directory.systemTemp.createTemp('fima_mig_');
        addTearDown(() => tempDir.delete(recursive: true));
        final settingsPath = '${tempDir.path}/settings.json';

        final legacyJson = {
          'leftPanelPath': '/projects/app',
          'rightPanelPath': '/downloads',
          'leftPanelSortColumn': 2,
          'leftPanelSortAscending': false,
          'rightPanelSortColumn': 1,
          'rightPanelSortAscending': true,
          'keyMap': {
            'workspaceDialog': Platform.isMacOS ? '⌘ + W' : 'Ctrl+W',
            'settings': 'Ctrl+Alt+S',
          },
          'workspaces': [
            {
              'name': 'Work',
              'leftPanelPath': '/work/src',
              'rightPanelPath': '/work/docs',
            },
          ],
        };
        await File(settingsPath).writeAsString(jsonEncode(legacyJson));

        final service = _TempFileSettingsService(settingsPath);
        final loaded = await service.load();

        expect(loaded.leftTabs.length, 1);
        expect(loaded.leftTabs.first.path, '/projects/app');
        expect(loaded.leftTabs.first.sortColumn, 2);
        expect(loaded.leftTabs.first.sortAscending, false);
        expect(loaded.rightTabs.length, 1);
        expect(loaded.rightTabs.first.path, '/downloads');
        expect(loaded.rightTabs.first.sortColumn, 1);
        expect(loaded.workspaces.length, 1);
        expect(loaded.workspaces.first.leftTabs.first.path, '/work/src');
        expect(loaded.workspaces.first.rightTabs.first.path, '/work/docs');
        expect(loaded.keyMap.containsKey('workspaceDialog'), isFalse);
        expect(loaded.keyMap['settings'], 'Ctrl+Alt+S');

        // Verify disk file was rewritten in the new format
        final rewritten =
            jsonDecode(await File(settingsPath).readAsString())
                as Map<String, dynamic>;
        expect(rewritten.containsKey('leftTabs'), isTrue);
        expect(rewritten.containsKey('rightTabs'), isTrue);
        expect(rewritten.containsKey('leftPanelPath'), isFalse);
        expect(rewritten.containsKey('rightPanelPath'), isFalse);
        expect(UserSettings.needsMigration(rewritten), isFalse);
      },
    );

    test('Workspace serializes and deserializes multiple tabs', () {
      final ws = Workspace(
        name: 'Multi',
        leftTabs: [
          PanelTab.create(path: '/a/one', sortColumn: 1, sortAscending: false),
          PanelTab.create(path: '/a/two'),
        ],
        leftActiveTabIndex: 1,
        rightTabs: [
          PanelTab.create(path: '/b/one'),
          PanelTab.create(path: '/b/two'),
          PanelTab.create(path: '/b/three'),
        ],
        rightActiveTabIndex: 2,
      );

      final roundTripped = Workspace.fromJson(ws.toJson());
      expect(roundTripped.name, 'Multi');
      expect(roundTripped.leftTabs.map((t) => t.path).toList(), [
        '/a/one',
        '/a/two',
      ]);
      expect(roundTripped.leftActiveTabIndex, 1);
      expect(roundTripped.leftTabs.first.sortColumn, 1);
      expect(roundTripped.leftTabs.first.sortAscending, false);
      expect(roundTripped.rightTabs.map((t) => t.path).toList(), [
        '/b/one',
        '/b/two',
        '/b/three',
      ]);
      expect(roundTripped.rightActiveTabIndex, 2);
    });
  });

  group('Panel tabs UI and shortcuts', () {
    late _FakeFileSystemRepository repo;
    final primaryMod = Platform.isMacOS
        ? LogicalKeyboardKey.metaLeft
        : LogicalKeyboardKey.controlLeft;

    setUp(() {
      repo = _FakeFileSystemRepository({
        '/home/user/alpha': const [],
        '/home/user/beta': const [],
        '/home/user/gamma': const [],
        '/home/other': const [],
      });
    });

    testWidgets(
      'Cmd/Ctrl+T creates tab, Ctrl+Tab / Ctrl+Shift+Tab switches tabs, Cmd/Ctrl+W closes tab',
      (tester) async {
        final settingsService = _InMemorySettingsService(
          UserSettings.defaultSettings().copyWith(
            showWalkthroughOnStartup: false,
            leftTabs: [PanelTab.create(path: '/home/user/alpha')],
            rightTabs: [PanelTab.create(path: '/home/other')],
          ),
        );

        final ref = await _pumpApp(
          tester,
          settingsService: settingsService,
          repo: repo,
        );
        ref.read(focusProvider.notifier).setActivePanel(ActivePanel.left);
        await tester.pump();

        // Initially 1 tab: tab bar is hidden
        expect(
          find.descendant(
            of: find.byType(PanelTabBar),
            matching: find.text('alpha'),
          ),
          findsNothing,
        );

        // Cmd/Ctrl + T -> creates second tab named 'alpha'
        await _sendCombo(tester, [primaryMod], LogicalKeyboardKey.keyT);
        expect(ref.read(panelTabsProvider('left')).tabs.length, 2);
        expect(ref.read(panelTabsProvider('left')).activeTabIndex, 1);
        expect(
          find.descendant(
            of: find.byType(PanelTabBar),
            matching: find.text('alpha'),
          ),
          findsNWidgets(2),
        );

        // Navigate second tab to /home/user/beta
        final tab2Id = ref.read(panelTabsProvider('left')).activeTabId;
        await ref
            .read(panelStateProvider(tab2Id).notifier)
            .loadPath('/home/user/beta');
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(PanelTabBar),
            matching: find.text('alpha'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(PanelTabBar),
            matching: find.text('beta'),
          ),
          findsOneWidget,
        );

        // Ctrl + Shift + Tab -> switch right-to-left (to tab 0: alpha)
        await _sendCombo(tester, [
          LogicalKeyboardKey.controlLeft,
          LogicalKeyboardKey.shiftLeft,
        ], LogicalKeyboardKey.tab);
        expect(ref.read(panelTabsProvider('left')).activeTabIndex, 0);

        // Ctrl + Tab -> switch left-to-right (to tab 1: beta)
        await _sendCombo(tester, [
          LogicalKeyboardKey.controlLeft,
        ], LogicalKeyboardKey.tab);
        expect(ref.read(panelTabsProvider('left')).activeTabIndex, 1);

        // Ctrl + Tab wraps around back to tab 0
        await _sendCombo(tester, [
          LogicalKeyboardKey.controlLeft,
        ], LogicalKeyboardKey.tab);
        expect(ref.read(panelTabsProvider('left')).activeTabIndex, 0);

        // Cmd/Ctrl + W -> closes active tab (tab 0), leaves beta
        await _sendCombo(tester, [primaryMod], LogicalKeyboardKey.keyW);
        expect(ref.read(panelTabsProvider('left')).tabs.length, 1);
        expect(
          ref.read(panelTabsProvider('left')).activeTab.path,
          '/home/user/beta',
        );

        // Cmd/Ctrl + W on last remaining tab is a no-op
        await _sendCombo(tester, [primaryMod], LogicalKeyboardKey.keyW);
        expect(ref.read(panelTabsProvider('left')).tabs.length, 1);
      },
    );

    testWidgets('Shift+Cmd/Ctrl+W opens Workspaces dialog', (tester) async {
      final settingsService = _InMemorySettingsService(
        UserSettings.defaultSettings().copyWith(
          showWalkthroughOnStartup: false,
          leftTabs: [PanelTab.create(path: '/home/user/alpha')],
          rightTabs: [PanelTab.create(path: '/home/other')],
        ),
      );

      await _pumpApp(tester, settingsService: settingsService, repo: repo);

      await _sendCombo(tester, [
        primaryMod,
        LogicalKeyboardKey.shiftLeft,
      ], LogicalKeyboardKey.keyW);

      expect(find.byType(OmniDialog), findsOneWidget);
    });

    testWidgets(
      'Overflow arrow button displays hidden tabs and clicking selects hidden tab',
      (tester) async {
        final settingsService = _InMemorySettingsService(
          UserSettings.defaultSettings().copyWith(
            showWalkthroughOnStartup: false,
            leftTabs: [
              PanelTab.create(path: '/home/user/alpha'),
              PanelTab.create(path: '/home/user/beta'),
              PanelTab.create(path: '/home/user/gamma'),
              PanelTab.create(path: '/home/user/delta_very_long_folder_name'),
              PanelTab.create(path: '/home/user/epsilon_another_long_name'),
            ],
            leftActiveTabIndex: 0,
            rightTabs: [PanelTab.create(path: '/home/other')],
          ),
        );

        final ref = await _pumpApp(
          tester,
          settingsService: settingsService,
          repo: repo,
          windowSize: const Size(760, 600),
        );

        // With 380px left panel and 5 tabs, overflow dropdown icon must appear
        final overflowIcon = find.descendant(
          of: find.byType(PanelTabBar),
          matching: find.byIcon(Icons.keyboard_arrow_down),
        );
        expect(overflowIcon, findsOneWidget);

        // Open overflow menu
        await tester.tap(overflowIcon);
        await tester.pumpAndSettle();

        // Hidden tab should appear in the popup menu
        expect(find.text('epsilon_another_long_name'), findsOneWidget);

        // Selecting it makes it the active tab
        await tester.tap(find.text('epsilon_another_long_name'));
        await tester.pumpAndSettle();
        expect(ref.read(panelTabsProvider('left')).activeTabIndex, 4);
      },
    );

    testWidgets(
      'Restores multi-tab state lazily on startup and saves/loads Workspaces with all tabs',
      (tester) async {
        final settingsService = _InMemorySettingsService(
          UserSettings.defaultSettings().copyWith(
            showWalkthroughOnStartup: false,
            leftTabs: [
              PanelTab.create(path: '/home/user/alpha'),
              PanelTab.create(path: '/home/user/beta'),
            ],
            leftActiveTabIndex: 1,
            rightTabs: [
              PanelTab.create(path: '/home/other'),
              PanelTab.create(path: '/home/user/gamma'),
            ],
            rightActiveTabIndex: 0,
            workspaces: [
              Workspace(
                name: 'SavedTabs',
                leftTabs: [
                  PanelTab.create(path: '/home/user/alpha'),
                  PanelTab.create(path: '/home/user/gamma'),
                ],
                leftActiveTabIndex: 0,
                rightTabs: [PanelTab.create(path: '/home/user/beta')],
                rightActiveTabIndex: 0,
              ),
            ],
          ),
        );

        final ref = await _pumpApp(
          tester,
          settingsService: settingsService,
          repo: repo,
        );

        // Only active tabs should be requested on startup (lazy loading)
        expect(repo.requestedPaths, contains('/home/user/beta'));
        expect(repo.requestedPaths, contains('/home/other'));
        expect(repo.requestedPaths, isNot(contains('/home/user/alpha')));
        expect(repo.requestedPaths, isNot(contains('/home/user/gamma')));

        // Switching to alpha loads it lazily
        await ref.read(panelTabsProvider('left').notifier).selectTab(0);
        await tester.pumpAndSettle();
        expect(repo.requestedPaths, contains('/home/user/alpha'));

        // Open workspace dialog and load 'SavedTabs'
        await _sendCombo(tester, [
          primaryMod,
          LogicalKeyboardKey.shiftLeft,
        ], LogicalKeyboardKey.keyW);
        expect(find.text('SavedTabs'), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        final leftState = ref.read(panelTabsProvider('left'));
        final rightState = ref.read(panelTabsProvider('right'));
        expect(leftState.tabs.map((t) => t.path).toList(), [
          '/home/user/alpha',
          '/home/user/gamma',
        ]);
        expect(leftState.activeTabIndex, 0);
        expect(rightState.tabs.map((t) => t.path).toList(), [
          '/home/user/beta',
        ]);
      },
    );

    testWidgets(
      'Disconnected SSH tab without saved password prompts ConnectServerDialog when activated',
      (tester) async {
        final compoundRepo = _FakeCompoundRepository(repo);
        const conn = RemoteConnection(
          id: 'srv1',
          name: 'MyServer',
          host: '10.0.0.1',
          port: 22,
          username: 'admin',
          rememberPassword: false,
        );

        final settingsService = _InMemorySettingsService(
          UserSettings.defaultSettings().copyWith(
            showWalkthroughOnStartup: false,
            remoteConnections: [conn],
            leftTabs: [
              PanelTab.create(path: '/home/user/alpha'),
              PanelTab.create(path: 'ssh://srv1/var/log'),
            ],
            leftActiveTabIndex: 0,
            rightTabs: [PanelTab.create(path: '/home/other')],
          ),
        );

        final ref = await _pumpApp(
          tester,
          settingsService: settingsService,
          repo: compoundRepo,
        );

        expect(find.byType(ConnectServerDialog), findsNothing);

        // Click the SSH tab ('log')
        await tester.tap(find.text('log'));
        await tester.pumpAndSettle();

        expect(ref.read(panelTabsProvider('left')).activeTabIndex, 1);
        expect(find.byType(ConnectServerDialog), findsOneWidget);
      },
    );
  });
}
