import 'package:fima/presentation/providers/file_system_provider.dart';
import 'package:fima/presentation/providers/focus_provider.dart';
import 'package:fima/presentation/providers/operation_status_provider.dart';
import 'package:fima/presentation/providers/settings_provider.dart';
import 'package:fima/presentation/widgets/popups/delete_confirmation_dialog.dart';
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

        if (event.logicalKey == LogicalKeyboardKey.keyH &&
            (HardwareKeyboard.instance.isControlPressed ||
                HardwareKeyboard.instance.isMetaPressed)) {
          ref.read(userSettingsProvider.notifier).toggleShowHiddenFiles();
          return KeyEventResult.handled;
        }

        // Delete
        if (event.logicalKey == LogicalKeyboardKey.delete) {
          final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
          final panelState = ref.read(panelStateProvider(activePanelId));

          if (isShiftPressed) {
            // Permanent delete - show dialog
            // We need count of items to be deleted.
            // If selection is empty, it's 1 (focused item), unless focused item is .. or empty
            int count = panelState.selectedItems.length;
            if (count == 0 &&
                panelState.focusedIndex >= 0 &&
                panelState.focusedIndex < panelState.items.length &&
                !panelState.items[panelState.focusedIndex].isParentDetails) {
              count = 1;
            }

            if (count > 0) {
              showDialog(
                context: context,
                builder: (context) => DeleteConfirmationDialog(count: count),
              ).then((confirmed) {
                if (confirmed == true) {
                  panelController.deleteSelectedItems(permanent: true);
                }
              });
            }
          } else {
            // Move to trash - no confirmation
            panelController.deleteSelectedItems(permanent: false);
          }
          return KeyEventResult.handled;
        }

        // F5 - Copy
        if (event.logicalKey == LogicalKeyboardKey.f5) {
          ref.read(operationStatusProvider.notifier).startCopy();
          return KeyEventResult.handled;
        }

        // F6 - Move
        if (event.logicalKey == LogicalKeyboardKey.f6) {
          ref.read(operationStatusProvider.notifier).startMove();
          return KeyEventResult.handled;
        }


        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
