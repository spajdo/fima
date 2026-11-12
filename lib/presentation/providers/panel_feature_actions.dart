import 'dart:io';

import 'package:fima/domain/entity/bookmark.dart';
import 'package:fima/domain/entity/file_system_item.dart';
import 'package:fima/domain/entity/panel_state.dart';
import 'package:fima/infrastructure/service/item_metadata_service.dart';
import 'package:fima/presentation/providers/file_system_provider.dart';
import 'package:fima/presentation/providers/focus_provider.dart';
import 'package:fima/presentation/providers/overlay_provider.dart';
import 'package:fima/presentation/providers/panel_tabs_provider.dart';
import 'package:fima/presentation/providers/settings_provider.dart';
import 'package:fima/presentation/widgets/popups/file_diff_dialog.dart';
import 'package:fima/presentation/widgets/popups/permissions_dialog.dart';
import 'package:fima/presentation/widgets/popups/text_input_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

class PanelFeatureActions {
  /// Prompts for a bookmark name and saves [folderPath] (or the active panel's
  /// current directory when [folderPath] is omitted).
  static Future<void> promptSaveBookmark(
    BuildContext context,
    WidgetRef ref, {
    String? folderPath,
  }) async {
    String targetPath = folderPath ?? '';
    if (targetPath.isEmpty) {
      final activePanelId = ref.read(focusProvider.notifier).getActivePanelId();
      final activeTabId = ref
          .read(panelTabsProvider(activePanelId))
          .activeTabId;
      targetPath = ref.read(panelStateProvider(activeTabId)).currentPath;
    }

    if (targetPath.isEmpty || targetPath.startsWith('ssh://')) {
      ref
          .read(overlayProvider.notifier)
          .showToast(
            'Bookmarks are supported for local and archive folders.',
            isError: true,
          );
      return;
    }

    final baseName = p.basename(targetPath);
    final initialName = baseName.isNotEmpty ? baseName : targetPath;

    final result = await showDialog<String>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => TextInputDialog(
        title: 'Save Bookmark',
        label: 'Bookmark Name',
        initialValue: initialName,
        okButtonLabel: 'Save',
      ),
    );

    if (result == null || result.trim().isEmpty) return;
    final name = result.trim();
    ref
        .read(userSettingsProvider.notifier)
        .addBookmark(Bookmark(name: name, path: targetPath));
    ref.read(overlayProvider.notifier).showToast('Bookmark saved: $name');
  }

  /// Resolves two local regular file paths for side-by-side comparison.
  ///
  /// Priority:
  /// 1. Two local files selected in the active panel.
  /// 2. Focused/selected file in left panel vs focused/selected (or same-named)
  ///    file in right panel.
  static (String, String)? resolveCompareFilePaths(
    WidgetRef ref, {
    List<FileSystemItem>? explicitItems,
  }) {
    bool isComparableFile(FileSystemItem item) =>
        !item.isDirectory &&
        !item.isParentDetails &&
        !item.path.startsWith('ssh://') &&
        !ItemMetadataService.isZipPath(item.path);

    if (explicitItems != null && explicitItems.length == 2) {
      if (isComparableFile(explicitItems[0]) &&
          isComparableFile(explicitItems[1])) {
        return (explicitItems[0].path, explicitItems[1].path);
      }
    }

    final activePanelId = ref.read(focusProvider.notifier).getActivePanelId();
    final oppositePanelId = activePanelId == 'left' ? 'right' : 'left';
    final activeTabId = ref.read(panelTabsProvider(activePanelId)).activeTabId;
    final oppositeTabId = ref
        .read(panelTabsProvider(oppositePanelId))
        .activeTabId;

    final activeState = ref.read(panelStateProvider(activeTabId));
    final oppositeState = ref.read(panelStateProvider(oppositeTabId));

    // Case 1: Exactly two comparable files selected in active panel
    final activeSelected = activeState.items
        .where(
          (item) =>
              activeState.selectedItems.contains(item.path) &&
              isComparableFile(item),
        )
        .toList();
    if (activeSelected.length == 2) {
      return (activeSelected[0].path, activeSelected[1].path);
    }

    // Case 2: Compare one file from left panel with one file from right panel
    FileSystemItem? pickSingleFile(PanelState state) {
      final selected = state.items
          .where(
            (item) =>
                state.selectedItems.contains(item.path) &&
                isComparableFile(item),
          )
          .toList();
      if (selected.length == 1) return selected.first;
      if (state.focusedIndex >= 0 && state.focusedIndex < state.items.length) {
        final focused = state.items[state.focusedIndex];
        if (isComparableFile(focused)) return focused;
      }
      return null;
    }

    final activeFile = pickSingleFile(activeState);
    if (activeFile == null) return null;

    FileSystemItem? oppositeFile = pickSingleFile(oppositeState);
    oppositeFile ??= oppositeState.items.cast<FileSystemItem?>().firstWhere(
      (item) =>
          item != null &&
          isComparableFile(item) &&
          item.name == activeFile.name,
      orElse: () => null,
    );

    if (oppositeFile == null) return null;

    return activePanelId == 'left'
        ? (activeFile.path, oppositeFile.path)
        : (oppositeFile.path, activeFile.path);
  }

  /// Opens the side-by-side file comparison dialog or shows an explanatory toast.
  static Future<void> openCompareFiles(
    BuildContext context,
    WidgetRef ref, {
    List<FileSystemItem>? explicitItems,
  }) async {
    final pair = resolveCompareFilePaths(ref, explicitItems: explicitItems);
    if (pair == null) {
      ref
          .read(overlayProvider.notifier)
          .showToast(
            'Select two local text files or focus a file in each panel to compare.',
            isError: true,
          );
      return;
    }

    await showFileDiffDialog(context, leftPath: pair.$1, rightPath: pair.$2);
  }

  /// Opens the POSIX permissions editor dialog for [item] (or active focused item).
  static Future<void> openEditPermissions(
    BuildContext context,
    WidgetRef ref, {
    FileSystemItem? item,
    String? currentPath,
  }) async {
    FileSystemItem? targetItem = item;
    String activePath = currentPath ?? '';

    if (targetItem == null) {
      final activePanelId = ref.read(focusProvider.notifier).getActivePanelId();
      final activeTabId = ref
          .read(panelTabsProvider(activePanelId))
          .activeTabId;
      final panelState = ref.read(panelStateProvider(activeTabId));
      activePath = panelState.currentPath;
      if (panelState.focusedIndex >= 0 &&
          panelState.focusedIndex < panelState.items.length) {
        targetItem = panelState.items[panelState.focusedIndex];
      }
    }

    if (targetItem == null || targetItem.isParentDetails) {
      ref
          .read(overlayProvider.notifier)
          .showToast(
            'Focus a file or folder to edit permissions.',
            isError: true,
          );
      return;
    }

    final isRemote = targetItem.path.startsWith('ssh://');
    if (ItemMetadataService.isZipPath(targetItem.path) ||
        (!isRemote && Platform.isWindows)) {
      ref
          .read(overlayProvider.notifier)
          .showToast(
            'POSIX permission editing is available for local Unix/macOS and SSH items.',
            isError: true,
          );
      return;
    }

    await showPermissionsDialog(
      context,
      item: targetItem,
      currentPath: activePath,
    );
  }
}
