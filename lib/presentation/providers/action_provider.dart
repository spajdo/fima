import 'package:fima/domain/entity/app_action.dart';
import 'package:fima/presentation/providers/file_system_provider.dart';
import 'package:fima/presentation/providers/focus_provider.dart';
import 'package:fima/presentation/providers/operation_status_provider.dart';
import 'package:fima/presentation/providers/settings_provider.dart';
import 'package:fima/presentation/widgets/popups/delete_confirmation_dialog.dart';
import 'package:fima/presentation/widgets/popups/text_input_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appActionsProvider = Provider<List<AppAction>>((ref) {
  final focusController = ref.read(focusProvider.notifier);
  final activePanelId = focusController.getActivePanelId();
  final panelController = ref.read(panelStateProvider(activePanelId).notifier);
  
  // Helper specifically for dialogs since we can't easily get context here.
  // We'll return just the data needed to perform the action, or the action itself.
  // For actions requiring UI (dialogs), we might need a different approach or 
  // pass a context-aware runner. 
  // For now, let's implement actions that don't need context or use 
  // a global key / navigator if user accepts that pattern, but standard riverpod
  // usually suggests handling UI side effects in the widget layer.
  // 
  // However, `read` inside options is tricky. The provider is read once.
  // But actions need current state. So we should probably use a function or 
  // a class that can read current state when executed.
  
  return [
    AppAction(
      id: 'copy',
      label: 'Copy',
      shortcut: 'F5',
      callback: () {
        ref.read(operationStatusProvider.notifier).startCopy();
      },
    ),
    AppAction(
      id: 'move',
      label: 'Move',
      shortcut: 'F6',
      callback: () {
        ref.read(operationStatusProvider.notifier).startMove();
      },
    ),
    AppAction(
      id: 'rename',
      label: 'Rename',
      shortcut: 'F2',
      callback: () {
        ref.read(panelStateProvider(activePanelId).notifier).startRenaming();
      },
    ),
    AppAction(
      id: 'refresh',
      label: 'Refresh',
      shortcut: 'Ctrl+R',
      callback: () {
         ref.read(panelStateProvider(activePanelId).notifier).refresh();
      },
    ),
     AppAction(
      id: 'select_all',
      label: 'Select All',
      shortcut: 'Ctrl+A',
      callback: () {
         ref.read(panelStateProvider(activePanelId).notifier).selectAll();
      },
    ),
     AppAction(
      id: 'deselect_all',
      label: 'Deselect All',
      shortcut: 'Ctrl+D',
      callback: () {
         ref.read(panelStateProvider(activePanelId).notifier).deselectAll();
      },
    ),
    AppAction(
      id: 'toggle_hidden',
      label: 'Toggle Hidden Files',
      shortcut: 'Ctrl+H',
      callback: () {
        ref.read(userSettingsProvider.notifier).toggleShowHiddenFiles();
      },
    ),
    // For actions needing dialogs (New Dir, New File, Delete), 
    // the callback might need to be handled by the UI invoker 
    // or we pass a "request" object.
    // simpler: define them with a special ID and handle in UI
    // OR: Assume the caller of AppAction.callback provides context if we change signature?
    // Current signature is VoidCallback.
    // Let's implement non-UI actions first perfectly.
    // For UI actions, we will add them but they might need a way to get context.
    // 
    // Actually, KeyboardHandler has context. omni_dialog has context.
    // Maybe AppAction should accept BuildContext?
  ];
});

// Since some actions require context (showing dialogs), let's create a specialized provider
// or class that can generate actions given a context/ref.
class ActionGenerator {
  final WidgetRef ref;
  final BuildContext context;

  ActionGenerator(this.context, this.ref);

