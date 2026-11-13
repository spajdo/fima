import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:fima/domain/entity/file_system_item.dart';
import 'package:fima/domain/entity/panel_state.dart';
import 'package:fima/domain/entity/workspace.dart';
import 'package:fima/domain/utils/fima_path.dart';
import 'package:fima/infrastructure/service/application_service.dart';
import 'package:fima/infrastructure/service/system_clipboard_service.dart';
import 'package:fima/presentation/providers/clipboard_actions.dart';
import 'package:fima/presentation/providers/file_system_provider.dart';
import 'package:fima/presentation/providers/focus_provider.dart';
import 'package:fima/presentation/providers/operation_status_provider.dart';
import 'package:fima/presentation/providers/overlay_provider.dart';
import 'package:fima/presentation/providers/panel_feature_actions.dart';
import 'package:fima/presentation/providers/panel_tabs_provider.dart';
import 'package:fima/presentation/providers/settings_provider.dart';
import 'package:fima/presentation/widgets/popups/application_picker_dialog.dart';
import 'package:fima/presentation/widgets/popups/connect_server_dialog.dart';
import 'package:fima/presentation/widgets/popups/delete_confirmation_dialog.dart';
import 'package:fima/presentation/widgets/popups/file_preview_dialog.dart';
import 'package:fima/presentation/widgets/popups/item_info_dialog.dart';
import 'package:fima/presentation/widgets/popups/omni_dialog.dart';
import 'package:fima/presentation/widgets/popups/shortcuts_dialog.dart';
import 'package:fima/presentation/widgets/popups/text_input_dialog.dart';

/// Single source of truth for executing named application actions across
/// keyboard shortcuts, the Omni palette, and context menus.
///
/// Always captures needed notifiers/controllers BEFORE opening dialogs so
/// `.then(...)` callbacks stay safe if the caller widget (e.g. OmniDialog)
/// disposes before the dialog completes.
class AppActionDispatcher {
  const AppActionDispatcher._();

