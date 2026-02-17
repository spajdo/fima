import 'package:fima/domain/entity/app_theme.dart';
import 'package:fima/domain/entity/default_themes.dart';
import 'package:fima/presentation/providers/settings_provider.dart';
import 'package:fima/presentation/providers/theme_provider.dart';
import 'package:fima/presentation/widgets/keyboard_handler.dart';
import 'package:fima/presentation/widgets/main_screen.dart';
import 'package:fima/presentation/widgets/window_manager_initializer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    windowButtonVisibility: true,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {});

  runApp(const ProviderScope(child: FimaApp()));
}

class FimaApp extends ConsumerStatefulWidget {
  const FimaApp({super.key});

  @override
  ConsumerState<FimaApp> createState() => _FimaAppState();
}

class _FimaAppState extends ConsumerState<FimaApp> {
  bool _isReady = false;
  late FimaTheme _initialTheme;

  @override
  void initState() {
    super.initState();
    _initialTheme = DefaultThemes.light;
    _initialize();
  }

  Future<void> _initialize() async {
    await ref.read(userSettingsProvider.notifier).load();
    final themeName = ref.read(userSettingsProvider).themeName;
    final themeService = ref.read(themeServiceProvider);
    final savedTheme = await themeService.loadThemeByName(themeName);
    final theme = savedTheme ?? DefaultThemes.getByName(themeName);
    ref.read(themeProvider.notifier).setTheme(theme);
    _initialTheme = theme;
    if (mounted) {
      setState(() {
        _isReady = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Fima - File Manager',
        theme: _buildTheme(_initialTheme),
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    final theme = ref.watch(themeProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fima - File Manager',
      theme: _buildTheme(theme),
      home: const WindowManagerInitializer(
        child: KeyboardHandler(child: MainScreen()),
      ),
    );
  }

  ThemeData _buildTheme(FimaTheme fimaTheme) {
    return ThemeData(
      colorScheme: ColorScheme(
        brightness: fimaTheme.backgroundColor.computeLuminance() > 0.5
            ? Brightness.light
            : Brightness.dark,
        primary: fimaTheme.accentColor,
        onPrimary: Colors.white,
        secondary: fimaTheme.accentColor,
        onSecondary: Colors.white,
        error: Colors.red,
        onError: Colors.white,
        surface: fimaTheme.backgroundColor,
        onSurface: fimaTheme.textColor,
      ),
      scaffoldBackgroundColor: fimaTheme.backgroundColor,
      useMaterial3: true,
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: fimaTheme.accentColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: fimaTheme.accentColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: fimaTheme.accentColor,
          side: BorderSide(color: fimaTheme.accentColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: fimaTheme.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: fimaTheme.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: fimaTheme.accentColor, width: 2),
        ),
        fillColor: fimaTheme.backgroundColor,
        hintStyle: TextStyle(color: fimaTheme.secondaryTextColor),
      ),
      dividerColor: fimaTheme.borderColor,
      iconTheme: IconThemeData(color: fimaTheme.textColor),
      listTileTheme: ListTileThemeData(
        textColor: fimaTheme.textColor,
        iconColor: fimaTheme.secondaryTextColor,
        selectedTileColor: fimaTheme.selectedItemColor,
        selectedColor: fimaTheme.textColor,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: fimaTheme.backgroundColor,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: fimaTheme.backgroundColor,
        surfaceTintColor: Colors.transparent,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: fimaTheme.borderColor),
          ),
          fillColor: fimaTheme.backgroundColor,
        ),
      ),
    );
  }
}
