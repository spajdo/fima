import 'package:fima/domain/entity/user_settings.dart';
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
}
