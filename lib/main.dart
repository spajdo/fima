import 'package:fima/presentation/widgets/keyboard_handler.dart';
import 'package:fima/presentation/widgets/main_screen.dart';
import 'package:fima/presentation/widgets/window_manager_initializer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager
  await windowManager.ensureInitialized();

  // Configure initial window options - don't set size here, let WindowManagerInitializer handle it
  WindowOptions windowOptions = const WindowOptions(
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    windowButtonVisibility: true,
  );

  // Wait for window to be ready, but don't show it yet - WindowManagerInitializer will handle showing
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    // Don't show here - let WindowManagerInitializer show it after applying settings
  });

  runApp(const ProviderScope(child: FimaApp()));
}

class FimaApp extends StatelessWidget {
  const FimaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fima - File Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const WindowManagerInitializer(
        child: KeyboardHandler(child: MainScreen()),
      ),
    );
  }
}
