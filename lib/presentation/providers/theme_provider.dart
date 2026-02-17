import 'package:fima/domain/entity/app_theme.dart';
import 'package:fima/domain/entity/default_themes.dart';
import 'package:fima/infrastructure/service/theme_service.dart';
import 'package:fima/presentation/providers/settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final themeServiceProvider = Provider<ThemeService>((ref) {
  return ThemeService();
});

final availableThemesProvider = FutureProvider<List<FimaTheme>>((ref) async {
  final service = ref.read(themeServiceProvider);
  return service.loadThemes();
});

final themeProvider = StateNotifierProvider<ThemeController, FimaTheme>((ref) {
  final service = ref.read(themeServiceProvider);
  final settings = ref.read(userSettingsProvider);
  return ThemeController(service, settings.themeName);
});

class ThemeController extends StateNotifier<FimaTheme> {
  final ThemeService _service;
  final String _defaultThemeName;

  ThemeController(this._service, this._defaultThemeName)
    : super(DefaultThemes.getByName(_defaultThemeName));

  Future<void> loadTheme(String themeName) async {
    final theme = await _service.loadThemeByName(themeName);
    if (theme != null) {
      state = theme;
    } else {
      state = DefaultThemes.getByName(_defaultThemeName);
    }
  }

  void setTheme(FimaTheme theme) {
    state = theme;
  }
}
