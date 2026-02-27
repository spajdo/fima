import 'package:fima/domain/entity/key_map_action.dart';
import 'package:fima/domain/entity/path_index_entry.dart';
import 'package:fima/domain/entity/remote_connection.dart';
import 'package:fima/domain/entity/user_settings.dart';
import 'package:fima/domain/entity/workspace.dart';
import 'package:fima/infrastructure/service/settings_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Settings service provider
final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService();
});

// User settings state provider
final userSettingsProvider =
    StateNotifierProvider<SettingsController, UserSettings>((ref) {
      final service = ref.read(settingsServiceProvider);
      return SettingsController(service);
    });

class SettingsController extends StateNotifier<UserSettings> {
  final SettingsService _service;

  SettingsController(this._service) : super(UserSettings.defaultSettings());

  /// Load settings from file
  Future<void> load() async {
    final settings = await _service.load();
    state = settings;
  }

  /// Save current settings to file
  Future<void> save() async {
    await _service.save(state);
  }

  /// Update left panel path
  void setLeftPanelPath(String path) {
    state = state.copyWith(leftPanelPath: path);
    save(); // Auto-save
  }

  /// Update right panel path
  void setRightPanelPath(String path) {
    state = state.copyWith(rightPanelPath: path);
    save(); // Auto-save
  }

  /// Update left panel sort column
  void setLeftPanelSort(int column, bool ascending) {
    state = state.copyWith(
      leftPanelSortColumn: column,
      leftPanelSortAscending: ascending,
    );
    save(); // Auto-save
  }

  /// Update right panel sort column
  void setRightPanelSort(int column, bool ascending) {
    state = state.copyWith(
      rightPanelSortColumn: column,
      rightPanelSortAscending: ascending,
    );
    save(); // Auto-save
  }

  /// Update panel split ratio
  void setPanelSplitRatio(double ratio) {
    state = state.copyWith(panelSplitRatio: ratio);
    save(); // Auto-save
  }

  /// Update font size
  void setFontSize(double size) {
    // Clamp font size to reasonable limits (e.g., 8.0 to 32.0)
    final newSize = size.clamp(8.0, 32.0);
    if (state.fontSize != newSize) {
      state = state.copyWith(fontSize: newSize);
      save(); // Auto-save
    }
  }

  /// Toggle show hidden files setting
  void toggleShowHiddenFiles() {
    state = state.copyWith(showHiddenFiles: !state.showHiddenFiles);
    save(); // Auto-save
  }

  /// Toggle use built-in terminal setting
  void toggleUseBuiltInTerminal() {
    state = state.copyWith(useBuiltInTerminal: !state.useBuiltInTerminal);
    save(); // Auto-save
  }

  /// Update max path indexes
  void setMaxPathIndexes(int count) {
    final newCount = count.clamp(10, 100);
    if (state.maxPathIndexes != newCount) {
      state = state.copyWith(maxPathIndexes: newCount);
      save(); // Auto-save
    }
  }

  /// Update window size and position
  void updateWindowState({
    double? width,
    double? height,
    double? x,
    double? y,
    bool? maximized,
  }) {
    state = state.copyWith(
      windowWidth: width,
      windowHeight: height,
      windowX: x,
      windowY: y,
      windowMaximized: maximized,
    );
    save(); // Auto-save
  }

  /// Update window size only
  void updateWindowSize(double width, double height) {
    state = state.copyWith(windowWidth: width, windowHeight: height);
    save(); // Auto-save
  }

  /// Update window position only
  void updateWindowPosition(double x, double y) {
    state = state.copyWith(windowX: x, windowY: y);
    save(); // Auto-save
  }

  /// Update window maximized state
  void updateWindowMaximized(bool maximized) {
    state = state.copyWith(windowMaximized: maximized);
    save(); // Auto-save
  }

  /// Add or update a path in the index
  void indexPath(String path) {
    if (path.isEmpty) return;

    final List<PathIndexEntry> newIndexes = List.from(state.pathIndexes);
    final index = newIndexes.indexWhere((e) => e.path == path);

    if (index != -1) {
      // Update existing entry
      final entry = newIndexes[index];
      newIndexes[index] = entry.copyWith(
        visitsCount: entry.visitsCount + 1,
        lastVisited: DateTime.now(),
      );
    } else {
      // Add new entry
      newIndexes.add(
        PathIndexEntry(path: path, visitsCount: 1, lastVisited: DateTime.now()),
      );
    }

    // Sort by visitsCount (descending)
    newIndexes.sort((a, b) => b.visitsCount.compareTo(a.visitsCount));

    // Prune if exceeds maxPathIndexes
    if (newIndexes.length > state.maxPathIndexes) {
      newIndexes.removeRange(state.maxPathIndexes, newIndexes.length);
    }

    state = state.copyWith(pathIndexes: newIndexes);
    save(); // Auto-save
  }

