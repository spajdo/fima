import 'package:fima/domain/entity/file_system_item.dart';
import 'package:fima/domain/entity/panel_state.dart';
import 'package:fima/domain/repository/file_system_repository.dart';
import 'package:fima/infrastructure/repository/local_file_system_repository.dart';
import 'package:fima/presentation/providers/settings_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'dart:async';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:fima/domain/entity/desktop_application.dart';
import 'package:fima/domain/entity/panel_operation_progress.dart';
import 'package:fima/domain/entity/remote_connection.dart';

import 'package:fima/infrastructure/repository/compound_file_system_repository.dart';

final fileSystemRepositoryProvider = Provider<FileSystemRepository>((ref) {
  return CompoundFileSystemRepository(LocalFileSystemRepository());
});

final panelStateProvider =
    StateNotifierProvider.family<PanelController, PanelState, String>((
      ref,
      panelId,
    ) {
      return PanelController(
        ref.read(fileSystemRepositoryProvider),
        ref,
        panelId,
      );
    });

class PanelController extends StateNotifier<PanelState> {
  final FileSystemRepository _repository;
  final Ref _ref;
  final String _panelId;
  List<FileSystemItem> _allItems = [];

  PanelController(this._repository, this._ref, this._panelId)
    : super(const PanelState());

  Future<void> init(String? initialPath) async {
    final settings = _ref.read(userSettingsProvider);
    final isLeft = _panelId == 'left';
    final sortColIndex = isLeft
        ? settings.leftPanelSortColumn
        : settings.rightPanelSortColumn;
    final sortAscending = isLeft
        ? settings.leftPanelSortAscending
        : settings.rightPanelSortAscending;

    final sortColumn =
        sortColIndex >= 0 && sortColIndex < SortColumn.values.length
        ? SortColumn.values[sortColIndex]
        : SortColumn.name;

    state = state.copyWith(
      sortColumn: sortColumn,
      sortAscending: sortAscending,
    );

    final path = initialPath ?? await _repository.getHomeDirectory();
    await loadPath(path, addToVisited: false);
  }

  Future<void> loadPath(
    String path, {
    bool addToVisited = true,
    String? selectItemPath,
    bool preserveFocusedIndex = false,
    bool preserveSelection = false,
  }) async {
    try {
      final settings = _ref.read(userSettingsProvider);
      final items = await _repository.getItems(
        path,
        showHiddenFiles: settings.showHiddenFiles,
      );

      final sortedItems = _sortItems(
        items,
        state.sortColumn,
        state.sortAscending,
      );

      // Calculate new focused index
      int newFocusedIndex;
      if (preserveFocusedIndex &&
          state.focusedIndex >= 0 &&
          state.focusedIndex < state.items.length) {
        // Find focused item by path, not by index
        final focusedPath = state.items[state.focusedIndex].path;
        newFocusedIndex = sortedItems.indexWhere(
          (item) => item.path == focusedPath,
        );
        if (newFocusedIndex < 0) newFocusedIndex = 0;
      } else {
        newFocusedIndex = _getFocusedIndex(sortedItems, selectItemPath);
      }

      List<String> newVisitedPaths = List<String>.from(state.visitedPaths);
      if (addToVisited && path.isNotEmpty) {
        newVisitedPaths.add(path);
      }

      // Preserve selection by filtering selected paths that still exist
      Set<String> selectedItemsToUse = preserveSelection
          ? state.selectedItems
                .where((p) => sortedItems.any((item) => item.path == p))
                .toSet()
          : <String>{};

      state = state.copyWith(
        currentPath: path,
        items: sortedItems,
        selectedItems: preserveSelection ? selectedItemsToUse : {},
        focusedIndex: newFocusedIndex,
        visitedPaths: newVisitedPaths,
        quickFilterText: '',
      );

      _allItems = sortedItems;

      _savePath(path);

      _ref.read(userSettingsProvider.notifier).indexPath(path);
    } catch (e) {
      debugPrint('Error loading path $path: $e');
    }
  }

  int _getFocusedIndex(
    List<FileSystemItem> sortedItems,
    String? selectItemPath,
  ) {
    if (selectItemPath != null) {
      final index = sortedItems.indexWhere(
        (item) => item.path == selectItemPath,
      );
      return index >= 0 ? index : 0;
    }
    return 0;
  }

  Future<void> refresh() async {
    if (state.currentPath.isNotEmpty) {
      await loadPath(
        state.currentPath,
        addToVisited: false,
        selectItemPath: null,
        preserveFocusedIndex: true,
      );
    }
  }

