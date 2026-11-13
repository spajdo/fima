import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:fima/domain/entity/file_operation.dart';
import 'package:fima/domain/entity/file_system_item.dart';
import 'package:fima/domain/entity/panel_tab.dart';
import 'package:fima/domain/entity/user_settings.dart';
import 'package:fima/domain/repository/file_system_repository.dart';
import 'package:fima/domain/utils/fima_path.dart';
import 'package:fima/infrastructure/repository/compound_file_system_repository.dart';
import 'package:fima/infrastructure/repository/local_file_system_repository.dart';
import 'package:fima/infrastructure/repository/zip_file_system_repository.dart';
import 'package:fima/infrastructure/service/settings_service.dart';
import 'package:fima/infrastructure/service/system_clipboard_service.dart';
import 'package:fima/presentation/providers/clipboard_actions.dart';
import 'package:fima/presentation/providers/file_system_provider.dart';
import 'package:fima/presentation/providers/panel_tabs_provider.dart';
import 'package:fima/presentation/providers/settings_provider.dart';
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

class _DelayedRepo implements FileSystemRepository {
  final Map<String, Completer<List<FileSystemItem>>> completers = {};

  @override
  Future<List<FileSystemItem>> getItems(
    String path, {
    bool showHiddenFiles = false,
  }) {
    final c = Completer<List<FileSystemItem>>();
    completers[path] = c;
    return c.future;
  }

  @override
  Future<String> getHomeDirectory() async => '/tmp';

  @override
  Future<void> copyItem(String sourcePath, String destinationPath) async {}

  @override
  Stream<OperationStatus> copyItems(
    List<String> sourcePaths,
    String destinationPath,
    CancellationToken token,
  ) => const Stream.empty();

  @override
  Future<void> createDirectory(String path) async {}

  @override
  Future<void> createFile(String path) async {}

  @override
  Future<void> deleteItem(String path) async {}

  @override
  Future<void> moveItem(String sourcePath, String destinationPath) async {}

  @override
  Stream<OperationStatus> moveItems(
    List<String> sourcePaths,
    String destinationPath,
    CancellationToken token,
  ) => const Stream.empty();

  @override
  Future<void> moveToTrash(String path) async {}

  @override
  Future<void> renameItem(String oldPath, String newPath) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FimaPath helpers and security checks', () {
    test('handles local, ssh, and zip paths consistently', () {
      expect(FimaPath.isSshPath('ssh://conn1/home/user'), isTrue);
      expect(FimaPath.isSshPath('/tmp/test.zip'), isFalse);

      expect(FimaPath.extractZipParts('ssh://conn1/a.zip/file'), isNull);
      expect(FimaPath.extractZipParts('/tmp/a.zip/sub/file.txt'), (
        '/tmp/a.zip',
        'sub/file.txt',
      ));

      expect(FimaPath.join('ssh://conn1/', 'file.txt'), 'ssh://conn1/file.txt');
      expect(
        FimaPath.join('ssh://conn1/dir', 'file.txt'),
        'ssh://conn1/dir/file.txt',
      );
      expect(FimaPath.dirname('ssh://conn1/dir/file.txt'), 'ssh://conn1/dir');
      expect(FimaPath.dirname('ssh://conn1/file.txt'), 'ssh://conn1/');
      expect(FimaPath.basename('ssh://conn1/dir/file.txt'), 'file.txt');
    });

