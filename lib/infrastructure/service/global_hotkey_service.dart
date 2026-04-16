import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

class GlobalHotkeyService {
  final VoidCallback onToggleWindow;
  HotKey? _currentHotKey;

  GlobalHotkeyService({required this.onToggleWindow});

  /// Register a global hotkey from the app's shortcut string format.
  /// Returns true on success, false if parsing or registration failed.
  Future<bool> register(String shortcutString) async {
    if (shortcutString.isEmpty) return false;

    final hotKey = _parseShortcutString(shortcutString);
    if (hotKey == null) {
      debugPrint(
        'GlobalHotkeyService: failed to parse shortcut "$shortcutString"',
      );
      return false;
    }

    try {
      await hotKeyManager.register(
        hotKey,
        keyDownHandler: (_) => onToggleWindow(),
      );
      _currentHotKey = hotKey;
      debugPrint(
        'GlobalHotkeyService: registered global hotkey "$shortcutString"',
      );
      return true;
    } catch (e) {
      debugPrint('GlobalHotkeyService: registration failed: $e');
      return false;
    }
  }

  /// Unregister the currently registered global hotkey.
  Future<void> unregister() async {
    if (_currentHotKey == null) return;
    try {
      await hotKeyManager.unregister(_currentHotKey!);
      debugPrint('GlobalHotkeyService: unregistered global hotkey');
    } catch (e) {
      debugPrint('GlobalHotkeyService: unregister failed: $e');
    } finally {
      _currentHotKey = null;
    }
  }

  /// Unregister the old hotkey and register a new one.
  /// Returns true if registration succeeded.
  Future<bool> updateShortcut(String newShortcutString) async {
    await unregister();
    return register(newShortcutString);
  }

  void dispose() {
    unregister();
  }

  // ---------------------------------------------------------------------------
  // Shortcut string parsing
  // ---------------------------------------------------------------------------

  /// Parses the app's shortcut string format into a [HotKey] object.
  ///
  /// Supports both macOS symbol format (e.g. "⌃ + ⌘ + F1") and
  /// Linux/Windows word format (e.g. "Ctrl + Alt + F1").
  HotKey? _parseShortcutString(String shortcut) {
    final parts = shortcut.split('+').map((p) => p.trim()).toList();

    final modifiers = <HotKeyModifier>[];
    String? keyLabel;

    for (final part in parts) {
      if (part.isEmpty) continue;

      final modifier = _parseModifier(part);
      if (modifier != null) {
        modifiers.add(modifier);
      } else {
        keyLabel = part;
      }
    }

    if (keyLabel == null) return null;

    final keyCode = _parseKeyCode(keyLabel);
    if (keyCode == null) {
      debugPrint('GlobalHotkeyService: unknown key label "$keyLabel"');
      return null;
    }

    return HotKey(
      key: keyCode,
      modifiers: modifiers.isEmpty ? null : modifiers,
      scope: HotKeyScope.system,
    );
  }

  HotKeyModifier? _parseModifier(String part) {
    switch (part) {
      // macOS symbols
      case '⌘':
        return HotKeyModifier.meta;
      case '⌃':
        return HotKeyModifier.control;
      case '⌥':
        return HotKeyModifier.alt;
      case '⇧':
        return HotKeyModifier.shift;
      // Linux / Windows words
      case 'Ctrl':
        return HotKeyModifier.control;
      case 'Alt':
        return HotKeyModifier.alt;
      case 'Shift':
        return HotKeyModifier.shift;
      case 'Win':
        return HotKeyModifier.meta;
      default:
        return null;
    }
  }

