import 'dart:io';

import 'package:flutter/services.dart';

class KeyboardUtils {
  static String buildShortcutString(KeyEvent event) {
    final modifiers = <String>[];
    final key = event.logicalKey;

    if (HardwareKeyboard.instance.isControlPressed ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight) {
      if (Platform.isMacOS) {
        modifiers.add('⌃');
      } else {
        modifiers.add('Ctrl');
      }
    }
    if (HardwareKeyboard.instance.isAltPressed ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight) {
      if (Platform.isMacOS) {
        modifiers.add('⌥');
      } else {
        modifiers.add('Alt');
      }
    }
    if (HardwareKeyboard.instance.isShiftPressed ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight) {
      if (Platform.isMacOS) {
        modifiers.add('⇧');
      } else {
        modifiers.add('Shift');
      }
    }
    if (HardwareKeyboard.instance.isMetaPressed ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight) {
      if (Platform.isMacOS) {
        modifiers.add('⌘');
      } else {
        modifiers.add('Win');
      }
    }

    String keyLabel = _getKeyLabel(key);

    if (keyLabel.isEmpty) {
      return '';
    }

    modifiers.sort((a, b) {
      final order = Platform.isMacOS
          ? ['⌘', '⌥', '⇧', '⌃', 'Win']
          : ['Ctrl', 'Alt', 'Shift', 'Win'];
      final aIndex = order.indexOf(a);
      final bIndex = order.indexOf(b);
      if (aIndex != -1 && bIndex != -1) {
        return aIndex.compareTo(bIndex);
      }
      if (aIndex != -1) return -1;
      if (bIndex != -1) return 1;
      return a.compareTo(b);
    });

    final parts = [...modifiers, keyLabel];
    return parts.join(' + ');
  }

  static String _getKeyLabel(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowUp) {
      return 'Arrow Up';
    } else if (key == LogicalKeyboardKey.arrowDown) {
      return 'Arrow Down';
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      return 'Arrow Left';
    } else if (key == LogicalKeyboardKey.arrowRight) {
      return 'Arrow Right';
    } else if (key == LogicalKeyboardKey.space) {
      return 'Space';
    } else if (key == LogicalKeyboardKey.enter) {
      return 'Enter';
    } else if (key == LogicalKeyboardKey.backspace) {
      return 'Backspace';
    } else if (key == LogicalKeyboardKey.delete) {
      return 'Delete';
    } else if (key == LogicalKeyboardKey.escape) {
      return 'Escape';
    } else if (key == LogicalKeyboardKey.tab) {
      return 'Tab';
    } else if (key == LogicalKeyboardKey.home) {
      return 'Home';
    } else if (key == LogicalKeyboardKey.end) {
      return 'End';
    } else if (key == LogicalKeyboardKey.f1) {
      return 'F1';
    } else if (key == LogicalKeyboardKey.f2) {
      return 'F2';
    } else if (key == LogicalKeyboardKey.f3) {
      return 'F3';
    } else if (key == LogicalKeyboardKey.f4) {
      return 'F4';
    } else if (key == LogicalKeyboardKey.f5) {
      return 'F5';
    } else if (key == LogicalKeyboardKey.f6) {
      return 'F6';
    } else if (key == LogicalKeyboardKey.f7) {
      return 'F7';
    } else if (key == LogicalKeyboardKey.f8) {
      return 'F8';
    } else if (key == LogicalKeyboardKey.f9) {
      return 'F9';
    } else if (key == LogicalKeyboardKey.f10) {
      return 'F10';
    } else if (key == LogicalKeyboardKey.f11) {
      return 'F11';
    } else if (key == LogicalKeyboardKey.f12) {
      return 'F12';
    }
    return key.keyLabel.toUpperCase();
  }
}