    test('isStrictlyWithin and isSameOrWithin block Zip-Slip & self-copy', () {
      expect(FimaPath.isStrictlyWithin('/tmp/dest', '/tmp/dest/a.txt'), isTrue);
      expect(
        FimaPath.isStrictlyWithin('/tmp/dest', '/tmp/dest/../evil.txt'),
        isFalse,
      );
      expect(FimaPath.isSameOrWithin('/tmp/dir', '/tmp/dir'), isTrue);
      expect(FimaPath.isSameOrWithin('/tmp/dir', '/tmp/dir/sub'), isTrue);
      expect(FimaPath.isSameOrWithin('/tmp/dir', '/tmp/dir_other'), isFalse);
    });
  });

  group('Local & Zip filesystem safety fixes', () {
    late Directory tempDir;
    late LocalFileSystemRepository localRepo;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fima_phase1_');
      localRepo = LocalFileSystemRepository();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'copyItems rejects copying file onto itself without truncation',
      () async {
        final file = File(p.join(tempDir.path, 'data.txt'));
        await file.writeAsString('important content');

        expect(() async {
          await for (final _ in localRepo.copyItems(
            [file.path],
            tempDir.path,
            CancellationToken(),
          )) {}
        }, throwsA(isA<FileSystemException>()));

        expect(await file.readAsString(), 'important content');
      },
    );

    test(
      'copyItems rejects copying directory into its own subdirectory',
      () async {
        final parentDir = Directory(p.join(tempDir.path, 'parent'));
        final childDir = Directory(p.join(parentDir.path, 'child'));
        await childDir.create(recursive: true);

        expect(() async {
          await for (final _ in localRepo.copyItems(
            [parentDir.path],
            childDir.path,
            CancellationToken(),
          )) {}
        }, throwsA(isA<FileSystemException>()));
      },
    );

    test('ZipFileSystemRepository blocks Zip-Slip traversal entries', () async {
      final archive = Archive()
        ..addFile(ArchiveFile('../escaped.txt', 4, 'evil'.codeUnits))
        ..addFile(ArchiveFile('safe.txt', 2, 'ok'.codeUnits));
      final zipFile = File(p.join(tempDir.path, 'test.zip'));
      await zipFile.writeAsBytes(ZipEncoder().encode(archive));

      final destDir = Directory(p.join(tempDir.path, 'out'));
      await destDir.create();

      final zipRepo = ZipFileSystemRepository(localRepo);
      await for (final _ in zipRepo.extractItems(
        [
          p.join(zipFile.path, '../escaped.txt'),
          p.join(zipFile.path, 'safe.txt'),
        ],
        destDir.path,
        CancellationToken(),
      )) {}

      expect(File(p.join(tempDir.path, 'escaped.txt')).existsSync(), isFalse);
      expect(File(p.join(destDir.path, 'safe.txt')).existsSync(), isTrue);
    });
  });

  group('Concurrency & panel isolation fixes', () {
    test('PanelController.loadPath drops stale async responses', () async {
      final repo = _DelayedRepo();
      final container = ProviderContainer(
        overrides: [
          fileSystemRepositoryProvider.overrideWithValue(repo),
          settingsServiceProvider.overrideWithValue(
            _InMemorySettingsService(
              const UserSettings(leftTabs: [], rightTabs: []),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(userSettingsProvider.notifier).ensureLoaded();
      final controller = container.read(panelStateProvider('tab-1').notifier);

      final firstLoad = controller.loadPath('/slow/path');
      final secondLoad = controller.loadPath('/fast/path');

      repo.completers['/fast/path']!.complete([
        FileSystemItem(
          path: '/fast/path/fast.txt',
          name: 'fast.txt',
          size: 10,
          modified: DateTime(2026),
          isDirectory: false,
        ),
      ]);
      await secondLoad;
      expect(
        container.read(panelStateProvider('tab-1')).currentPath,
        '/fast/path',
      );

      repo.completers['/slow/path']!.complete([
        FileSystemItem(
          path: '/slow/path/slow.txt',
          name: 'slow.txt',
          size: 10,
          modified: DateTime(2026),
          isDirectory: false,
        ),
      ]);
      await firstLoad;

      final finalState = container.read(panelStateProvider('tab-1'));
      expect(finalState.currentPath, '/fast/path');
      expect(finalState.items.map((e) => e.name), contains('fast.txt'));
      expect(finalState.items.map((e) => e.name), isNot(contains('slow.txt')));
    });

    test(
      'Paste after cut never hijacks a panel that navigated away from source',
      () async {
        final tempDir = await Directory.systemTemp.createTemp('fima_paste_');
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final dirA = Directory(p.join(tempDir.path, 'dirA'))..createSync();
        final dirB = Directory(p.join(tempDir.path, 'dirB'))..createSync();
        final dirC = Directory(p.join(tempDir.path, 'dirC'))..createSync();
        final cutFile = File(p.join(dirA.path, 'moved.txt'))
          ..writeAsStringSync('hello');

        final settings = UserSettings(
          leftTabs: [PanelTab(id: 'left-1', path: dirA.path)],
          rightTabs: [PanelTab(id: 'right-1', path: dirB.path)],
        );

        final container = ProviderContainer(
          overrides: [
            fileSystemRepositoryProvider.overrideWithValue(
              CompoundFileSystemRepository(LocalFileSystemRepository()),
            ),
            settingsServiceProvider.overrideWithValue(
              _InMemorySettingsService(settings),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(userSettingsProvider.notifier).ensureLoaded();
        final leftTabId = container.read(panelTabsProvider('left')).activeTabId;
        final rightTabId = container
            .read(panelTabsProvider('right'))
            .activeTabId;
        await container
            .read(panelStateProvider(leftTabId).notifier)
            .loadPath(dirA.path);
        await container
            .read(panelStateProvider(rightTabId).notifier)
            .loadPath(dirB.path);

        final clipboard = container.read(clipboardActionsProvider);
        await clipboard.copyOrCut(
          leftTabId,
          ClipboardOperation.cut,
          explicitPaths: [cutFile.path],
        );

        // User switches Left panel away to dirC before pasting in Right panel.
        await container
            .read(panelStateProvider(leftTabId).notifier)
            .loadPath(dirC.path);

        await clipboard.paste(rightTabId);

        expect(File(p.join(dirB.path, 'moved.txt')).existsSync(), isTrue);
        expect(cutFile.existsSync(), isFalse);
        expect(
          container.read(panelStateProvider(leftTabId)).currentPath,
          dirC.path,
        );
        expect(
          container.read(panelStateProvider(rightTabId)).currentPath,
          dirB.path,
        );
      },
    );
  });
}
