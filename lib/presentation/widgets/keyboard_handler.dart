import 'package:fima/presentation/providers/file_system_provider.dart';
import 'package:fima/presentation/providers/focus_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class KeyboardHandler extends ConsumerWidget {
  final Widget child;

  const KeyboardHandler({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyUpEvent) {
          return KeyEventResult.ignored;
        }

        final focusController = ref.read(focusProvider.notifier);
        final activePanelId = focusController.getActivePanelId();
        final panelController = ref.read(
          panelStateProvider(activePanelId).notifier,
        );

        // Navigation keys
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          panelController.moveSelectionUp();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          panelController.moveSelectionDown();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.home) {
          panelController.moveToFirst();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.end) {
          panelController.moveToLast();
          return KeyEventResult.handled;
        }

        // Directory navigation
        if (event.logicalKey == LogicalKeyboardKey.enter) {
          panelController.enterFocusedItem();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.backspace) {
          panelController.navigateToParent();
          return KeyEventResult.handled;
        }

        // Selection
        if (event.logicalKey == LogicalKeyboardKey.space) {
          panelController.toggleSelectionAtFocus();
          return KeyEventResult.handled;
        }

        // Ctrl+A - Select all
        if (event.logicalKey == LogicalKeyboardKey.keyA &&
            (HardwareKeyboard.instance.isControlPressed ||
                HardwareKeyboard.instance.isMetaPressed)) {
          panelController.selectAll();
          return KeyEventResult.handled;
        }

        // Ctrl+D - Deselect all
        if (event.logicalKey == LogicalKeyboardKey.keyD &&
            (HardwareKeyboard.instance.isControlPressed ||
                HardwareKeyboard.instance.isMetaPressed)) {
          panelController.deselectAll();
          return KeyEventResult.handled;
        }

        // Tab - Switch panel
        if (event.logicalKey == LogicalKeyboardKey.tab) {
          focusController.switchPanel();
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
