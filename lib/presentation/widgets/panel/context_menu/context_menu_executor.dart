import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:fima/domain/entity/file_system_item.dart';
import 'package:fima/domain/entity/panel_state.dart';
import 'package:fima/domain/utils/fima_path.dart';
import 'package:fima/infrastructure/service/system_clipboard_service.dart';
import 'package:fima/presentation/providers/app_action_dispatcher.dart';
import 'package:fima/presentation/providers/clipboard_actions.dart';
import 'package:fima/presentation/providers/file_system_provider.dart';
import 'package:fima/presentation/providers/operation_status_provider.dart';
import 'package:fima/presentation/providers/overlay_provider.dart';
import 'package:fima/presentation/providers/panel_feature_actions.dart';
import 'package:fima/presentation/providers/panel_tabs_provider.dart';
import 'package:fima/presentation/providers/settings_provider.dart';
import 'package:fima/presentation/widgets/panel/context_menu/context_menu_spec.dart';
import 'package:fima/presentation/widgets/popups/file_preview_dialog.dart';

/// Executes [ContextMenuAction] selections for a panel context menu by
/// delegating shared actions to [AppActionDispatcher] and controllers.
class ContextMenuExecutor {
  const ContextMenuExecutor._();

  static Future<void> execute({
    required ContextMenuAction action,
    required BuildContext context,
    required WidgetRef ref,
    required String panelId,
    required String tabId,
    required PanelState panelState,
    required PanelController controller,
    required FileSystemItem? clickedItem,
    required List<FileSystemItem> targetItems,
  }) async {
    switch (action) {
      case ContextMenuAction.open:
        controller.enterFocusedItem();
        break;
      case ContextMenuAction.openInNewTab:
        if (clickedItem != null) {
          await ref
              .read(panelTabsProvider(panelId).notifier)
              .createTab(path: clickedItem.path);
        }
        break;
      case ContextMenuAction.openInOppositePanel:
        if (clickedItem != null) {
          final oppositePanelId = panelId == 'left' ? 'right' : 'left';
          final oppositeTabId = ref
              .read(panelTabsProvider(oppositePanelId))
              .activeTabId;
          await ref
              .read(panelStateProvider(oppositeTabId).notifier)
              .loadPath(clickedItem.path);
        }
        break;
      case ContextMenuAction.openWith:
        if (clickedItem != null) {
          AppActionDispatcher.openWithApplication(
            context,
            controller,
            clickedItem.path,
          );
        }
        break;
      case ContextMenuAction.preview:
        if (clickedItem != null && !clickedItem.isDirectory) {
          await showFilePreviewDialog(context, clickedItem);
        }
        break;
      case ContextMenuAction.extractHere:
        if (clickedItem != null) {
          await controller.extractArchive(
            clickedItem.path,
            panelState.currentPath,
          );
          await controller.refresh();
        }
        break;
      case ContextMenuAction.extractToFolder:
        if (clickedItem != null) {
          final stem = p.basenameWithoutExtension(clickedItem.name);
          final destDir = p.join(panelState.currentPath, stem);
          await Directory(destDir).create(recursive: true);
          await controller.extractArchive(clickedItem.path, destDir);
          await controller.refresh();
        }
        break;
      case ContextMenuAction.extractToOpposite:
        if (clickedItem != null) {
          final oppositePanelId = panelId == 'left' ? 'right' : 'left';
          final oppositeTabId = ref
              .read(panelTabsProvider(oppositePanelId))
              .activeTabId;
          final destPath = ref
              .read(panelStateProvider(oppositeTabId))
              .currentPath;
          if (destPath.isNotEmpty &&
              !FimaPath.isSshPath(destPath) &&
              !FimaPath.isZipPath(destPath)) {
            await controller.extractArchive(clickedItem.path, destPath);
            await ref
                .read(panelStateProvider(oppositeTabId).notifier)
                .refresh();
          }
        }
        break;
      case ContextMenuAction.copyToOpposite:
        await ref.read(operationStatusProvider.notifier).startCopy();
        break;
      case ContextMenuAction.moveToOpposite:
        await ref.read(operationStatusProvider.notifier).startMove();
        break;
      case ContextMenuAction.copyToClipboard:
        await ref
            .read(clipboardActionsProvider)
            .copyOrCut(
              tabId,
              ClipboardOperation.copy,
              explicitPaths: targetItems.map((e) => e.path).toList(),
            );
        break;
      case ContextMenuAction.cutToClipboard:
        await ref
            .read(clipboardActionsProvider)
            .copyOrCut(
              tabId,
              ClipboardOperation.cut,
              explicitPaths: targetItems.map((e) => e.path).toList(),
            );
        break;
      case ContextMenuAction.pasteFromClipboard:
        await ref.read(clipboardActionsProvider).paste(tabId);
        break;
      case ContextMenuAction.copyPath:
        final paths = targetItems.map((e) => e.path).toList();
        if (paths.isNotEmpty) {
          final text = paths.join('\n');
          await Clipboard.setData(ClipboardData(text: text));
          ref
              .read(overlayProvider.notifier)
              .showToast(
                paths.length > 1
                    ? 'Copied ${paths.length} paths'
                    : 'Path copied: $text',
              );
        }
        break;
      case ContextMenuAction.rename:
        controller.startRenaming();
        break;
      case ContextMenuAction.compress:
        final paths = targetItems.map((e) => e.path).toList();
        if (paths.isNotEmpty) {
          AppActionDispatcher.compressItems(context, controller, paths);
        }
        break;
      case ContextMenuAction.createDirectory:
        AppActionDispatcher.promptCreateItem(
          context,
          controller,
          panelState,
          isDirectory: true,
        );
        break;
      case ContextMenuAction.createFile:
        AppActionDispatcher.promptCreateItem(
          context,
          controller,
          panelState,
          isDirectory: false,
        );
        break;
      case ContextMenuAction.selectAll:
        controller.selectAll();
        break;
      case ContextMenuAction.deselectAll:
        controller.deselectAll();
        break;
      case ContextMenuAction.toggleHiddenFiles:
        ref.read(userSettingsProvider.notifier).toggleShowHiddenFiles();
        break;
      case ContextMenuAction.refresh:
        await controller.refresh();
        break;
      case ContextMenuAction.openTerminalHere:
        final termPath = (clickedItem != null && clickedItem.isDirectory)
            ? clickedItem.path
            : panelState.currentPath;
        AppActionDispatcher.openTerminal(
          ref,
          isLeftPanel: panelId == 'left',
          tabId: tabId,
          path: termPath,
        );
        break;
      case ContextMenuAction.openDefaultManager:
        if (clickedItem != null) {
          await controller.revealInFileManager(
            clickedItem.path,
            isDirectory: clickedItem.isDirectory,
          );
        } else if (panelState.currentPath.isNotEmpty) {
          await controller.openFileManager(panelState.currentPath);
        }
        break;
      case ContextMenuAction.calculateDirectorySize:
        if (clickedItem != null && clickedItem.isDirectory) {
          await controller.calculateDirectorySize(clickedItem.path);
        }
        break;
      case ContextMenuAction.calculateAllDirectorySizes:
        await controller.calculateAllDirectorySizes();
        break;
      case ContextMenuAction.bookmarkFolder:
        final folderPath = (clickedItem != null && clickedItem.isDirectory)
            ? clickedItem.path
            : panelState.currentPath;
        await PanelFeatureActions.promptSaveBookmark(
          context,
          ref,
          folderPath: folderPath,
        );
        break;
      case ContextMenuAction.compareFiles:
        await PanelFeatureActions.openCompareFiles(
          context,
          ref,
          explicitItems: targetItems.length == 2 ? targetItems : null,
        );
        break;
      case ContextMenuAction.editPermissions:
        if (clickedItem != null) {
          await PanelFeatureActions.openEditPermissions(
            context,
            ref,
            item: clickedItem,
            currentPath: panelState.currentPath,
          );
        }
        break;
      case ContextMenuAction.moveToTrash:
        await controller.deleteSelectedItems(permanent: false);
        break;
      case ContextMenuAction.permanentDelete:
        AppActionDispatcher.showDeleteConfirmation(
          context,
          controller,
          targetItems.length,
          permanent: true,
        );
        break;
      case ContextMenuAction.info:
        final infoItems = targetItems.isNotEmpty
            ? targetItems
            : [
                FileSystemItem(
                  path: panelState.currentPath,
                  name: FimaPath.basename(panelState.currentPath).isEmpty
                      ? panelState.currentPath
                      : FimaPath.basename(panelState.currentPath),
                  size: 0,
                  modified: DateTime.now(),
                  isDirectory: true,
                ),
              ];
        AppActionDispatcher.showItemInfo(
          context,
          panelState,
          explicitItems: infoItems,
        );
        break;
    }
  }
}
