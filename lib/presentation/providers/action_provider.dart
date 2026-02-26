import 'package:fima/domain/entity/app_action.dart';
import 'package:fima/domain/entity/key_map_action.dart';
import 'package:fima/infrastructure/service/linux_application_service.dart';
import 'package:fima/infrastructure/service/system_clipboard_service.dart';
import 'package:fima/presentation/providers/file_system_provider.dart';
import 'package:fima/presentation/providers/focus_provider.dart';
import 'package:fima/presentation/providers/operation_status_provider.dart';
import 'package:fima/presentation/providers/overlay_provider.dart';
import 'package:fima/presentation/providers/settings_provider.dart';
import 'package:fima/presentation/widgets/popups/application_picker_dialog.dart';
import 'package:fima/presentation/widgets/popups/delete_confirmation_dialog.dart';
import 'package:fima/presentation/widgets/popups/text_input_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appActionsProvider = Provider<List<AppAction>>((ref) {
  return [];
});

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

    final settingsNotifier = ref.read(userSettingsProvider.notifier);

    final panelState = ref.read(panelStateProvider(activePanelId));
    bool isZipFocused = false;
    if (panelState.focusedIndex >= 0 &&
        panelState.focusedIndex < panelState.items.length) {
      final focusedItem = panelState.items[panelState.focusedIndex];
      // A zip file itself (not inside another zip or directory) might just end with .zip
      if (focusedItem.path.toLowerCase().endsWith('.zip') &&
          !focusedItem.isDirectory &&
          !focusedItem.isParentDetails) {
        isZipFocused = true;
      }
    }

    final actions = KeyMapActionDefs.omniPanelActions.map((action) {
      return AppAction(
        id: action.id,
        label: action.label,
        shortcut: settingsNotifier.getEffectiveShortcut(action.id),
        callback: () =>
            _executeAction(action.id, activePanelId, panelController),
      );
    }).toList();

    if (isZipFocused) {
      final extractHereAction = KeyMapActionDefs.getById('extractHere');
      final extractOppositeAction = KeyMapActionDefs.getById(
        'extractToOpposite',
      );

      if (extractHereAction != null && extractOppositeAction != null) {
        actions.insert(
          0,
          AppAction(
            id: extractOppositeAction.id,
            label: extractOppositeAction.label,
            shortcut: settingsNotifier.getEffectiveShortcut(
              extractOppositeAction.id,
            ),
            callback: () => _executeAction(
              extractOppositeAction.id,
              activePanelId,
              panelController,
            ),
          ),
        );
        actions.insert(
          0,
          AppAction(
            id: extractHereAction.id,
            label: extractHereAction.label,
            shortcut: settingsNotifier.getEffectiveShortcut(
              extractHereAction.id,
            ),
            callback: () => _executeAction(
              extractHereAction.id,
              activePanelId,
              panelController,
            ),
          ),
        );
      }
    }

    return actions;
  }

  void _executeAction(
    String actionId,
    String activePanelId,
    dynamic panelController,
  ) {
    final panelState = ref.read(panelStateProvider(activePanelId));

    switch (actionId) {
      case 'extractHere':
        _extractZip(activePanelId, panelController, extractToOpposite: false);
        break;
      case 'extractToOpposite':
        _extractZip(activePanelId, panelController, extractToOpposite: true);
        break;
      case 'compress':
        _compressItems(activePanelId, panelController, context);
        break;
      case 'copyOperation':
        ref.read(operationStatusProvider.notifier).startCopy();
        break;
      case 'moveOperation':
        ref.read(operationStatusProvider.notifier).startMove();
        break;
      case 'createDirectory':
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
        break;
      case 'createFile':
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
        break;
      case 'rename':
        panelController.startRenaming();
        break;
      case 'deleteToTrash':
        panelController.deleteSelectedItems(permanent: false);
        break;
      case 'permanentDelete':
        _showDeleteConfirmation(
          activePanelId,
          panelController,
          permanent: true,
        );
        break;
      case 'selectAll':
        panelController.selectAll();
        break;
      case 'toggleHiddenFiles':
        ref.read(userSettingsProvider.notifier).toggleShowHiddenFiles();
        break;
      case 'openTerminal':
        if (panelState.currentPath.isNotEmpty) {
          panelController.openTerminal(panelState.currentPath);
        }
        break;
      case 'openDefaultManager':
        if (panelState.currentPath.isNotEmpty) {
          panelController.openFileManager(panelState.currentPath);
        }
        break;
      case 'openWith':
        _openWithApplication(panelState, panelController);
        break;
      case 'copyPath':
        _copyPathToClipboard(panelState);
        break;
      case 'copyToClipboard':
        _copyOrCut(panelState, panelController, ClipboardOperation.copy);
        break;
      case 'cutToClipboard':
        _copyOrCut(panelState, panelController, ClipboardOperation.cut);
        break;
      case 'pasteFromClipboard':
        panelController.pasteFromClipboard();
        break;
      case 'moveUp':
        panelController.moveSelectionUp();
        break;
      case 'moveDown':
        panelController.moveSelectionDown();
        break;
      case 'jumpToTop':
        panelController.moveToFirst();
        break;
      case 'jumpToBottom':
        panelController.moveToLast();
        break;
      case 'deselectAll':
        panelController.deselectAll();
        break;
      case 'settings':
        final focusState = ref.read(focusProvider);
        final isLeftPanel = focusState.activePanel == ActivePanel.left;
        ref.read(overlayProvider.notifier).showSettings(isLeftPanel);
        break;
    }
  }

  void _showDeleteConfirmation(
    String activePanelId,
    dynamic panelController, {
    required bool permanent,
  }) {
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
          panelController.deleteSelectedItems(permanent: permanent);
        }
      });
    }
  }

  void _openWithApplication(dynamic panelState, dynamic panelController) {
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

    ApplicationPickerDialog.show(context, applications).then((selectedApp) {
      if (selectedApp != null) {
        panelController.openWithApplication(selectedApp, targetPath!);
      }
    });
  }

  void _copyPathToClipboard(dynamic panelState) {
    String? targetPath;

    if (panelState.focusedIndex >= 0 &&
        panelState.focusedIndex < panelState.items.length) {
      final item = panelState.items[panelState.focusedIndex];
      if (!item.isParentDetails) {
        targetPath = item.path;
      }
    }

    if (targetPath != null && targetPath.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: targetPath));
      ref.read(overlayProvider.notifier).showToast('Path copied: $targetPath');
    }
  }

  void _copyOrCut(
    dynamic panelState,
    dynamic panelController,
    ClipboardOperation operation,
  ) {
    List<String> paths = panelState.selectedItems.toList();

    if (paths.isEmpty) {
      if (panelState.focusedIndex >= 0 &&
          panelState.focusedIndex < panelState.items.length) {
        final item = panelState.items[panelState.focusedIndex];
        if (!item.isParentDetails) {
          paths.add(item.path);
        }
      }
    }

    if (paths.isNotEmpty) {
      panelController.copyToClipboard(paths, operation);
    }
  }

  void _extractZip(
    String activePanelId,
    dynamic panelController, {
    required bool extractToOpposite,
  }) {
    final panelState = ref.read(panelStateProvider(activePanelId));
    if (panelState.focusedIndex >= 0 &&
        panelState.focusedIndex < panelState.items.length) {
      final item = panelState.items[panelState.focusedIndex];
      if (item.path.toLowerCase().endsWith('.zip')) {
        String destinationPath;
        dynamic refreshController;

        if (extractToOpposite) {
          final oppositePanelId = activePanelId == 'left' ? 'right' : 'left';
          destinationPath = ref
              .read(panelStateProvider(oppositePanelId))
              .currentPath;
          // Capture the opposite panel controller now, before the dialog closes
          refreshController = ref.read(
            panelStateProvider(oppositePanelId).notifier,
          );
        } else {
          destinationPath = panelState.currentPath;
          refreshController = panelController;
        }

        panelController.extractArchive(item.path, destinationPath).then((_) {
          refreshController.refresh();
        });
      }
    }
  }

  void _compressItems(
    String activePanelId,
    dynamic panelController,
    BuildContext context,
  ) {
    final panelState = ref.read(panelStateProvider(activePanelId));
    List<String> paths = panelState.selectedItems.toList();

    if (paths.isEmpty) {
      if (panelState.focusedIndex >= 0 &&
          panelState.focusedIndex < panelState.items.length) {
        final item = panelState.items[panelState.focusedIndex];
        if (!item.isParentDetails) {
          paths.add(item.path);
        }
      }
    }

    if (paths.isEmpty) return;

    if (paths.length == 1) {
      // Single item: compress directly using its name
      final itemName = paths.first.split('/').last;
      final zipName = '$itemName.zip';
      panelController.compressItems(paths, zipName).then((_) {
        panelController.refresh();
      });
    } else {
      // Multiple items: ask for name
      showDialog(
        context: context,
        barrierColor: Colors.transparent,
        builder: (context) => const TextInputDialog(
          title: 'Compress Items',
          label: 'Archive Name (e.g. archive.zip)',
          okButtonLabel: 'Compress',
        ),
      ).then((name) {
        if (name != null && name.toString().isNotEmpty) {
          String zipName = name.toString();
          if (!zipName.toLowerCase().endsWith('.zip')) {
            zipName += '.zip';
          }
          panelController.compressItems(paths, zipName).then((_) {
            panelController.refresh();
          });
        }
      });
    }
  }
}