  /// Executes [actionId] against the currently active panel/tab.
  /// Returns `true` if [actionId] was recognized and dispatched.
  static bool dispatch(BuildContext context, WidgetRef ref, String actionId) {
    final activePanelId = ref.read(focusProvider.notifier).getActivePanelId();
    final activeTabId = ref.read(panelTabsProvider(activePanelId)).activeTabId;
    final panelController = ref.read(panelStateProvider(activeTabId).notifier);
    final panelState = ref.read(panelStateProvider(activeTabId));

    switch (actionId) {
      case 'moveUp':
        panelController.moveSelectionUp();
        return true;
      case 'moveDown':
        panelController.moveSelectionDown();
        return true;
      case 'jumpToTop':
        panelController.moveToFirst();
        return true;
      case 'jumpToBottom':
        panelController.moveToLast();
        return true;
      case 'enterDirectory':
        panelController.enterFocusedItem();
        return true;
      case 'navigateParent':
        panelController.navigateToParent();
        return true;
      case 'toggleSelection':
        panelController.toggleSelectionAtFocus();
        return true;
      case 'selectAll':
        panelController.selectAll();
        return true;
      case 'deselectAll':
        panelController.deselectAll();
        return true;
      case 'copyToClipboard':
        ref
            .read(clipboardActionsProvider)
            .copyOrCut(activeTabId, ClipboardOperation.copy);
        return true;
      case 'cutToClipboard':
        ref
            .read(clipboardActionsProvider)
            .copyOrCut(activeTabId, ClipboardOperation.cut);
        return true;
      case 'pasteFromClipboard':
        ref.read(clipboardActionsProvider).paste(activeTabId);
        return true;
      case 'switchPanel':
        ref.read(focusProvider.notifier).switchPanel();
        return true;
      case 'newTab':
        ref.read(panelTabsProvider(activePanelId).notifier).createTab();
        return true;
      case 'closeTab':
        ref.read(panelTabsProvider(activePanelId).notifier).closeActiveTab();
        return true;
      case 'nextTab':
        ref.read(panelTabsProvider(activePanelId).notifier).nextTab();
        return true;
      case 'previousTab':
        ref.read(panelTabsProvider(activePanelId).notifier).previousTab();
        return true;
      case 'toggleHiddenFiles':
        ref.read(userSettingsProvider.notifier).toggleShowHiddenFiles();
        return true;
      case 'deleteToTrash':
        panelController.deleteSelectedItems(permanent: false);
        return true;
      case 'goToTrash':
        navigateToTrash(ref, panelController);
        return true;
      case 'permanentDelete':
        final count = _resolveTargetCount(panelState);
        if (count > 0) {
          showDeleteConfirmation(
            context,
            panelController,
            count,
            permanent: true,
          );
        }
        return true;
      case 'copyOperation':
        ref.read(operationStatusProvider.notifier).startCopy();
        return true;
      case 'moveOperation':
        ref.read(operationStatusProvider.notifier).startMove();
        return true;
      case 'compress':
        final paths = _resolveSelectedOrFocusedPaths(panelState);
        if (paths.isNotEmpty) {
          compressItems(context, panelController, paths);
        }
        return true;
      case 'rename':
        panelController.startRenaming();
        return true;
      case 'createDirectory':
        promptCreateItem(
          context,
          panelController,
          panelState,
          isDirectory: true,
        );
        return true;
      case 'createFile':
        promptCreateItem(
          context,
          panelController,
          panelState,
          isDirectory: false,
        );
        return true;
      case 'openTerminal':
        openTerminal(
          ref,
          isLeftPanel: activePanelId == 'left',
          tabId: activeTabId,
          path: panelState.currentPath,
        );
        return true;
      case 'openDefaultManager':
        if (panelState.currentPath.isNotEmpty) {
          panelController.openFileManager(panelState.currentPath);
        }
        return true;
      case 'openWith':
        final targetPath = _resolvePrimaryTargetPath(panelState);
        if (targetPath != null) {
          openWithApplication(context, panelController, targetPath);
        }
        return true;
      case 'copyPath':
        final focused = _focusedNonParentItem(panelState);
        if (focused != null && focused.path.isNotEmpty) {
          copyPathToClipboard(ref, focused.path);
        }
        return true;
      case 'extractHere':
        _extractFocusedArchive(
          ref,
          activePanelId,
          activeTabId,
          panelController,
          panelState,
          extractToOpposite: false,
        );
        return true;
      case 'extractToOpposite':
        _extractFocusedArchive(
          ref,
          activePanelId,
          activeTabId,
          panelController,
          panelState,
          extractToOpposite: true,
        );
        return true;
      case 'filePreview':
        final focused = _focusedNonParentItem(panelState);
        if (focused != null && !focused.isDirectory) {
          showFilePreviewDialog(context, focused);
        }
        return true;
      case 'showInfo':
        showItemInfo(context, panelState);
        return true;
      case 'saveBookmark':
        PanelFeatureActions.promptSaveBookmark(context, ref);
        return true;
      case 'bookmarkDialog':
        _showOmni(context, 'b ');
        return true;
      case 'calculateDirectorySizes':
        panelController.calculateAllDirectorySizes();
        return true;
      case 'compareFiles':
        PanelFeatureActions.openCompareFiles(context, ref);
        return true;
      case 'editPermissions':
        PanelFeatureActions.openEditPermissions(context, ref);
        return true;
      case 'settings':
        ref
            .read(overlayProvider.notifier)
            .showSettings(activePanelId == 'left');
        return true;
      case 'workspaceDialog':
        _showOmni(context, 'w ');
        return true;
      case 'remoteDialog':
        _showOmni(context, 'r ');
        return true;
      case 'omniPanelPaths':
        _showOmni(context, '');
        return true;
      case 'omniPanelActions':
        _showOmni(context, '>');
        return true;
      case 'editPath':
        panelController.startEditingPath();
        return true;
      case 'connectToServer':
        showDialog(
          context: context,
          barrierColor: Colors.black54,
          builder: (context) => const ConnectServerDialog(),
        );
        return true;
      case 'saveWorkspace':
        _showSaveWorkspaceDialog(context, ref);
        return true;
      case 'clearQuickFilter':
        panelController.clearQuickFilter();
        return true;
      case 'clearFilter':
        if (panelState.quickFilterText.isNotEmpty) {
          panelController.clearQuickFilter();
        }
        return true;
      case 'showShortcuts':
        showDialog(
          context: context,
          barrierColor: Colors.black54,
          builder: (context) => const ShortcutsDialog(),
        );
        return true;
      default:
        return false;
    }
  }

