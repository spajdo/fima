import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

class WindowToggleService {
  static const _channel = MethodChannel('fima/window');

  /// Toggle the window:
  ///   - focused + visible + not minimized → minimize
  ///   - otherwise → restore/show, move to current virtual desktop, focus
  Future<void> toggle() async {
    try {
      final isVisible = await windowManager.isVisible();
      final isFocused = await windowManager.isFocused();
      final isMinimized = await windowManager.isMinimized();

      if (isFocused && isVisible && !isMinimized) {
        await windowManager.minimize();
      } else {
        if (isMinimized) {
          await windowManager.restore();
        }
        if (!isVisible) {
          await windowManager.show();
        }
        // On Windows, move the window to the user's current virtual desktop
        // before focusing. macOS handles this via .moveToActiveSpace on NSWindow;
        // Linux X11 handles it via gtk_window_present().
        if (Platform.isWindows) {
          await _moveToCurrentDesktopWindows();
        }
        await windowManager.focus();
      }
    } catch (e) {
      debugPrint('WindowToggleService: toggle failed: $e');
    }
  }

  /// Calls native Windows code to move the window to the user's current
  /// virtual desktop. Uses the hide/show trick via IVirtualDesktopManager to
  /// avoid switching the user to the window's desktop.
  Future<void> _moveToCurrentDesktopWindows() async {
    try {
      await _channel.invokeMethod<void>('moveToCurrentDesktop');
    } catch (e) {
      // Non-fatal: window will still be shown even if desktop move fails
      debugPrint('WindowToggleService: moveToCurrentDesktop failed: $e');
    }
  }
}