  /// Add a new workspace
  void addWorkspace(Workspace workspace) {
    final List<Workspace> newWorkspaces = List.from(state.workspaces);
    // Remove existing workspace with same name
    newWorkspaces.removeWhere((w) => w.name == workspace.name);
    newWorkspaces.add(workspace);
    state = state.copyWith(workspaces: newWorkspaces);
    save();
  }

  /// Update a workspace
  void updateWorkspace(String oldName, Workspace workspace) {
    final List<Workspace> newWorkspaces = List.from(state.workspaces);
    final index = newWorkspaces.indexWhere((w) => w.name == oldName);
    if (index != -1) {
      newWorkspaces[index] = workspace;
      state = state.copyWith(workspaces: newWorkspaces);
      save();
    }
  }

  /// Delete a workspace by name
  void deleteWorkspace(String name) {
    final List<Workspace> newWorkspaces = List.from(state.workspaces);
    newWorkspaces.removeWhere((w) => w.name == name);
    state = state.copyWith(workspaces: newWorkspaces);
    save();
  }

  /// Update theme name
  void setThemeName(String name) {
    state = state.copyWith(themeName: name);
    save();
  }

  /// Set a custom keyboard shortcut for an action
  void setKeyMapShortcut(String actionId, String shortcut) {
    final newKeyMap = Map<String, String>.from(state.keyMap);
    newKeyMap[actionId] = shortcut;
    state = state.copyWith(keyMap: newKeyMap);
    save();
  }

  /// Remove a custom keyboard shortcut for an action
  void removeKeyMapShortcut(String actionId) {
    final newKeyMap = Map<String, String>.from(state.keyMap);
    newKeyMap.remove(actionId);
    state = state.copyWith(keyMap: newKeyMap);
    save();
  }

  /// Get the effective shortcut for an action (custom or default)
  String? getEffectiveShortcut(String actionId) {
    final customShortcut = state.keyMap[actionId];
    if (customShortcut != null && customShortcut.isNotEmpty) {
      return customShortcut;
    }
    return KeyMapActionDefs.getDefaultShortcut(actionId);
  }

  /// Get all custom shortcuts
  Map<String, String> getAllCustomShortcuts() {
    return Map.unmodifiable(state.keyMap);
  }

  /// Check if an action has a custom shortcut
  bool hasCustomShortcut(String actionId) {
    return state.keyMap.containsKey(actionId);
  }

  /// Find action by shortcut (returns actionId or null)
  String? findActionByShortcut(String shortcut) {
    for (final action in KeyMapActionDefs.all) {
      final effectiveShortcut = getEffectiveShortcut(action.id) ?? '';
      if (KeyMapActionDefs.shortcutsMatch(effectiveShortcut, shortcut)) {
        return action.id;
      }
    }
    return null;
  }

  /// Find all conflicting actions for a given shortcut (excluding a specific actionId)
  List<String> findConflictingActions(
    String shortcut, {
    String? excludeActionId,
  }) {
    final conflicts = <String>[];
    for (final action in KeyMapActionDefs.all) {
      if (excludeActionId != null && action.id == excludeActionId) continue;
      final effectiveShortcut = getEffectiveShortcut(action.id) ?? '';
      if (KeyMapActionDefs.shortcutsMatch(effectiveShortcut, shortcut)) {
        conflicts.add(action.label);
      }
    }
    return conflicts;
  }

  /// Reset all keyboard shortcuts to defaults
  void resetKeyMapToDefault() {
    state = state.copyWith(keyMap: {});
    save();
  }

  /// Add a new remote connection
  void addRemoteConnection(RemoteConnection connection) {
    final List<RemoteConnection> newList = List.from(state.remoteConnections);
    newList.removeWhere((c) => c.id == connection.id);
    newList.add(connection);
    state = state.copyWith(remoteConnections: newList);
    save();
  }

  /// Update an existing remote connection
  void updateRemoteConnection(String id, RemoteConnection connection) {
    final List<RemoteConnection> newList = List.from(state.remoteConnections);
    final index = newList.indexWhere((c) => c.id == id);
    if (index != -1) {
      newList[index] = connection;
      state = state.copyWith(remoteConnections: newList);
      save();
    }
  }

  /// Delete a remote connection by ID
  void deleteRemoteConnection(String id) {
    final List<RemoteConnection> newList = List.from(state.remoteConnections);
    newList.removeWhere((c) => c.id == id);
    state = state.copyWith(remoteConnections: newList);
    save();
  }
}
