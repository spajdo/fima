import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:fima/domain/entity/desktop_application.dart';
import 'package:fima/domain/entity/file_system_item.dart';
import 'package:fima/domain/entity/panel_state.dart';
import 'package:fima/domain/entity/remote_connection.dart';
import 'package:fima/domain/repository/file_system_repository.dart';
import 'package:fima/domain/utils/file_item_sorter.dart';
import 'package:fima/domain/utils/fima_path.dart';
import 'package:fima/infrastructure/repository/compound_file_system_repository.dart';
import 'package:fima/infrastructure/repository/local_file_system_repository.dart';
import 'package:fima/infrastructure/service/archive_service.dart';
import 'package:fima/infrastructure/service/desktop_integration_service.dart';
import 'package:fima/infrastructure/service/item_metadata_service.dart';
import 'package:fima/infrastructure/service/remote_file_edit_service.dart';
import 'package:fima/presentation/providers/panel_tabs_provider.dart';
import 'package:fima/presentation/providers/settings_provider.dart';

final fileSystemRepositoryProvider = Provider<FileSystemRepository>((ref) {
  return CompoundFileSystemRepository(LocalFileSystemRepository());
});

final archiveServiceProvider = Provider<ArchiveService>((ref) {
  return const ArchiveService();
});

final desktopIntegrationServiceProvider = Provider<DesktopIntegrationService>((
  ref,
) {
  return const DesktopIntegrationService();
});

final panelStateProvider =
    StateNotifierProvider.family<PanelController, PanelState, String>((
      ref,
      tabId,
    ) {
      return PanelController(
        ref.read(fileSystemRepositoryProvider),
        ref,
        tabId,
      );
    });

class PanelController extends StateNotifier<PanelState> {
  final FileSystemRepository _repository;
  final Ref _ref;
  final String _tabId;
  String? _panelId;
  bool? _loadedShowHiddenFiles;
  List<FileSystemItem> _allItems = [];
  int _loadGeneration = 0;
  final RemoteFileEditService _remoteEditService;

  PanelController(this._repository, this._ref, this._tabId)
    : _remoteEditService = RemoteFileEditService(
        _ref.read(desktopIntegrationServiceProvider),
      ),
      super(const PanelState());

  bool get needsHiddenFilesRefresh =>
      _loadedShowHiddenFiles != null &&
      _loadedShowHiddenFiles != _ref.read(userSettingsProvider).showHiddenFiles;

  SortColumn _resolveSortColumn(int sortColIndex) {
    return sortColIndex >= 0 && sortColIndex < SortColumn.values.length
        ? SortColumn.values[sortColIndex]
        : SortColumn.name;
  }

  /// Sets initial SSH path and sort metadata on a tab before the connection is
  /// established so the UI shows the connection header while authenticating.
  void primeSshTabState({
    required String panelId,
    required String sshPath,
    required int sortColumn,
    required bool sortAscending,
  }) {
    _panelId = panelId;
    state = state.copyWith(
      currentPath: sshPath,
      sortColumn: _resolveSortColumn(sortColumn),
      sortAscending: sortAscending,
    );
  }

  Future<void> initTab({
    required String panelId,
    String? initialPath,
    int sortColumn = 0,
    bool sortAscending = true,
  }) async {
    _panelId = panelId;
    state = state.copyWith(
      sortColumn: _resolveSortColumn(sortColumn),
      sortAscending: sortAscending,
    );

    final path = (initialPath != null && initialPath.isNotEmpty)
        ? initialPath
        : await _repository.getHomeDirectory();
    await loadPath(path, addToVisited: false);
  }

  Future<void> loadPath(
    String path, {
    bool addToVisited = true,
    String? selectItemPath,
    bool preserveFocusedIndex = false,
    bool preserveSelection = false,
    bool recordVisit = true,
  }) async {
    final generation = ++_loadGeneration;
    try {
      final settings = _ref.read(userSettingsProvider);
      final items = await _repository.getItems(
        path,
        showHiddenFiles: settings.showHiddenFiles,
      );
      if (!mounted || generation != _loadGeneration) return;

      _applyLoadedItems(
        path,
        items,
        addToVisited: addToVisited,
        selectItemPath: selectItemPath,
        preserveFocusedIndex: preserveFocusedIndex,
        preserveSelection: preserveSelection,
        recordVisit: recordVisit,
      );
    } catch (e) {
      debugPrint('Error loading path $path: $e');
    }
  }