  void _savePath(String path) {
    try {
      if (_panelId == 'left') {
        _ref.read(userSettingsProvider.notifier).setLeftPanelPath(path);
      } else if (_panelId == 'right') {
        _ref.read(userSettingsProvider.notifier).setRightPanelPath(path);
      }
    } catch (e) {
      debugPrint('Error saving path to settings: $e');
    }
  }

  Future<void> navigateToParent() async {
    if (state.currentPath.isEmpty) return;
    final parent = p.dirname(state.currentPath);
    if (parent != state.currentPath) {
      String? selectPath;
      if (state.visitedPaths.isNotEmpty) {
        selectPath = state.visitedPaths.removeLast();
      }
      await loadPath(parent, addToVisited: false, selectItemPath: selectPath);
    }
  }

  // We need to keep a reference to active file watchers so we can dispose them
  final Map<String, StreamSubscription> _activeFileWatchers = {};

  void enterFocusedItem() {
    if (state.items.isEmpty || state.focusedIndex >= state.items.length) return;
    final item = state.items[state.focusedIndex];
    if (item.isDirectory ||
        item.isParentDetails ||
        item.path.toLowerCase().endsWith('.zip')) {
      if (item.isParentDetails) {
        navigateToParent();
      } else {
        loadPath(item.path, addToVisited: true);
      }
    } else if (item.path.startsWith('ssh://')) {
      _openRemoteFileLocally(item.path);
    } else {
      OpenFile.open(item.path);
    }
  }

  /// Downloads a remote SSH file to a local temp dir and opens it with the
  /// system default application (e.g. VS Code for .log / .txt files).
  /// Also starts a background tail worker that polls the remote file every
  /// 2 seconds and appends new bytes to the local copy so the editor
  /// auto-reloads when the remote file grows.
  /// If the user modifies the local file, it triggers an upload back to the remote server.
  Future<void> _openRemoteFileLocally(String sshPath) async {
    try {
      final compound = _repository;
      if (compound is! CompoundFileSystemRepository) return;

      final connId = RemoteConnection.connectionIdFromSshUrl(sshPath);
      final remotePath = RemoteConnection.remotePathFromSshUrl(sshPath);
      final fileName = remotePath.split('/').last;

      // Build a stable temp path that mirrors the remote structure.
      final tmpDir = Directory(
        '/tmp/fima_ssh/$connId${remotePath.substring(0, remotePath.length - fileName.length)}',
      );
      await tmpDir.create(recursive: true);

      final localPath = '${tmpDir.path}$fileName';
      final file = File(localPath);

      // Cancel existing watcher if any
      await _activeFileWatchers[sshPath]?.cancel();
      _activeFileWatchers.remove(sshPath);

      // Download the initial snapshot and get its byte length.
      var currentSize = await compound.sshRepository.downloadToLocal(
        sshPath,
        localPath,
      );

      final sftp = compound.sshRepository.getSftpClientFor(connId);
      if (sftp == null) return;

      // Start live-tail: poll every 2 s, append new bytes to local file.
      void startTailing() {
        compound.sshRepository.tailService.startTailing(
          sftp: sftp,
          sshPath: sshPath,
          remotePath: remotePath,
          localPath: localPath,
          initialSize: currentSize,
        );
      }

      startTailing();

      // Watch local file for user modifications
      bool isUploading = false;

      final watcher = file.watch().listen((event) async {
        if (isUploading) return;

        // Wait a tiny bit to debounce rapid save events from editors
        await Future.delayed(const Duration(milliseconds: 100));

        try {
          // Suspend tailing while we upload
          isUploading = true;
          compound.sshRepository.tailService.stopTailing(sshPath);

          // Upload the file back to the remote server
          debugPrint('Local file edited, uploading to remote: $sshPath');
          await compound.sshRepository.uploadFromLocal(localPath, sshPath);

          // Re-measure after upload and resume tailing
          currentSize = await file.length();
          startTailing();
        } catch (e) {
          debugPrint('Error uploading edited file: $e');
        } finally {
          isUploading = false;
        }
      });
      _activeFileWatchers[sshPath] = watcher;

      // Open in the system default app — VS Code for text/log files.
      await OpenFile.open(localPath);
    } catch (e) {
      debugPrint('Error opening remote file locally: $e');
    }
  }

  @override
  void dispose() {
    for (var watcher in _activeFileWatchers.values) {
      watcher.cancel();
    }
    _activeFileWatchers.clear();
    super.dispose();
  }

