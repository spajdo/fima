import 'package:fima/domain/entity/path_index_entry.dart';
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
}
