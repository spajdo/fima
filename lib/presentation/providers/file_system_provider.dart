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

import 'package:fima/domain/entity/desktop_application.dart';

final fileSystemRepositoryProvider = Provider<FileSystemRepository>((ref) {
  return LocalFileSystemRepository();
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

  PanelController(this._repository, this._ref, this._panelId)
    : super(const PanelState());

  Future<void> init(String? initialPath) async {
    final path = initialPath ?? await _repository.getHomeDirectory();
    await loadPath(path, addToVisited: false);
  }

  Future<void> loadPath(
    String path, {
    bool addToVisited = true,
    String? selectItemPath,
    bool preserveFocusedIndex = false,
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

      int newFocusedIndex = _getFocusedIndex(
        sortedItems,
        selectItemPath,
        preserveFocusedIndex,
      );
      if (preserveFocusedIndex && state.focusedIndex < sortedItems.length) {
        newFocusedIndex = state.focusedIndex;
      }

      List<String> newVisitedPaths = List<String>.from(state.visitedPaths);
      if (addToVisited && path.isNotEmpty) {
        newVisitedPaths.add(path);
      }

      state = state.copyWith(
        currentPath: path,
        items: sortedItems,
        selectedItems: {},
        focusedIndex: newFocusedIndex,
        visitedPaths: newVisitedPaths,
      );

      _savePath(path);

      _ref.read(userSettingsProvider.notifier).indexPath(path);
    } catch (e) {
      debugPrint('Error loading path $path: $e');
    }
  }

  int _getFocusedIndex(
    List<FileSystemItem> sortedItems,
    String? selectItemPath,
    bool preserveFocusedIndex,
  ) {
    if (selectItemPath == null &&
        !preserveFocusedIndex &&
        state.visitedPaths.isNotEmpty) {
      selectItemPath = state.visitedPaths.last;
    }
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

  void enterFocusedItem() {
    if (state.items.isEmpty || state.focusedIndex >= state.items.length) return;
    final item = state.items[state.focusedIndex];
    if (item.isDirectory || item.isParentDetails) {
      if (item.isParentDetails) {
        navigateToParent();
      } else {
        loadPath(item.path, addToVisited: true);
      }
    } else {
      OpenFile.open(item.path);
    }
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
      await loadPath(state.currentPath);
      // Optional: Select the new directory?
    } catch (e) {
      debugPrint('Error creating directory: $e');
    }
  }

  Future<void> createFile(String name) async {
    try {
      final newPath = p.join(state.currentPath, name);
      await _repository.createFile(newPath);
      await loadPath(state.currentPath);
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
        await loadPath(state.currentPath);
      }
    } catch (e) {
      debugPrint('Error renaming item: $e');
    } finally {
      state = state.clearEditing();
    }
  }

  Future<void> deleteSelectedItems({required bool permanent}) async {
    final selectedPaths = state.selectedItems.toList();
    if (selectedPaths.isEmpty &&
        state.focusedIndex >= 0 &&
        state.focusedIndex < state.items.length) {
      // If no selection, delete focused item
      final item = state.items[state.focusedIndex];
      if (!item.isParentDetails) {
        selectedPaths.add(item.path);
      }
    }

    if (selectedPaths.isEmpty) return;

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

    // Refresh and clear selection
    await loadPath(state.currentPath);
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
