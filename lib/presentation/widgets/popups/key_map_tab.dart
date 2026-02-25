import 'dart:io';

import 'package:fima/domain/entity/key_map_action.dart';
import 'package:fima/presentation/providers/settings_provider.dart';
import 'package:fima/presentation/widgets/popups/shortcut_recorder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class KeyMapTab extends ConsumerStatefulWidget {
  final VoidCallback? onShortcutChanged;

  const KeyMapTab({super.key, this.onShortcutChanged});

  @override
  ConsumerState<KeyMapTab> createState() => _KeyMapTabState();
}

class _KeyMapTabState extends ConsumerState<KeyMapTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  String? _shortcutFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<KeyMapAction> _getFilteredActions(
    SettingsController settingsController,
  ) {
    return KeyMapActionDefs.all.where((action) {
      // Filter by text (label)
      if (_searchText.isNotEmpty) {
        if (!action.label.toLowerCase().contains(_searchText.toLowerCase())) {
          return false;
        }
      }

      // Filter by shortcut
      if (_shortcutFilter != null) {
        final effectiveShortcut = settingsController.getEffectiveShortcut(
          action.id,
        );
        if (effectiveShortcut != _shortcutFilter) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsController = ref.watch(userSettingsProvider.notifier);
    final filteredActions = _getFilteredActions(settingsController);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search actions...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchText.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchText = '';
                                  });
                                },
                              )
                            : null,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchText = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _showFindShortcutDialog,
                    icon: const Icon(Icons.keyboard),
                    tooltip: 'Find Action by Shortcut',
                  ),
                ],
              ),
              if (_shortcutFilter != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    InputChip(
                      label: Text('Shortcut: $_shortcutFilter'),
                      onDeleted: () {
                        setState(() {
                          _shortcutFilter = null;
                        });
                      },
                      deleteIcon: const Icon(Icons.close, size: 16),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: filteredActions.isEmpty
              ? Center(
                  child: Text(
                    'No actions found',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredActions.length,
                  itemBuilder: (context, index) {
                    final action = filteredActions[index];
                    final effectiveShortcut = settingsController
                        .getEffectiveShortcut(action.id);
                    final hasCustom = settingsController.hasCustomShortcut(
                      action.id,
                    );

                    return _KeyMapRow(
                      action: action,
                      shortcut: effectiveShortcut ?? '',
                      isCustom: hasCustom,
                      onShortcutChanged: (newShortcut) async {
                        if (newShortcut.isEmpty) {
                          settingsController.removeKeyMapShortcut(action.id);
                          widget.onShortcutChanged?.call();
                          return;
                        }

                        final conflicts = settingsController
                            .findConflictingActions(
                              newShortcut,
                              excludeActionId: action.id,
                            );

                        if (conflicts.isNotEmpty) {
                          final confirmed = await _showConflictDialog(
                            context,
                            newShortcut,
                            action.label,
                            conflicts,
                          );
                          if (confirmed == true) {
                            for (final conflictLabel in conflicts) {
                              final conflictAction = KeyMapActionDefs.all
                                  .firstWhere((a) => a.label == conflictLabel);
                              settingsController.removeKeyMapShortcut(
                                conflictAction.id,
                              );
                            }
                            settingsController.setKeyMapShortcut(
                              action.id,
                              newShortcut,
                            );
                            widget.onShortcutChanged?.call();
                          }
                        } else {
                          settingsController.setKeyMapShortcut(
                            action.id,
                            newShortcut,
                          );
                          widget.onShortcutChanged?.call();
                        }
                      },
                      onClearShortcut: () {
                        settingsController.removeKeyMapShortcut(action.id);
                        widget.onShortcutChanged?.call();
                      },
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => _showResetDialog(context, ref),
                icon: const Icon(Icons.restore),
                label: const Text('Reset to Default'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showFindShortcutDialog() async {
    final shortcut = await showDialog<String>(
      context: context,
      builder: (context) => const _FindShortcutDialog(),
    );

    if (shortcut != null && mounted) {
      setState(() {
        _shortcutFilter = shortcut;
      });
    }
  }

  Future<bool?> _showConflictDialog(
    BuildContext context,
    String shortcut,
    String actionLabel,
    List<String> conflicts,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Shortcut Conflict'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Shortcut '$shortcut' is already used by '${conflicts.join(', ')}'.",
            ),
            const SizedBox(height: 8),
            const Text('It will be removed from the conflicting action(s).'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
  }

  Future<void> _showResetDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Key Map'),
        content: const Text(
          'Are you sure you want to reset all keyboard shortcuts to defaults?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(userSettingsProvider.notifier).resetKeyMapToDefault();
      widget.onShortcutChanged?.call();
    }
  }
}

class _FindShortcutDialog extends StatefulWidget {
  const _FindShortcutDialog();

  @override
  State<_FindShortcutDialog> createState() => _FindShortcutDialogState();
}

class _FindShortcutDialogState extends State<_FindShortcutDialog> {
  final Set<LogicalKeyboardKey> _pressedKeys = {};
  String _recordedShortcut = '';

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
                'Find Action by Shortcut',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Press keys to filter list...',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                ),
                child: Text(
                  _recordedShortcut.isEmpty ? '...' : _recordedShortcut,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: _recordedShortcut.isEmpty
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
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
                            Navigator.of(context).pop(_recordedShortcut);
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

class _KeyMapRow extends StatelessWidget {
  final KeyMapAction action;
  final String shortcut;
  final bool isCustom;
  final Function(String) onShortcutChanged;
  final VoidCallback onClearShortcut;

  const _KeyMapRow({
    required this.action,
    required this.shortcut,
    required this.isCustom,
    required this.onShortcutChanged,
    required this.onClearShortcut,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(action.label, style: theme.textTheme.bodyMedium),
          ),
          Expanded(
            flex: 2,
            child: _ShortcutBadge(
              shortcut: shortcut,
              isCustom: isCustom,
              isEditable: action.isEditable,
              onTap: action.isEditable
                  ? () => _showShortcutRecorder(context)
                  : null,
              onClear: isCustom ? onClearShortcut : null,
            ),
          ),
        ],
      ),
    );
  }

  void _showShortcutRecorder(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => ShortcutRecorder(
        initialShortcut: shortcut,
        actionLabel: action.label,
        actionIdToExclude: action.id,
        onSave: (newShortcut) {
          onShortcutChanged(newShortcut);
        },
      ),
    );
  }
}

class _ShortcutBadge extends StatelessWidget {
  final String shortcut;
  final bool isCustom;
  final bool isEditable;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  const _ShortcutBadge({
    required this.shortcut,
    required this.isCustom,
    required this.isEditable,
    this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!isEditable) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              shortcut,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isCustom
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isCustom
                    ? theme.colorScheme.primary
                    : theme.dividerColor,
              ),
            ),
            child: Text(
              shortcut.isEmpty ? 'Click to set' : shortcut,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isCustom
                    ? theme.colorScheme.onPrimaryContainer
                    : shortcut.isEmpty
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onSurface,
                fontWeight: isCustom ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ),
        if (isCustom && onClear != null) ...[
          const SizedBox(width: 8),
          InkWell(
            onTap: onClear,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
