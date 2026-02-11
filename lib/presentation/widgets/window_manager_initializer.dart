import 'dart:async';

import 'package:fima/presentation/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

class WindowManagerInitializer extends ConsumerStatefulWidget {
  final Widget child;

  const WindowManagerInitializer({super.key, required this.child});

  @override
  ConsumerState<WindowManagerInitializer> createState() =>
      _WindowManagerInitializerState();
}

class _WindowManagerInitializerState
    extends ConsumerState<WindowManagerInitializer>
    with WindowListener {
  bool _isInitialized = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    windowManager.addListener(this);
    _initializeWindowState();

    super.initState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeWindowState() async {
    // Load settings first
    await ref.read(userSettingsProvider.notifier).load();

    final settings = ref.read(userSettingsProvider);

    try {
      // Apply saved window state
      if (settings.windowWidth != null && settings.windowHeight != null) {
        await windowManager.setSize(
          Size(settings.windowWidth!, settings.windowHeight!),
        );
      }

      if (settings.windowX != null && settings.windowY != null) {
        await windowManager.setPosition(
          Offset(settings.windowX!, settings.windowY!),
        );
      }

      if (settings.windowMaximized) {
        await windowManager.maximize();
      }

      // Show and focus the window after applying settings
      await windowManager.show();
      await windowManager.focus();

      _isInitialized = true;
    } catch (e) {
      // If there's an error applying window state, still show the window
      debugPrint('Error applying window state: $e');
      await windowManager.show();
      await windowManager.focus();
      _isInitialized = true;
    }
  }

  void _saveWindowStateDebounced() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _saveWindowState();
    });
  }

  Future<void> _saveWindowState() async {
    if (!_isInitialized) return;

    try {
      final isMaximized = await windowManager.isMaximized();

      if (!isMaximized) {
        final size = await windowManager.getSize();
        final position = await windowManager.getPosition();

        ref
            .read(userSettingsProvider.notifier)
            .updateWindowState(
              width: size.width,
              height: size.height,
              x: position.dx,
              y: position.dy,
              maximized: false,
            );
      } else {
        ref.read(userSettingsProvider.notifier).updateWindowMaximized(true);
      }
    } catch (e) {
      debugPrint('Error saving window state: $e');
    }
  }

  // Window event listeners
  @override
  void onWindowResize() {
    _saveWindowStateDebounced();
  }

  @override
  void onWindowResized() {
    _saveWindowStateDebounced();
  }

  @override
  void onWindowMove() {
    _saveWindowStateDebounced();
  }

  @override
  void onWindowMoved() {
    _saveWindowStateDebounced();
  }

  @override
  void onWindowMaximize() {
    ref.read(userSettingsProvider.notifier).updateWindowMaximized(true);
  }

  @override
  void onWindowUnmaximize() {
    ref.read(userSettingsProvider.notifier).updateWindowMaximized(false);
    // Save the restored size and position
    _saveWindowState();
  }

  @override
  void onWindowClose() async {
    // Save final window state before closing
    await _saveWindowState();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