  static void openTerminal(
    WidgetRef ref, {
    required bool isLeftPanel,
    required String tabId,
    required String path,
  }) {
    if (path.isEmpty || FimaPath.isSshPath(path) || FimaPath.isZipPath(path)) {
      return;
    }
    final useBuiltIn = ref.read(userSettingsProvider).useBuiltInTerminal;
    if (useBuiltIn) {
      ref
          .read(overlayProvider.notifier)
          .showTerminal(isLeftPanel, path, tabId: tabId);
    } else {
      ref.read(desktopIntegrationServiceProvider).openTerminal(path);
    }
  }

  static void promptCreateItem(
    BuildContext context,
    PanelController controller,
    PanelState panelState, {
    required bool isDirectory,
  }) {
    if (panelState.currentPath.isEmpty) return;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => TextInputDialog(
        title: isDirectory ? 'Create Directory' : 'Create File',
        label: isDirectory ? 'Directory Name' : 'File Name',
        okButtonLabel: 'Create',
      ),
    ).then((name) {
      if (name != null && name.toString().isNotEmpty) {
        if (isDirectory) {
          controller.createDirectory(name.toString());
        } else {
          controller.createFile(name.toString());
        }
      }
    });
  }

  static void compressItems(
    BuildContext context,
    PanelController controller,
    List<String> paths,
  ) {
    if (paths.isEmpty) return;

    if (paths.length == 1) {
      final itemName = FimaPath.basename(paths.first);
      final zipName = '$itemName.zip';
      controller.compressItems(paths, zipName).then((_) {
        controller.refresh();
      });
      return;
    }

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
        var zipName = name.toString();
        if (!zipName.toLowerCase().endsWith('.zip')) {
          zipName += '.zip';
        }
        controller.compressItems(paths, zipName).then((_) {
          controller.refresh();
        });
      }
    });
  }

  static void openWithApplication(
    BuildContext context,
    PanelController controller,
    String targetPath,
  ) {
    if (targetPath.isEmpty) return;

    final applications = ApplicationService().getInstalledApplications();
    if (!context.mounted) return;

    ApplicationPickerDialog.show(context, applications).then((selectedApp) {
      if (selectedApp != null) {
        controller.openWithApplication(selectedApp, targetPath);
      }
    });
  }

  static void showDeleteConfirmation(
    BuildContext context,
    PanelController controller,
    int count, {
    required bool permanent,
  }) {
    if (count <= 0) return;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => DeleteConfirmationDialog(count: count),
    ).then((confirmed) {
      if (confirmed == true) {
        controller.deleteSelectedItems(permanent: permanent);
      }
    });
  }

  static void showItemInfo(
    BuildContext context,
    PanelState panelState, {
    List<FileSystemItem>? explicitItems,
  }) {
    List<FileSystemItem> targetItems = explicitItems != null
        ? List<FileSystemItem>.from(explicitItems)
        : panelState.items
              .where(
                (item) =>
                    panelState.selectedItems.contains(item.path) &&
                    !item.isParentDetails,
              )
              .toList();

    if (targetItems.isEmpty) {
      final focused = _focusedNonParentItem(panelState);
      if (focused != null) {
        targetItems = [focused];
      }
    }

    if (targetItems.isNotEmpty) {
      showItemInfoDialog(
        context,
        items: targetItems,
        currentPath: panelState.currentPath,
      );
    }
  }

  static void copyPathToClipboard(WidgetRef ref, String targetPath) {
    if (targetPath.isEmpty) return;
    Clipboard.setData(ClipboardData(text: targetPath));
    ref.read(overlayProvider.notifier).showToast('Path copied: $targetPath');
  }

  static Future<void> navigateToTrash(
    WidgetRef ref,
    PanelController controller,
  ) async {
    final overlayNotifier = ref.read(overlayProvider.notifier);
    String? systemTrashPath;

    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '';
      if (home.isNotEmpty) systemTrashPath = '$home/.Trash';
    } else if (Platform.isLinux) {
      final home = Platform.environment['HOME'] ?? '';
      if (home.isNotEmpty) {
        systemTrashPath = '$home/.local/share/Trash/files';
      }
    } else if (Platform.isWindows) {
      final systemDrive =
          Platform.environment['SystemDrive'] ??
          Platform.environment['HOMEDRIVE'] ??
          'C:';
      systemTrashPath = '$systemDrive\\\$Recycle.Bin';
    }

    if (systemTrashPath != null && await Directory(systemTrashPath).exists()) {
      await controller.loadPath(systemTrashPath);
      return;
    }

    try {
      final appSupportDir = await getApplicationSupportDirectory();
      final fallbackTrash = '${appSupportDir.path}/Trash';
      final fallbackDir = Directory(fallbackTrash);
      if (!await fallbackDir.exists()) {
        await fallbackDir.create(recursive: true);
      }
      await controller.loadPath(fallbackTrash);
    } catch (_) {
      overlayNotifier.showToast('Could not locate Trash folder');
    }
  }

  static void _showOmni(BuildContext context, String initialText) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => OmniDialog(initialText: initialText),
    );
  }

  static void _showSaveWorkspaceDialog(BuildContext context, WidgetRef ref) {
    final leftTabsState = ref.read(panelTabsProvider('left'));
    final rightTabsState = ref.read(panelTabsProvider('right'));
    final settingsNotifier = ref.read(userSettingsProvider.notifier);

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => const TextInputDialog(
        title: 'Save Workspace',
        label: 'Workspace Name',
        okButtonLabel: 'Save',
      ),
    ).then((name) {
      if (name != null && name.toString().isNotEmpty) {
        final workspace = Workspace(
          name: name.toString(),
          leftTabs: leftTabsState.tabs,
          leftActiveTabIndex: leftTabsState.activeTabIndex,
          rightTabs: rightTabsState.tabs,
          rightActiveTabIndex: rightTabsState.activeTabIndex,
        );
        settingsNotifier.addWorkspace(workspace);
      }
    });
  }

  static void _extractFocusedArchive(
    WidgetRef ref,
    String activePanelId,
    String activeTabId,
    PanelController panelController,
    PanelState panelState, {
    required bool extractToOpposite,
  }) {
    final item = _focusedNonParentItem(panelState);
    if (item == null ||
        !item.path.toLowerCase().endsWith('.zip') ||
        FimaPath.isSshPath(item.path)) {
      return;
    }

    final String destinationPath;
    final PanelController refreshController;

    if (extractToOpposite) {
      final oppositePanelId = activePanelId == 'left' ? 'right' : 'left';
      final oppositeTabId = ref
          .read(panelTabsProvider(oppositePanelId))
          .activeTabId;
      destinationPath = ref.read(panelStateProvider(oppositeTabId)).currentPath;
      refreshController = ref.read(panelStateProvider(oppositeTabId).notifier);
    } else {
      destinationPath = panelState.currentPath;
      refreshController = panelController;
    }

    if (destinationPath.isEmpty ||
        FimaPath.isSshPath(destinationPath) ||
        FimaPath.isZipPath(destinationPath)) {
      return;
    }

    panelController.extractArchive(item.path, destinationPath).then((_) {
      refreshController.refresh();
    });
  }

  static FileSystemItem? _focusedNonParentItem(PanelState panelState) {
    if (panelState.focusedIndex < 0 ||
        panelState.focusedIndex >= panelState.items.length) {
      return null;
    }
    final item = panelState.items[panelState.focusedIndex];
    return item.isParentDetails ? null : item;
  }

  static List<String> _resolveSelectedOrFocusedPaths(PanelState panelState) {
    if (panelState.selectedItems.isNotEmpty) {
      return panelState.selectedItems.toList();
    }
    final focused = _focusedNonParentItem(panelState);
    return focused != null ? [focused.path] : const [];
  }

  static String? _resolvePrimaryTargetPath(PanelState panelState) {
    if (panelState.selectedItems.isNotEmpty) {
      return panelState.selectedItems.first;
    }
    return _focusedNonParentItem(panelState)?.path;
  }

  static int _resolveTargetCount(PanelState panelState) {
    if (panelState.selectedItems.isNotEmpty) {
      return panelState.selectedItems.length;
    }
    return _focusedNonParentItem(panelState) != null ? 1 : 0;
  }
}