  /// Validates [rawPath] and navigates to it, returning an error message if
  /// the directory does not exist or cannot be read, or `null` on success.
  Future<String?> navigateToPath(String rawPath) async {
    final trimmed = rawPath.trim();
    if (trimmed.isEmpty) {
      return 'Path cannot be empty';
    }
    if (trimmed.startsWith('ssh://')) {
      return 'Directory does not exist: $trimmed';
    }

    String expanded = trimmed;
    if (trimmed == '~' ||
        trimmed.startsWith('~/') ||
        (Platform.isWindows && trimmed.startsWith('~\\'))) {
      final home =
          Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      if (home != null && home.isNotEmpty) {
        expanded = trimmed.length == 1
            ? home
            : p.join(home, trimmed.substring(2));
      }
    }

    final normalizedPath = p.normalize(expanded);
    final generation = ++_loadGeneration;
    try {
      final settings = _ref.read(userSettingsProvider);
      final items = await _repository.getItems(
        normalizedPath,
        showHiddenFiles: settings.showHiddenFiles,
      );
      if (!mounted || generation != _loadGeneration) return null;
      _applyLoadedItems(normalizedPath, items);
      return null;
    } on PathAccessException {
      return 'Access denied: Cannot read directory';
    } on FileSystemException catch (e) {
      final code = e.osError?.errorCode;
      if (code == 13 || code == 1) {
        return 'Access denied: Cannot read directory';
      }
      return 'Directory does not exist: $normalizedPath';
    } catch (_) {
      return 'Directory does not exist: $normalizedPath';
    }
  }

  void startEditingPath() {
    if (state.currentPath.startsWith('ssh://')) return;
    state = state.copyWith(isEditingPath: true);
  }

  void stopEditingPath() {
    if (state.isEditingPath) {
      state = state.copyWith(isEditingPath: false);
    }
  }

