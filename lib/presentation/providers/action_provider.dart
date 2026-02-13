import 'package:fima/domain/entity/app_action.dart';
import 'package:fima/domain/entity/workspace.dart';
import 'package:fima/infrastructure/service/linux_application_service.dart';
import 'package:fima/presentation/providers/file_system_provider.dart';
import 'package:fima/presentation/providers/focus_provider.dart';
import 'package:fima/presentation/providers/operation_status_provider.dart';
import 'package:fima/presentation/providers/settings_provider.dart';
import 'package:fima/presentation/widgets/popups/application_picker_dialog.dart';
import 'package:fima/presentation/widgets/popups/delete_confirmation_dialog.dart';
import 'package:fima/presentation/widgets/popups/text_input_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appActionsProvider = Provider<List<AppAction>>((ref) {
  return [];
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
    final panelController = ref.read(
      panelStateProvider(activePanelId).notifier,
    );

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
        },
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
        },
      ),
      AppAction(
        id: 'open_with',
        label: 'Open with...',
        shortcut: 'F4',
        callback: () {
          final panelState = ref.read(panelStateProvider(activePanelId));
          String? targetPath;

          if (panelState.selectedItems.isNotEmpty) {
            targetPath = panelState.selectedItems.first;
          } else if (panelState.focusedIndex >= 0 &&
              panelState.focusedIndex < panelState.items.length &&
              !panelState.items[panelState.focusedIndex].isParentDetails) {
            targetPath = panelState.items[panelState.focusedIndex].path;
          }

          if (targetPath == null || targetPath.isEmpty) return;

          final appService = LinuxApplicationService();
          final applications = appService.getInstalledApplications();

          if (!context.mounted) return;

          ApplicationPickerDialog.show(context, applications).then((
            selectedApp,
          ) {
            if (selectedApp != null) {
              panelController.openWithApplication(selectedApp, targetPath!);
            }
          });
        },
      ),
      AppAction(
        id: 'save_workspace',
        label: 'Save as Workspace',
        shortcut: 'Ctrl+Shift+S',
        callback: () {
          final leftState = ref.read(panelStateProvider('left'));
          final rightState = ref.read(panelStateProvider('right'));

          showDialog(
            context: context,
            barrierColor: Colors.transparent,
            builder: (context) => TextInputDialog(
              title: 'Save Workspace',
              label: 'Workspace Name',
              okButtonLabel: 'Save',
            ),
          ).then((name) {
            if (name != null && name.toString().isNotEmpty) {
              final workspace = Workspace(
                name: name.toString(),
                leftPanelPath: leftState.currentPath,
                rightPanelPath: rightState.currentPath,
              );
              ref.read(userSettingsProvider.notifier).addWorkspace(workspace);
            }
          });
        },
      ),
    ];
  }
}