  /// Navigate this panel to the SSH server's root directory.
  Future<void> loadSshPath(RemoteConnection connection) async {
    final sshPath = connection.buildPath('/');
    await loadPath(sshPath, addToVisited: false);
  }

  /// Disconnect a remote SSH session and navigate back to local home.
  Future<void> disconnectSsh() async {
    final compound = _repository;
    if (compound is! CompoundFileSystemRepository) return;

    // Auto-stop all file tailing for all connections on disconnect
    // Usually disconnectSsh handles the active connection for this panel.
    final currentPath = state.currentPath;
    if (currentPath.startsWith('ssh://')) {
      final connId = RemoteConnection.connectionIdFromSshUrl(currentPath);
      compound.sshRepository.disconnect(connId);

      // Also stop active watchers for this connection
      final keysToRemove = _activeFileWatchers.keys
          .where((k) => k.startsWith('ssh://$connId'))
          .toList();
      for (final k in keysToRemove) {
        _activeFileWatchers[k]?.cancel();
        _activeFileWatchers.remove(k);
      }
    }

    final homeDir =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '/';
    await loadPath(homeDir, addToVisited: true);
  }

  void toggleSelection(String path) {
    final newSelection = Set<String>.from(state.selectedItems);
    if (newSelection.contains(path)) {
      newSelection.remove(path);
    } else {
      newSelection.add(path);
    }
    state = state.copyWith(selectedItems: newSelection);
  }

  void selectItem(String path, {bool clearOthers = true}) {
    // Selection logic moved to separate "Mark" functionality (Space key)
    // Clicking/Navigating now only moves focus, unless specifically requested.
    // For compatibility with single-click selection if needed in future:
    /*
     if (clearOthers) {
       state = state.copyWith(selectedItems: {path});
     } else {
       toggleSelection(path);
     }
     */
  }

  void sort(SortColumn column) {
    final ascending = state.sortColumn == column ? !state.sortAscending : true;
    final sortedItems = _sortItems(state.items, column, ascending);
    state = state.copyWith(
      sortColumn: column,
      sortAscending: ascending,
      items: sortedItems,
    );

    // Persist sort preference to settings
    if (_panelId == 'left') {
      _ref
          .read(userSettingsProvider.notifier)
          .setLeftPanelSort(column.index, ascending);
    } else if (_panelId == 'right') {
      _ref
          .read(userSettingsProvider.notifier)
          .setRightPanelSort(column.index, ascending);
    }

    // Update _allItems with the new sort order
    if (state.quickFilterText.isEmpty) {
      _allItems = sortedItems;
    } else {
      _allItems = _sortItems(_allItems, column, ascending);
      // Re-apply the filter
      setQuickFilter(state.quickFilterText);
    }
  }

  void setQuickFilter(String text) {
    final lowerText = text.toLowerCase();
    final filtered = _allItems.where((item) {
      if (item.isParentDetails) return true;
      return item.name.toLowerCase().startsWith(lowerText);
    }).toList();

    // Find best match: exact match first, then shortest name
    int bestIndex = -1;
    int bestLength = -1;
    for (int i = 0; i < filtered.length; i++) {
      final item = filtered[i];
      if (item.isParentDetails) continue;
      final lowerName = item.name.toLowerCase();
      if (lowerName == lowerText) {
        bestIndex = i;
        break;
      }
      if (bestIndex == -1 || item.name.length < bestLength) {
        bestIndex = i;
        bestLength = item.name.length;
      }
    }

    state = state.copyWith(
      quickFilterText: text,
      items: filtered,
      focusedIndex: bestIndex >= 0 ? bestIndex : (filtered.isNotEmpty ? 0 : -1),
    );
  }

  void clearQuickFilter() {
    // Preserve the currently focused item
    int newIndex = 0;
    if (state.focusedIndex >= 0 && state.focusedIndex < state.items.length) {
      final focusedPath = state.items[state.focusedIndex].path;
      final idx = _allItems.indexWhere((item) => item.path == focusedPath);
      if (idx >= 0) newIndex = idx;
    }

    state = state.copyWith(
      quickFilterText: '',
      items: _allItems,
      focusedIndex: newIndex,
    );
  }

