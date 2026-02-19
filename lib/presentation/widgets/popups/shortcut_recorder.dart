import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fima/presentation/providers/settings_provider.dart';

class ShortcutRecorder extends ConsumerStatefulWidget {
  final String initialShortcut;
  final String actionLabel;
  final String? actionIdToExclude;
  final Function(String) onSave;

  const ShortcutRecorder({
    super.key,
    required this.initialShortcut,
    required this.actionLabel,
    this.actionIdToExclude,
    required this.onSave,
  });

  @override
  ConsumerState<ShortcutRecorder> createState() => _ShortcutRecorderState();
}

class _ShortcutRecorderState extends ConsumerState<ShortcutRecorder> {
  final Set<LogicalKeyboardKey> _pressedKeys = {};
  String _recordedShortcut = '';
  bool _isListening = false;
  String? _conflictWarning;

  @override
  void initState() {
    super.initState();
    _recordedShortcut = widget.initialShortcut;
    _isListening = widget.initialShortcut.isEmpty;
    _updateConflictWarning();
  }

  void _updateConflictWarning() {
    if (_recordedShortcut.isEmpty) {
      _conflictWarning = null;
      return;
    }

    final settingsController = ref.read(userSettingsProvider.notifier);
    final conflicts = settingsController.findConflictingActions(
      _recordedShortcut,
      excludeActionId: widget.actionIdToExclude,
    );

    if (conflicts.isNotEmpty) {
      _conflictWarning =
          "This shortcut is used by '${conflicts.join(', ')}'. It will be replaced.";
    } else {
      _conflictWarning = null;
    }
  }

  String _buildShortcutString() {
    final modifiers = <String>[];
    final otherKeys = <String>[];

    for (final key in _pressedKeys) {
      if (_isModifierKey(key)) {
        modifiers.add(_getModifierLabel(key));
      } else {
        otherKeys.add(_getKeyLabel(key));
      }
    }

    modifiers.sort((a, b) {
      final order = ['Ctrl', 'Alt', 'Shift', '⌘', 'Win'];
      final aIndex = order.indexOf(a);
      final bIndex = order.indexOf(b);
      if (aIndex != -1 && bIndex != -1) {
        return aIndex.compareTo(bIndex);
      }
      if (aIndex != -1) return -1;
      if (bIndex != -1) return 1;
      return a.compareTo(b);
    });

    final parts = [...modifiers, ...otherKeys];
    return parts.join('+');
  }