  PhysicalKeyboardKey? _parseKeyCode(String label) {
    // Function keys
    const fKeys = {
      'F1': PhysicalKeyboardKey.f1,
      'F2': PhysicalKeyboardKey.f2,
      'F3': PhysicalKeyboardKey.f3,
      'F4': PhysicalKeyboardKey.f4,
      'F5': PhysicalKeyboardKey.f5,
      'F6': PhysicalKeyboardKey.f6,
      'F7': PhysicalKeyboardKey.f7,
      'F8': PhysicalKeyboardKey.f8,
      'F9': PhysicalKeyboardKey.f9,
      'F10': PhysicalKeyboardKey.f10,
      'F11': PhysicalKeyboardKey.f11,
      'F12': PhysicalKeyboardKey.f12,
    };
    if (fKeys.containsKey(label)) return fKeys[label];

    // Special keys
    switch (label) {
      case 'Space':
        return PhysicalKeyboardKey.space;
      case 'Enter':
        return PhysicalKeyboardKey.enter;
      case 'Backspace':
        return PhysicalKeyboardKey.backspace;
      case 'Delete':
        return PhysicalKeyboardKey.delete;
      case 'Escape':
        return PhysicalKeyboardKey.escape;
      case 'Tab':
        return PhysicalKeyboardKey.tab;
      case 'Home':
        return PhysicalKeyboardKey.home;
      case 'End':
        return PhysicalKeyboardKey.end;
      case 'Arrow Up':
        return PhysicalKeyboardKey.arrowUp;
      case 'Arrow Down':
        return PhysicalKeyboardKey.arrowDown;
      case 'Arrow Left':
        return PhysicalKeyboardKey.arrowLeft;
      case 'Arrow Right':
        return PhysicalKeyboardKey.arrowRight;
    }

    // Single letter keys (A-Z / 0-9)
    if (label.length == 1) {
      final char = label.toUpperCase();
      final letterKeys = {
        'A': PhysicalKeyboardKey.keyA,
        'B': PhysicalKeyboardKey.keyB,
        'C': PhysicalKeyboardKey.keyC,
        'D': PhysicalKeyboardKey.keyD,
        'E': PhysicalKeyboardKey.keyE,
        'F': PhysicalKeyboardKey.keyF,
        'G': PhysicalKeyboardKey.keyG,
        'H': PhysicalKeyboardKey.keyH,
        'I': PhysicalKeyboardKey.keyI,
        'J': PhysicalKeyboardKey.keyJ,
        'K': PhysicalKeyboardKey.keyK,
        'L': PhysicalKeyboardKey.keyL,
        'M': PhysicalKeyboardKey.keyM,
        'N': PhysicalKeyboardKey.keyN,
        'O': PhysicalKeyboardKey.keyO,
        'P': PhysicalKeyboardKey.keyP,
        'Q': PhysicalKeyboardKey.keyQ,
        'R': PhysicalKeyboardKey.keyR,
        'S': PhysicalKeyboardKey.keyS,
        'T': PhysicalKeyboardKey.keyT,
        'U': PhysicalKeyboardKey.keyU,
        'V': PhysicalKeyboardKey.keyV,
        'W': PhysicalKeyboardKey.keyW,
        'X': PhysicalKeyboardKey.keyX,
        'Y': PhysicalKeyboardKey.keyY,
        'Z': PhysicalKeyboardKey.keyZ,
        '0': PhysicalKeyboardKey.digit0,
        '1': PhysicalKeyboardKey.digit1,
        '2': PhysicalKeyboardKey.digit2,
        '3': PhysicalKeyboardKey.digit3,
        '4': PhysicalKeyboardKey.digit4,
        '5': PhysicalKeyboardKey.digit5,
        '6': PhysicalKeyboardKey.digit6,
        '7': PhysicalKeyboardKey.digit7,
        '8': PhysicalKeyboardKey.digit8,
        '9': PhysicalKeyboardKey.digit9,
        ',': PhysicalKeyboardKey.comma,
        '.': PhysicalKeyboardKey.period,
        '/': PhysicalKeyboardKey.slash,
        ';': PhysicalKeyboardKey.semicolon,
        "'": PhysicalKeyboardKey.quote,
        '[': PhysicalKeyboardKey.bracketLeft,
        ']': PhysicalKeyboardKey.bracketRight,
        '\\': PhysicalKeyboardKey.backslash,
        '-': PhysicalKeyboardKey.minus,
        '=': PhysicalKeyboardKey.equal,
        '`': PhysicalKeyboardKey.backquote,
      };
      return letterKeys[char];
    }

    return null;
  }

  /// Whether hotkey_manager is supported on the current platform.
  static bool get isSupported => Platform.isMacOS || Platform.isWindows || Platform.isLinux;
}