  List<FileSystemItem> _sortItems(
    List<FileSystemItem> items,
    SortColumn column,
    bool ascending,
  ) {
    final parentItem = items.where((i) => i.isParentDetails).toList();
    final directories = items
        .where((i) => i.isDirectory && !i.isParentDetails)
        .toList();
    final files = items
        .where((i) => !i.isDirectory && !i.isParentDetails)
        .toList();

    int compare(FileSystemItem a, FileSystemItem b) {
      int result;
      switch (column) {
        case SortColumn.name:
          result = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case SortColumn.size:
          result = a.size.compareTo(b.size);
          break;
        case SortColumn.modified:
          result = a.modified.compareTo(b.modified);
          break;
      }
      return ascending ? result : -result;
    }

    directories.sort(compare);
    files.sort(compare);

    return [...parentItem, ...directories, ...files];
  }

  // Keyboard navigation methods
  void moveSelectionUp() {
    if (state.items.isEmpty) return;
    final newIndex = (state.focusedIndex - 1).clamp(0, state.items.length - 1);
    state = state.copyWith(focusedIndex: newIndex);
    // Focus only, no selection update
  }

  void moveSelectionDown() {
    if (state.items.isEmpty) return;
    final newIndex = (state.focusedIndex + 1).clamp(0, state.items.length - 1);
    state = state.copyWith(focusedIndex: newIndex);
    // Focus only, no selection update
  }

  void moveToFirst() {
    if (state.items.isEmpty) return;
    state = state.copyWith(focusedIndex: 0);
    // Focus only, no selection update
  }

  void moveToLast() {
    if (state.items.isEmpty) return;
    final lastIndex = state.items.length - 1;
    state = state.copyWith(focusedIndex: lastIndex);
    // Focus only, no selection update
  }

  void toggleSelectionAtFocus() {
    if (state.focusedIndex < 0 || state.focusedIndex >= state.items.length) {
      return;
    }
    final item = state.items[state.focusedIndex];
    toggleSelection(item.path);
  }

  void selectAll() {
    final allPaths = state.items
        .where((item) => !item.isParentDetails)
        .map((item) => item.path)
        .toSet();
    state = state.copyWith(selectedItems: allPaths);
  }

  void deselectAll() {
    state = state.copyWith(selectedItems: {});
  }

  void setFocusedIndex(int index) {
    if (index >= -1 && index < state.items.length) {
      state = state.copyWith(focusedIndex: index);
    }
  }

  Future<void> createDirectory(String name) async {
    try {
      final newPath = p.join(state.currentPath, name);
      await _repository.createDirectory(newPath);
      await loadPath(state.currentPath, selectItemPath: newPath);
    } catch (e) {
      debugPrint('Error creating directory: $e');
    }
  }

  Future<void> createFile(String name) async {
    try {
      final newPath = p.join(state.currentPath, name);
      await _repository.createFile(newPath);
      await loadPath(state.currentPath, selectItemPath: newPath);
    } catch (e) {
      debugPrint('Error creating file: $e');
    }
  }

  void startRenaming() {
    if (state.focusedIndex >= 0 && state.focusedIndex < state.items.length) {
      final item = state.items[state.focusedIndex];
      if (!item.isParentDetails) {
        state = state.copyWith(editingPath: item.path);
      }
    }
  }

  void cancelRenaming() {
    state = state.clearEditing();
  }

  Future<void> renameItem(String newName) async {
    final editingPath = state.editingPath;
    if (editingPath == null) return;

    try {
      final parent = p.dirname(editingPath);
      final newPath = p.join(parent, newName);
      if (newPath != editingPath) {
        await _repository.renameItem(editingPath, newPath);
        await loadPath(state.currentPath, selectItemPath: newPath);
      }
    } catch (e) {
      debugPrint('Error renaming item: $e');
    } finally {
      state = state.clearEditing();
    }
  }

  Future<void> deleteSelectedItems({required bool permanent}) async {
    final selectedPaths = state.selectedItems.toList();
    int targetIndex = -1;

    if (selectedPaths.isEmpty &&
        state.focusedIndex >= 0 &&
        state.focusedIndex < state.items.length) {
      // If no selection, delete focused item
      final item = state.items[state.focusedIndex];
      if (!item.isParentDetails) {
        selectedPaths.add(item.path);
        targetIndex = state.focusedIndex;
      }
    } else if (selectedPaths.isNotEmpty) {
      // Find the highest index among selected items
      for (final path in selectedPaths) {
        final idx = state.items.indexWhere((item) => item.path == path);
        if (idx > targetIndex) targetIndex = idx;
      }
    }

    if (selectedPaths.isEmpty) return;

    // Build list of items that will remain after deletion
    final remainingItems = state.items
        .where((item) => !selectedPaths.contains(item.path))
        .toList();

    // Determine which item to select after deletion
    String? selectPath;
    if (remainingItems.isNotEmpty) {
      // If targetIndex is beyond remaining items, select last one
      final newTargetIndex = targetIndex >= remainingItems.length
          ? remainingItems.length - 1
          : targetIndex;
      if (newTargetIndex >= 0 && newTargetIndex < remainingItems.length) {
        selectPath = remainingItems[newTargetIndex].path;
      }
    }

    // Perform deletion
    for (final path in selectedPaths) {
      try {
        if (permanent) {
          await _repository.deleteItem(path);
        } else {
          await _repository.moveToTrash(path);
        }
      } catch (e) {
        debugPrint('Error deleting $path: $e');
      }
    }

    await loadPath(state.currentPath, selectItemPath: selectPath);
  }

