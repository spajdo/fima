import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fima/domain/entity/key_map_action.dart';
import 'package:fima/infrastructure/service/keyboard_utils.dart';
import 'package:fima/presentation/providers/app_action_dispatcher.dart';
import 'package:fima/presentation/providers/file_system_provider.dart';
import 'package:fima/presentation/providers/focus_provider.dart';
import 'package:fima/presentation/providers/overlay_provider.dart';
import 'package:fima/presentation/providers/panel_tabs_provider.dart';
import 'package:fima/presentation/providers/settings_provider.dart';

const _keyRepeatInitialDelay = Duration(milliseconds: 150);
const _keyRepeatInterval = Duration(milliseconds: 50);

class KeyboardHandler extends ConsumerStatefulWidget {
  final Widget child;

  const KeyboardHandler({super.key, required this.child});

  @override
  ConsumerState<KeyboardHandler> createState() => _KeyboardHandlerState();
}

class _KeyboardHandlerState extends ConsumerState<KeyboardHandler> {
  final Map<LogicalKeyboardKey, Timer> _keyRepeatTimers = {};

  void _startKeyRepeat(
    BuildContext context,
    WidgetRef ref,
    LogicalKeyboardKey key,
  ) {
    _stopKeyRepeat(key);

    void moveAction() {
      final focusController = ref.read(focusProvider.notifier);
      final activePanelId = focusController.getActivePanelId();
      final activeTabId = ref
          .read(panelTabsProvider(activePanelId))
          .activeTabId;
      final panelController = ref.read(
        panelStateProvider(activeTabId).notifier,
      );

      if (key == LogicalKeyboardKey.arrowUp) {
        panelController.moveSelectionUp();
      } else if (key == LogicalKeyboardKey.arrowDown) {
        panelController.moveSelectionDown();
      } else if (key == LogicalKeyboardKey.arrowLeft) {
        panelController.moveToFirst();
      } else if (key == LogicalKeyboardKey.arrowRight) {
        panelController.moveToLast();
      } else if (key == LogicalKeyboardKey.home) {
        panelController.moveToFirst();
      } else if (key == LogicalKeyboardKey.end) {
        panelController.moveToLast();
      }
    }

    moveAction();

    _keyRepeatTimers[key] = Timer(_keyRepeatInitialDelay, () {
      if (_keyRepeatTimers.containsKey(key)) {
        moveAction();
        _keyRepeatTimers[key] = Timer.periodic(_keyRepeatInterval, (_) {
          if (_keyRepeatTimers.containsKey(key)) {
            moveAction();
          }
        });
      }
    });
  }

  void _stopKeyRepeat(LogicalKeyboardKey key) {
    _keyRepeatTimers[key]?.cancel();
    _keyRepeatTimers.remove(key);
  }

  @override
  void dispose() {
    for (final timer in _keyRepeatTimers.values) {
      timer.cancel();
    }
    _keyRepeatTimers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardFocusNode = ref.watch(keyboardHandlerFocusNodeProvider);
    return Focus(
      focusNode: keyboardFocusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        final isNavigationKey =
            event.logicalKey == LogicalKeyboardKey.arrowUp ||
            event.logicalKey == LogicalKeyboardKey.arrowDown ||
            event.logicalKey == LogicalKeyboardKey.arrowLeft ||
            event.logicalKey == LogicalKeyboardKey.arrowRight ||
            event.logicalKey == LogicalKeyboardKey.home ||
            event.logicalKey == LogicalKeyboardKey.end;

        if (event is KeyUpEvent) {
          if (isNavigationKey) {
            _stopKeyRepeat(event.logicalKey);
          }
          return KeyEventResult.ignored;
        }

        final activePanelId = ref
            .read(focusProvider.notifier)
            .getActivePanelId();
        final activeTabId = ref
            .read(panelTabsProvider(activePanelId))
            .activeTabId;
        final panelController = ref.read(
          panelStateProvider(activeTabId).notifier,
        );
        final currentPanelState = ref.read(panelStateProvider(activeTabId));

        // If renaming or editing the path bar is in progress, disable all
        // panel shortcuts; the active field handles Escape, Enter, and input.
        if (currentPanelState.editingPath != null ||
            currentPanelState.isEditingPath) {
          return KeyEventResult.ignored;
        }

        // If overlay is active, handle ESC or ignore before navigation/shortcuts.
        final overlayState = ref.read(overlayProvider);
        if (overlayState.isActive) {
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            // Terminal overlay intercepts Escape itself (confirmation dialog).
            if (overlayState.type == OverlayType.terminal) {
              return KeyEventResult.ignored;
            }
            ref.read(overlayProvider.notifier).close();
            return KeyEventResult.handled;
          }

          if (overlayState.type == OverlayType.terminal) {
            final focusState = ref.read(focusProvider);
            final terminalIsLeft = overlayState.isLeftPanel;
            final activeIsLeft = focusState.activePanel == ActivePanel.left;
            if (terminalIsLeft == activeIsLeft) {
              return KeyEventResult.ignored;
            }
          } else {
            return KeyEventResult.ignored;
          }
        }

        final hasAnyModifier =
            HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed ||
            HardwareKeyboard.instance.isAltPressed ||
            HardwareKeyboard.instance.isShiftPressed;

        if (isNavigationKey && !hasAnyModifier) {
          if (event is KeyDownEvent) {
            _startKeyRepeat(context, ref, event.logicalKey);
            return KeyEventResult.handled;
          }
          if (event is KeyRepeatEvent) {
            // Timer drives held navigation repeat; absorb OS repeat event.
            return KeyEventResult.handled;
          }
        }

        // Handle Backspace for quick filter
        if (event.logicalKey == LogicalKeyboardKey.backspace) {
          if (HardwareKeyboard.instance.isControlPressed) {
            if (currentPanelState.quickFilterText.isNotEmpty) {
              panelController.clearQuickFilter();
              return KeyEventResult.handled;
            }
          } else if (currentPanelState.quickFilterText.isNotEmpty) {
            final filterText = currentPanelState.quickFilterText;
            final newText = filterText.substring(0, filterText.length - 1);
            if (newText.isEmpty) {
              panelController.clearQuickFilter();
            } else {
              panelController.setQuickFilter(newText);
            }
            return KeyEventResult.handled;
          }
        }

        // Check custom keyboard shortcuts.
        final currentShortcut = KeyboardUtils.buildShortcutString(event);
        if (currentShortcut.isNotEmpty) {
          final actionId = ref
              .read(userSettingsProvider.notifier)
              .findActionByShortcut(currentShortcut);
          if (actionId != null) {
            final action = KeyMapActionDefs.getById(actionId);
            if (action != null && action.isGlobal) {
              return KeyEventResult.ignored;
            }

            if (AppActionDispatcher.dispatch(context, ref, actionId)) {
              return KeyEventResult.handled;
            }
          }
        }

        // QuickFilter: plain printable character keys (no Ctrl/Alt/Meta)
        if (!HardwareKeyboard.instance.isControlPressed &&
            !HardwareKeyboard.instance.isMetaPressed &&
            !HardwareKeyboard.instance.isAltPressed) {
          final character = event.character;
          if (character != null &&
              character.length == 1 &&
              !character.contains('\n') &&
              !character.contains('\r') &&
              !character.contains('\t') &&
              character.codeUnitAt(0) >= 32) {
            final newText = currentPanelState.quickFilterText + character;
            panelController.setQuickFilter(newText);
            return KeyEventResult.handled;
          }
        }

        return KeyEventResult.ignored;
      },
      child: widget.child,
    );
  }
}