  void _applyLoadedItems(
    String path,
    List<FileSystemItem> items, {
    bool addToVisited = true,
    String? selectItemPath,
    bool preserveFocusedIndex = false,
    bool preserveSelection = false,
    bool recordVisit = true,
  }) {
    final nextDirectorySizes = path == state.currentPath
        ? Map<String, int>.from(state.directorySizes)
        : <String, int>{};

    final sortedItems = _sortItems(
      items,
      state.sortColumn,
      state.sortAscending,
      directorySizes: nextDirectorySizes,
    );

    int newFocusedIndex;
    if (preserveFocusedIndex &&
        state.focusedIndex >= 0 &&
        state.focusedIndex < state.items.length) {
      final focusedPath = state.items[state.focusedIndex].path;
      newFocusedIndex = sortedItems.indexWhere(
        (item) => item.path == focusedPath,
      );
      if (newFocusedIndex < 0) newFocusedIndex = 0;
    } else {
      newFocusedIndex = _getFocusedIndex(sortedItems, selectItemPath);
    }

    final newVisitedPaths = List<String>.from(state.visitedPaths);
    if (addToVisited && path.isNotEmpty) {
      newVisitedPaths.add(path);
    }

    final selectedItemsToUse = preserveSelection
        ? state.selectedItems
              .where((p) => sortedItems.any((item) => item.path == p))
              .toSet()
        : <String>{};

    state = state.copyWith(
      currentPath: path,
      items: sortedItems,
      selectedItems: preserveSelection ? selectedItemsToUse : {},
      focusedIndex: newFocusedIndex,
      isEditingPath: false,
      visitedPaths: newVisitedPaths,
      quickFilterText: '',
      directorySizes: nextDirectorySizes,
      calculatingDirectories: path == state.currentPath
          ? state.calculatingDirectories
          : const {},
    );

    _allItems = sortedItems;
    _loadedShowHiddenFiles = _ref.read(userSettingsProvider).showHiddenFiles;

    _savePath(path);

    if (recordVisit) {
      _ref.read(userSettingsProvider.notifier).indexPath(path);
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
        recordVisit: false,
      );
    }
  }

  void _savePath(String path) {
    try {
      if (_panelId != null) {
        _ref
            .read(panelTabsProvider(_panelId!).notifier)
            .updateTabPath(_tabId, path);
      }
    } catch (e) {
      debugPrint('Error saving path to tab settings: $e');
    }
  }

  Future<void> navigateToParent() async {
    if (state.currentPath.isEmpty) return;
    final parent = FimaPath.dirname(state.currentPath);
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
    if (item.isDirectory ||
        item.isParentDetails ||
        item.path.toLowerCase().endsWith('.zip')) {
      if (item.isParentDetails) {
        navigateToParent();
      } else {
        loadPath(item.path, addToVisited: true);
      }
    } else if (FimaPath.isSshPath(item.path)) {
      _remoteEditService.openRemoteFileLocally(_repository, item.path);
    } else {
      _ref.read(desktopIntegrationServiceProvider).openFile(item.path);
    }
  }

  @override
  void dispose() {
    _remoteEditService.dispose();
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

    final currentPath = state.currentPath;
    if (FimaPath.isSshPath(currentPath)) {
      final connId = RemoteConnection.connectionIdFromSshUrl(currentPath);
      compound.sshRepository.disconnect(connId);
      _remoteEditService.disposeForConnection(connId);
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
    if (clearOthers) {
      selectItemOnly(path);
    } else {
      toggleSelection(path);
    }
  }

  /// Clears existing selection and selects only the item at [path].
  void selectItemOnly(String path) {
    state = state.copyWith(selectedItems: {path});
  }

  /// Adds items between [fromIndex] and [toIndex] (inclusive) to the current
  /// selection without clearing items that are already selected outside the range.
  void selectRange(int fromIndex, int toIndex) {
    if (state.items.isEmpty) return;
    final lo = fromIndex.clamp(0, state.items.length - 1);
    final hi = toIndex.clamp(0, state.items.length - 1);
    final start = lo < hi ? lo : hi;
    final end = lo < hi ? hi : lo;
    final newSelection = Set<String>.from(state.selectedItems);
    for (int i = start; i <= end; i++) {
      final item = state.items[i];
      if (!item.isParentDetails) {
        newSelection.add(item.path);
      }
    }
    state = state.copyWith(selectedItems: newSelection);
  }

  void sort(SortColumn column) {
    final ascending = state.sortColumn == column ? !state.sortAscending : true;
    final sortedItems = _sortItems(
      state.items,
      column,
      ascending,
      directorySizes: state.directorySizes,
    );
    state = state.copyWith(
      sortColumn: column,
      sortAscending: ascending,
      items: sortedItems,
    );

    // Persist sort preference for this tab
    if (_panelId != null) {
      _ref
          .read(panelTabsProvider(_panelId!).notifier)
          .updateTabSort(_tabId, column.index, ascending);
    }

    // Update _allItems with the new sort order
    if (state.quickFilterText.isEmpty) {
      _allItems = sortedItems;
    } else {
      _allItems = _sortItems(
        _allItems,
        column,
        ascending,
        directorySizes: state.directorySizes,
      );
      // Re-apply the filter
      setQuickFilter(state.quickFilterText);
    }
  }

  void setQuickFilter(String text) {
    final (filtered, resolvedIndex) = FileItemSorter.filterByPrefix(
      _allItems,
      text,
    );

    state = state.copyWith(
      quickFilterText: text,
      items: filtered,
      focusedIndex: resolvedIndex,
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
    bool ascending, {
    Map<String, int> directorySizes = const {},
  }) {
    return FileItemSorter.sortItems(
      items,
      column,
      ascending,
      directorySizes: directorySizes,
    );
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
    if (item.isDirectory && !item.isParentDetails) {
      unawaited(calculateDirectorySize(item.path));
    }
  }

  /// Calculates the recursive size of the directory at [dirPath] in a
  /// background isolate and caches it in [PanelState.directorySizes].
  Future<void> calculateDirectorySize(String dirPath) async {
    if (dirPath.isEmpty || dirPath.startsWith('ssh://')) return;
    if (state.calculatingDirectories.contains(dirPath)) return;

    final startPath = state.currentPath;
    final nextCalc = Set<String>.from(state.calculatingDirectories)
      ..add(dirPath);
    state = state.copyWith(calculatingDirectories: nextCalc);

    try {
      final totalBytes = await ItemMetadataService.calculateSingleDirectorySize(
        dirPath,
      );
      if (!mounted || state.currentPath != startPath) return;

      final nextSizes = Map<String, int>.from(state.directorySizes)
        ..[dirPath] = totalBytes;
      final doneCalc = Set<String>.from(state.calculatingDirectories)
        ..remove(dirPath);

      var updatedItems = state.items;
      if (state.sortColumn == SortColumn.size) {
        _allItems = _sortItems(
          _allItems,
          state.sortColumn,
          state.sortAscending,
          directorySizes: nextSizes,
        );
        updatedItems = _sortItems(
          state.items,
          state.sortColumn,
          state.sortAscending,
          directorySizes: nextSizes,
        );
      }

      state = state.copyWith(
        directorySizes: nextSizes,
        calculatingDirectories: doneCalc,
        items: updatedItems,
      );
    } catch (e) {
      debugPrint('Error calculating directory size for $dirPath: $e');
      if (!mounted || state.currentPath != startPath) return;
      final doneCalc = Set<String>.from(state.calculatingDirectories)
        ..remove(dirPath);
      state = state.copyWith(calculatingDirectories: doneCalc);
    }
  }

  /// Calculates recursive sizes for all directories currently listed in the panel.
  Future<void> calculateAllDirectorySizes() async {
    if (state.currentPath.isEmpty || state.currentPath.startsWith('ssh://')) {
      return;
    }
    final dirs = state.items
        .where((item) => item.isDirectory && !item.isParentDetails)
        .map((item) => item.path)
        .toList();
    if (dirs.isEmpty) return;

    for (final dirPath in dirs) {
      if (!mounted) return;
      await calculateDirectorySize(dirPath);
    }
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

  bool _isValidEntryName(String name) {
    final trimmed = name.trim();
    return trimmed.isNotEmpty &&
        trimmed != '.' &&
        trimmed != '..' &&
        !trimmed.contains('/') &&
        !trimmed.contains('\\');
  }

  Future<void> createDirectory(String name) async {
    final cleanName = name.trim();
    if (!_isValidEntryName(cleanName)) return;
    try {
      final newPath = FimaPath.join(state.currentPath, cleanName);
      await _repository.createDirectory(newPath);
      await loadPath(
        state.currentPath,
        selectItemPath: newPath,
        recordVisit: false,
      );
    } catch (e) {
      debugPrint('Error creating directory: $e');
    }
  }

  Future<void> createFile(String name) async {
    final cleanName = name.trim();
    if (!_isValidEntryName(cleanName)) return;
    try {
      final newPath = FimaPath.join(state.currentPath, cleanName);
      await _repository.createFile(newPath);
      await loadPath(
        state.currentPath,
        selectItemPath: newPath,
        recordVisit: false,
      );
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

    final cleanName = newName.trim();
    if (!_isValidEntryName(cleanName)) {
      state = state.clearEditing();
      return;
    }

    try {
      final parent = FimaPath.dirname(editingPath);
      final newPath = FimaPath.join(parent, cleanName);
      if (newPath != editingPath) {
        await _repository.renameItem(editingPath, newPath);
        await loadPath(
          state.currentPath,
          selectItemPath: newPath,
          recordVisit: false,
        );
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
    try {
      await for (final progress
          in _ref
              .read(archiveServiceProvider)
              .extractArchive(zipPath, destinationPath)) {
        state = state.copyWith(operationProgress: progress);
      }
    } finally {
      state = state.copyWith(clearOperationProgress: true);
    }
  }

  Future<void> compressItems(
    List<String> paths,
    String destinationZipName,
  ) async {
    final zipPath = FimaPath.join(state.currentPath, destinationZipName);
    try {
      await for (final progress
          in _ref
              .read(archiveServiceProvider)
              .compressItems(paths, zipPath, state.currentPath)) {
        state = state.copyWith(operationProgress: progress);
      }
    } finally {
      state = state.copyWith(clearOperationProgress: true);
    }
  }

  Future<void> openTerminal(String path) =>
      _ref.read(desktopIntegrationServiceProvider).openTerminal(path);

  Future<void> openFileManager(String path) =>
      _ref.read(desktopIntegrationServiceProvider).openFileManager(path);

  Future<void> revealInFileManager(String path, {required bool isDirectory}) =>
      _ref
          .read(desktopIntegrationServiceProvider)
          .revealInFileManager(path, isDirectory: isDirectory);

  Future<void> openWithApplication(DesktopApplication app, String path) => _ref
      .read(desktopIntegrationServiceProvider)
      .openWithApplication(app, path);
}