  Future<void> extractArchive(String zipPath, String destinationPath) async {
    final receivePort = ReceivePort();
    try {
      await Isolate.spawn(_isolateExtractArchive, {
        'sendPort': receivePort.sendPort,
        'zipPath': zipPath,
        'destinationPath': destinationPath,
      });

      await for (final message in receivePort) {
        if (message == null) {
          // Completion
          break;
        } else if (message is Map<String, dynamic>) {
          if (message.containsKey('error')) {
            debugPrint('Error extracting zip: ${message['error']}');
            break;
          } else {
            state = state.copyWith(
              operationProgress: PanelOperationProgress(
                operationName: message['operationName'],
                progress: message['progress'],
                currentItem: message['currentItem'],
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error launching isolate: $e');
    } finally {
      receivePort.close();
      state = state.copyWith(clearOperationProgress: true);
    }
  }

  Future<void> compressItems(
    List<String> paths,
    String destinationZipName,
  ) async {
    final receivePort = ReceivePort();
    final zipPath = p.join(state.currentPath, destinationZipName);

    try {
      await Isolate.spawn(_isolateCompressItems, {
        'sendPort': receivePort.sendPort,
        'paths': paths,
        'zipPath': zipPath,
        'basePath': state.currentPath,
      });

      await for (final message in receivePort) {
        if (message == null) {
          break;
        } else if (message is Map<String, dynamic>) {
          if (message.containsKey('error')) {
            debugPrint('Error creating zip: ${message['error']}');
            break;
          } else {
            state = state.copyWith(
              operationProgress: PanelOperationProgress(
                operationName: message['operationName'],
                progress: message['progress'],
                currentItem: message['currentItem'],
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error launching isolate: $e');
    } finally {
      receivePort.close();
      state = state.copyWith(clearOperationProgress: true);
    }
  }

  Future<void> openTerminal(String path) async {
    // Linux generic way to open terminal
    // Try generic emulator first, then specific ones
    if (Platform.isLinux) {
      try {
        // Try x-terminal-emulator first (Debian/Ubuntu/standard alternative)
        await Process.run('x-terminal-emulator', [], workingDirectory: path);
      } catch (e) {
        // Fallbacks
        final terminals = [
          'gnome-terminal',
          'konsole',
          'xfce4-terminal',
          'mate-terminal',
          'terminator',
          'xterm',
        ];
        for (final terminal in terminals) {
          try {
            // Most terminals accept working directory as is or need --working-directory
            // But Process.run workingDirectory argument usually handles it if the terminal respects cwd
            // For gnome-terminal we might need more arguments?
            // Process.run usually works.
            await Process.run(terminal, [], workingDirectory: path);
            return; // Success
          } catch (_) {
            // Continue to next
          }
        }
        debugPrint('Could not find a supported terminal to open.');
      }
    } else if (Platform.isMacOS) {
      // Mac implementation
      try {
        await Process.run('open', ['-a', 'Terminal', path]);
      } catch (e) {
        debugPrint('Error opening Mac terminal: $e');
      }
    } else if (Platform.isWindows) {
      // Windows implementation
      try {
        await Process.run('cmd', [
          '/K',
          'start',
          'cd',
          '/d',
          path,
        ], runInShell: true);
      } catch (e) {
        debugPrint('Error opening Windows terminal: $e');
      }
    }
  }

  Future<void> openFileManager(String path) async {
    if (Platform.isLinux) {
      try {
        await Process.run('xdg-open', [path]);
      } catch (e) {
        debugPrint('Error opening file manager on Linux: $e');
      }
    } else if (Platform.isMacOS) {
      try {
        await Process.run('open', [path]);
      } catch (e) {
        debugPrint('Error opening file manager on macOS: $e');
      }
    } else if (Platform.isWindows) {
      try {
        await Process.run('explorer', [path]);
      } catch (e) {
        debugPrint('Error opening file manager on Windows: $e');
      }
    }
  }

  Future<void> openWithApplication(DesktopApplication app, String path) async {
    if (Platform.isLinux) {
      try {
        final command = _buildCommand(app.exec, path);
        await Process.start(command[0], command.sublist(1), runInShell: true);
      } catch (e) {
        debugPrint('Error opening with application on Linux: $e');
      }
    } else if (Platform.isMacOS) {
      try {
        await Process.run('open', ['-a', app.exec, path]);
      } catch (e) {
        debugPrint('Error opening with application on macOS: $e');
      }
    } else if (Platform.isWindows) {
      try {
        final command = _buildCommand(app.exec, path);
        await Process.start(command[0], command.sublist(1), runInShell: true);
      } catch (e) {
        debugPrint('Error opening with application on Windows: $e');
      }
    }
  }

  List<String> _buildCommand(String exec, String path) {
    final parts = exec.split(' ');
    final result = <String>[];
    for (final part in parts) {
      if (part.isEmpty) continue;
      final replaced = _replaceExecParams(part, path);
      result.add(replaced);
    }
    return result;
  }

  String _replaceExecParams(String exec, String path) {
    String result = exec;
    final params = ['%F', '%f', '%U', '%u', '%D', '%d', '%N', '%n'];
    for (final param in params) {
      result = result.replaceAll(param, path);
    }
    return result;
  }
}

class _FileEntry {
  final String absolutePath;
  final String archivePath;
  _FileEntry(this.absolutePath, this.archivePath);
}

void _isolateExtractArchive(Map<String, dynamic> args) {
  final sendPort = args['sendPort'] as SendPort;
  final zipPath = args['zipPath'] as String;
  final destinationPath = args['destinationPath'] as String;

  try {
    final bytes = File(zipPath).readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);

    int totalFiles = archive.length;
    int processedFiles = 0;

    for (final file in archive) {
      if (file.isFile) {
        final filename = file.name;
        final data = file.content as List<int>;
        final destFile = File(p.join(destinationPath, filename));
        destFile.createSync(recursive: true);
        destFile.writeAsBytesSync(data);
      } else {
        Directory(
          p.join(destinationPath, file.name),
        ).createSync(recursive: true);
      }
      processedFiles++;
      sendPort.send({
        'operationName': 'Extracting',
        'progress': processedFiles / totalFiles,
        'currentItem': p.basename(file.name),
      });
    }
    sendPort.send(null);
  } catch (e) {
    sendPort.send({'error': e.toString()});
  }
}

void _isolateCompressItems(Map<String, dynamic> args) {
  final sendPort = args['sendPort'] as SendPort;
  _isolateCompressItemsAsync(args).then((_) {}).catchError((e) {
    sendPort.send({'error': e.toString()});
  });
}

Future<void> _isolateCompressItemsAsync(Map<String, dynamic> args) async {
  final sendPort = args['sendPort'] as SendPort;
  final paths = args['paths'] as List<String>;
  final zipPath = args['zipPath'] as String;
  final basePath = args['basePath'] as String;

  int totalFiles = 0;
  final fileEntries = <_FileEntry>[];

  for (final path in paths) {
    final stat = FileStat.statSync(path);
    if (stat.type == FileSystemEntityType.directory) {
      final dir = Directory(path);
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is File) {
          totalFiles++;
          final archivePath = p.relative(entity.path, from: basePath);
          fileEntries.add(_FileEntry(entity.path, archivePath));
        }
      }
    } else if (stat.type == FileSystemEntityType.file) {
      totalFiles++;
      final archivePath = p.relative(path, from: basePath);
      fileEntries.add(_FileEntry(path, archivePath));
    }
  }

  final encoder = ZipFileEncoder();
  encoder.create(zipPath);

  if (totalFiles == 0) {
    await encoder.close();
    sendPort.send(null);
    return;
  }

  int processedFiles = 0;
  for (final entry in fileEntries) {
    await encoder.addFile(File(entry.absolutePath), entry.archivePath);
    processedFiles++;
    sendPort.send({
      'operationName': 'Compressing',
      'progress': processedFiles / totalFiles,
      'currentItem': p.basename(entry.absolutePath),
    });
  }

  await encoder.close();
  sendPort.send(null);
}