  bool _isModifierKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight ||
        key == LogicalKeyboardKey.control ||
        key == LogicalKeyboardKey.alt ||
        key == LogicalKeyboardKey.shift ||
        key == LogicalKeyboardKey.meta;
  }

  String _getModifierLabel(LogicalKeyboardKey key) {
    if (Platform.isMacOS) {
      if (key == LogicalKeyboardKey.controlLeft ||
          key == LogicalKeyboardKey.controlRight ||
          key == LogicalKeyboardKey.control) {
        return '⌃';
      }
      if (key == LogicalKeyboardKey.altLeft ||
          key == LogicalKeyboardKey.altRight ||
          key == LogicalKeyboardKey.alt) {
        return '⌥';
      }
      if (key == LogicalKeyboardKey.shiftLeft ||
          key == LogicalKeyboardKey.shiftRight ||
          key == LogicalKeyboardKey.shift) {
        return '⇧';
      }
      if (key == LogicalKeyboardKey.metaLeft ||
          key == LogicalKeyboardKey.metaRight ||
          key == LogicalKeyboardKey.meta) {
        return '⌘';
      }
    } else {
      if (key == LogicalKeyboardKey.controlLeft ||
          key == LogicalKeyboardKey.controlRight ||
          key == LogicalKeyboardKey.control) {
        return 'Ctrl';
      }
      if (key == LogicalKeyboardKey.altLeft ||
          key == LogicalKeyboardKey.altRight ||
          key == LogicalKeyboardKey.alt) {
        return 'Alt';
      }
      if (key == LogicalKeyboardKey.shiftLeft ||
          key == LogicalKeyboardKey.shiftRight ||
          key == LogicalKeyboardKey.shift) {
        return 'Shift';
      }
      if (key == LogicalKeyboardKey.metaLeft ||
          key == LogicalKeyboardKey.metaRight ||
          key == LogicalKeyboardKey.meta) {
        return 'Win';
      }
    }
    return '';
  }

  String _getKeyLabel(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowUp) return 'Arrow Up';
    if (key == LogicalKeyboardKey.arrowDown) return 'Arrow Down';
    if (key == LogicalKeyboardKey.arrowLeft) return 'Arrow Left';
    if (key == LogicalKeyboardKey.arrowRight) return 'Arrow Right';
    if (key == LogicalKeyboardKey.space) return 'Space';
    if (key == LogicalKeyboardKey.enter) return 'Enter';
    if (key == LogicalKeyboardKey.backspace) return 'Backspace';
    if (key == LogicalKeyboardKey.delete) return 'Delete';
    if (key == LogicalKeyboardKey.escape) return 'Escape';
    if (key == LogicalKeyboardKey.tab) return 'Tab';
    if (key == LogicalKeyboardKey.home) return 'Home';
    if (key == LogicalKeyboardKey.end) return 'End';
    if (key == LogicalKeyboardKey.pageUp) return 'Page Up';
    if (key == LogicalKeyboardKey.pageDown) return 'Page Down';
    if (key == LogicalKeyboardKey.insert) return 'Insert';
    if (key == LogicalKeyboardKey.f1) return 'F1';
    if (key == LogicalKeyboardKey.f2) return 'F2';
    if (key == LogicalKeyboardKey.f3) return 'F3';
    if (key == LogicalKeyboardKey.f4) return 'F4';
    if (key == LogicalKeyboardKey.f5) return 'F5';
    if (key == LogicalKeyboardKey.f6) return 'F6';
    if (key == LogicalKeyboardKey.f7) return 'F7';
    if (key == LogicalKeyboardKey.f8) return 'F8';
    if (key == LogicalKeyboardKey.f9) return 'F9';
    if (key == LogicalKeyboardKey.f10) return 'F10';
    if (key == LogicalKeyboardKey.f11) return 'F11';
    if (key == LogicalKeyboardKey.f12) return 'F12';

    final label = key.keyLabel;
    if (label.isNotEmpty) {
      return label.toUpperCase();
    }

    return key.debugName ?? 'Unknown';
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      setState(() {
        _pressedKeys.add(event.logicalKey);
        _recordedShortcut = _buildShortcutString();
        if (_recordedShortcut.isNotEmpty) {
          _isListening = false;
        }
        _updateConflictWarning();
      });
    } else if (event is KeyUpEvent) {
      setState(() {
        _pressedKeys.remove(event.logicalKey);
      });
    }
  }

  void _handleClear() {
    setState(() {
      _pressedKeys.clear();
      _recordedShortcut = '';
      _isListening = true;
      _conflictWarning = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop();
            return;
          }

          if (_pressedKeys.contains(LogicalKeyboardKey.escape)) {
            return;
          }

          _handleKeyEvent(event);
        } else if (event is KeyUpEvent) {
          _handleKeyEvent(event);
        }
      },
      child: Dialog(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set Shortcut for "${widget.actionLabel}"',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _isListening
                    ? 'Press keys to set shortcut...'
                    : 'Press Escape to cancel',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isListening
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _conflictWarning != null
                        ? theme.colorScheme.error
                        : (_isListening
                              ? theme.colorScheme.primary
                              : theme.dividerColor),
                    width: _isListening || _conflictWarning != null ? 2 : 1,
                  ),
                ),
                child: Text(
                  _recordedShortcut.isEmpty
                      ? (_isListening ? '...' : 'No shortcut')
                      : _recordedShortcut,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: _recordedShortcut.isEmpty
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (_conflictWarning != null) ...[
                const SizedBox(height: 8),
                Text(
                  _conflictWarning!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _handleClear,
                    child: const Text('Clear'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _recordedShortcut.isNotEmpty
                        ? () {
                            widget.onSave(_recordedShortcut);
                            Navigator.of(context).pop();
                          }
                        : null,
                    child: const Text('OK'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