  List<AppAction> generate() {
    final focusController = ref.read(focusProvider.notifier);
    final activePanelId = focusController.getActivePanelId();
    final panelController = ref.read(panelStateProvider(activePanelId).notifier);
    
    return [
      AppAction(
        id: 'copy',
        label: 'Copy',
        shortcut: 'F5',
        callback: () {
          ref.read(operationStatusProvider.notifier).startCopy();
        },
      ),
      AppAction(
        id: 'move',
        label: 'Move',
        shortcut: 'F6',
        callback: () {
          ref.read(operationStatusProvider.notifier).startMove();
        },
      ),
       AppAction(
        id: 'new_folder',
        label: 'New Directory',
        shortcut: 'F7',
        callback: () {
           // Logic from KeyboardHandler
           final panelState = ref.read(panelStateProvider(activePanelId));
           if (panelState.currentPath.isEmpty) return;

           showDialog(
            context: context,
            barrierColor: Colors.transparent,
            builder: (context) => const TextInputDialog(
              title: 'Create Directory',
              label: 'Directory Name',
              okButtonLabel: 'Create',
            ),
          ).then((name) {
            if (name != null && name.toString().isNotEmpty) {
              panelController.createDirectory(name.toString());
            }
          });
        },
      ),
      AppAction(
        id: 'new_file',
        label: 'New File',
        shortcut: 'F8',
        callback: () {
           final panelState = ref.read(panelStateProvider(activePanelId));
           if (panelState.currentPath.isEmpty) return;

           showDialog(
            context: context,
            barrierColor: Colors.transparent,
            builder: (context) => const TextInputDialog(
              title: 'Create File',
              label: 'File Name',
              okButtonLabel: 'Create',
            ),
          ).then((name) {
            if (name != null && name.toString().isNotEmpty) {
              panelController.createFile(name.toString());
            }
          });
        },
      ),
       AppAction(
        id: 'rename',
        label: 'Rename',
        shortcut: 'F2',
        callback: () {
          panelController.startRenaming();
        },
      ),
      AppAction(
        id: 'delete',
        label: 'Delete',
        shortcut: 'Del',
        callback: () {
            // Logic from KeyboardHandler (simplified for now, assumes permanent delete or similar)
            // Ideally we check shift key state but here it's an explicit action.
            // Let's assume standard delete behavior (Trash).
            // But usually "Delete" action in menu implies context.
            // Let's implement simple trash delete first.
             panelController.deleteSelectedItems(permanent: false);
        },
      ),
      // We can add "Delete Permanently" as separate action
      AppAction(
        id: 'delete_permanent',
        label: 'Delete Permanently',
        shortcut: 'Shift+Del',
        callback: () {
             final panelState = ref.read(panelStateProvider(activePanelId));
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
                 barrierColor: Colors.transparent,
                 builder: (context) => DeleteConfirmationDialog(count: count),
               ).then((confirmed) {
                 if (confirmed == true) {
                   panelController.deleteSelectedItems(permanent: true);
                 }
               });
             }
        },
      ),
      AppAction(
        id: 'refresh',
        label: 'Refresh',
        shortcut: 'Ctrl+R',
        callback: () {
           panelController.refresh();
        },
      ),
      AppAction(
        id: 'select_all',
        label: 'Select All',
        shortcut: 'Ctrl+A',
        callback: () {
           panelController.selectAll();
        },
      ),
       AppAction(
        id: 'deselect_all',
        label: 'Deselect All',
        shortcut: 'Ctrl+D',
        callback: () {
           panelController.deselectAll();
        },
      ),
      AppAction(
        id: 'toggle_hidden',
        label: 'Toggle Hidden Files',
        shortcut: 'Ctrl+H',
        callback: () {
          ref.read(userSettingsProvider.notifier).toggleShowHiddenFiles();
        },
      ),
      AppAction(
          id: 'open_terminal',
          label: 'Open Terminal',
          shortcut: 'F9',
          callback: () {
              final panelState = ref.read(panelStateProvider(activePanelId));
              if (panelState.currentPath.isNotEmpty) {
                 panelController.openTerminal(panelState.currentPath);
              }
          }
      ),
      AppAction(
          id: 'open_file_manager',
          label: 'Open Default File Manager',
          shortcut: 'F10',
          callback: () {
              final panelState = ref.read(panelStateProvider(activePanelId));
              if (panelState.currentPath.isNotEmpty) {
                 panelController.openFileManager(panelState.currentPath);
              }
          }
      )
    ];
  }
}
