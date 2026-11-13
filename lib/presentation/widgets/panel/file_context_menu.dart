import 'dart:io';

import 'package:fima/domain/entity/app_theme.dart';
import 'package:fima/domain/entity/file_system_item.dart';
import 'package:fima/domain/entity/panel_state.dart';
import 'package:fima/domain/utils/fima_path.dart';
import 'package:fima/infrastructure/service/application_service.dart';
import 'package:fima/infrastructure/service/item_metadata_service.dart';
import 'package:fima/infrastructure/service/system_clipboard_service.dart';
import 'package:fima/presentation/providers/clipboard_actions.dart';
import 'package:fima/presentation/providers/file_system_provider.dart';
import 'package:fima/presentation/providers/internal_clipboard_provider.dart';
import 'package:fima/presentation/providers/operation_status_provider.dart';
import 'package:fima/presentation/providers/overlay_provider.dart';
import 'package:fima/presentation/providers/panel_feature_actions.dart';
import 'package:fima/presentation/providers/panel_tabs_provider.dart';
import 'package:fima/presentation/providers/settings_provider.dart';
import 'package:fima/presentation/providers/theme_provider.dart';
import 'package:fima/presentation/widgets/popups/application_picker_dialog.dart';
import 'package:fima/presentation/widgets/popups/delete_confirmation_dialog.dart';
import 'package:fima/presentation/widgets/popups/file_preview_dialog.dart';
import 'package:fima/presentation/widgets/popups/item_info_dialog.dart';
import 'package:fima/presentation/widgets/popups/text_input_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

enum ContextMenuAction {
  open,
  openInNewTab,
  openInOppositePanel,
  openWith,
  preview,
  extractHere,
  extractToFolder,
  extractToOpposite,
  copyToOpposite,
  moveToOpposite,
  copyToClipboard,
  cutToClipboard,
  pasteFromClipboard,
  copyPath,
  rename,
  compress,
  createDirectory,
  createFile,
  selectAll,
  deselectAll,
  toggleHiddenFiles,
  refresh,
  openTerminalHere,
  openDefaultManager,
  calculateDirectorySize,
  calculateAllDirectorySizes,
  bookmarkFolder,
  compareFiles,
  editPermissions,
  moveToTrash,
  permanentDelete,
  info,
}

class ContextMenuEntrySpec {
  final ContextMenuAction? action;
  final String? label;
  final IconData? icon;
  final String? shortcutActionId;
  final bool enabled;
  final bool isDestructive;
  final bool isDivider;

  const ContextMenuEntrySpec.item({
    required this.action,
    required this.label,
    required this.icon,
    this.shortcutActionId,
    this.enabled = true,
    this.isDestructive = false,
  }) : isDivider = false;

  const ContextMenuEntrySpec.divider()
    : action = null,
      label = null,
      icon = null,
      shortcutActionId = null,
      enabled = false,
      isDestructive = false,
      isDivider = true;
}

class FileContextMenu {
  /// Builds the context-aware menu entries for the given target state.
  static List<ContextMenuEntrySpec> buildEntries({
    required String currentPath,
    required FileSystemItem? clickedItem,
    required List<FileSystemItem> targetItems,
    required bool hasSelection,
    required bool showHiddenFiles,
    required bool canPaste,
    bool canCompareWithOpposite = false,
  }) {
    final isRemote = currentPath.startsWith('ssh://');
    final isInsideZip = !isRemote && ItemMetadataService.isZipPath(currentPath);

    // Background click (empty space in panel)
    if (clickedItem == null) {
      return _buildBackgroundEntries(
        isRemote: isRemote,
        isInsideZip: isInsideZip,
        hasSelection: hasSelection,
        showHiddenFiles: showHiddenFiles,
        canPaste: canPaste,
      );
    }

    // Parent directory ("..")
    if (clickedItem.isParentDetails) {
      return const [
        ContextMenuEntrySpec.item(
          action: ContextMenuAction.open,
          label: 'Open',
          icon: Icons.folder_open_outlined,
          shortcutActionId: 'enterDirectory',
        ),
        ContextMenuEntrySpec.item(
          action: ContextMenuAction.openInNewTab,
          label: 'Open in New Tab',
          icon: Icons.tab_outlined,
        ),
        ContextMenuEntrySpec.item(
          action: ContextMenuAction.openInOppositePanel,
          label: 'Open in Opposite Panel',
          icon: Icons.compare_arrows_outlined,
        ),
      ];
    }

    final isMulti = targetItems.length > 1;
    final count = targetItems.length;

    if (isInsideZip) {
      return _buildInsideZipEntries(
        item: clickedItem,
        isMulti: isMulti,
        count: count,
      );
    }

    if (isRemote) {
      return _buildRemoteEntries(
        item: clickedItem,
        isMulti: isMulti,
        count: count,
      );
    }

    if (isMulti) {
      final canCompareSelected =
          targetItems.length == 2 &&
          targetItems.every((e) => !e.isDirectory && !e.isParentDetails);
      return _buildLocalMultiEntries(
        count: count,
        canCompareSelected: canCompareSelected,
      );
    }

    if (clickedItem.isDirectory) {
      return _buildLocalDirectoryEntries();
    }

    if (clickedItem.name.toLowerCase().endsWith('.zip')) {
      return _buildLocalZipEntries(clickedItem);
    }

    return _buildLocalFileEntries(
      canCompareWithOpposite: canCompareWithOpposite,
    );
  }

  static List<ContextMenuEntrySpec> _buildBackgroundEntries({
    required bool isRemote,
    required bool isInsideZip,
    required bool hasSelection,
    required bool showHiddenFiles,
    required bool canPaste,
  }) {
    final entries = <ContextMenuEntrySpec>[];

    if (!isInsideZip && !isRemote) {
      entries.add(
        ContextMenuEntrySpec.item(
          action: ContextMenuAction.pasteFromClipboard,
          label: 'Paste',
          icon: Icons.content_paste_outlined,
          shortcutActionId: 'pasteFromClipboard',
          enabled: canPaste,
        ),
      );
      entries.add(const ContextMenuEntrySpec.divider());
    }

    if (!isInsideZip) {
      entries.addAll(const [
        ContextMenuEntrySpec.item(
          action: ContextMenuAction.createDirectory,
          label: 'New Folder...',
          icon: Icons.create_new_folder_outlined,
          shortcutActionId: 'createDirectory',
        ),
        ContextMenuEntrySpec.item(
          action: ContextMenuAction.createFile,
          label: 'New File...',
          icon: Icons.note_add_outlined,
          shortcutActionId: 'createFile',
        ),
        ContextMenuEntrySpec.divider(),
      ]);
    }

    entries.add(
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.selectAll,
        label: 'Select All',
        icon: Icons.select_all_outlined,
        shortcutActionId: 'selectAll',
      ),
    );
    if (hasSelection) {
      entries.add(
        const ContextMenuEntrySpec.item(
          action: ContextMenuAction.deselectAll,
          label: 'Deselect All',
          icon: Icons.deselect_outlined,
          shortcutActionId: 'deselectAll',
        ),
      );
    }

    entries.addAll([
      const ContextMenuEntrySpec.divider(),
      ContextMenuEntrySpec.item(
        action: ContextMenuAction.toggleHiddenFiles,
        label: showHiddenFiles ? 'Hide Hidden Files' : 'Show Hidden Files',
        icon: showHiddenFiles
            ? Icons.visibility_off_outlined
            : Icons.visibility_outlined,
        shortcutActionId: 'toggleHiddenFiles',
      ),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.refresh,
        label: 'Refresh',
        icon: Icons.refresh_outlined,
      ),
    ]);

    if (!isInsideZip && !isRemote) {
      entries.addAll([
        const ContextMenuEntrySpec.divider(),
        const ContextMenuEntrySpec.item(
          action: ContextMenuAction.calculateAllDirectorySizes,
          label: 'Calculate All Folder Sizes',
          icon: Icons.calculate_outlined,
          shortcutActionId: 'calculateDirectorySizes',
        ),
        const ContextMenuEntrySpec.item(
          action: ContextMenuAction.bookmarkFolder,
          label: 'Bookmark Current Folder...',
          icon: Icons.bookmark_add_outlined,
          shortcutActionId: 'saveBookmark',
        ),
        const ContextMenuEntrySpec.divider(),
        const ContextMenuEntrySpec.item(
          action: ContextMenuAction.openTerminalHere,
          label: 'Open Terminal Here',
          icon: Icons.terminal_outlined,
          shortcutActionId: 'openTerminal',
        ),
        ContextMenuEntrySpec.item(
          action: ContextMenuAction.openDefaultManager,
          label: _defaultFileManagerLabel(forFile: false),
          icon: Icons.open_in_new_outlined,
          shortcutActionId: 'openDefaultManager',
        ),
      ]);
    }

    entries.addAll(const [
      ContextMenuEntrySpec.divider(),
      ContextMenuEntrySpec.item(
        action: ContextMenuAction.info,
        label: 'Info',
        icon: Icons.info_outline,
        shortcutActionId: 'showInfo',
      ),
    ]);

    return entries;
  }

  static List<ContextMenuEntrySpec> _buildInsideZipEntries({
    required FileSystemItem item,
    required bool isMulti,
    required int count,
  }) {
    final entries = <ContextMenuEntrySpec>[];

    if (!isMulti && item.isDirectory) {
      entries.addAll(const [
        ContextMenuEntrySpec.item(
          action: ContextMenuAction.open,
          label: 'Open',
          icon: Icons.folder_open_outlined,
          shortcutActionId: 'enterDirectory',
        ),
        ContextMenuEntrySpec.item(
          action: ContextMenuAction.calculateDirectorySize,
          label: 'Calculate Size',
          icon: Icons.calculate_outlined,
        ),
      ]);
    }

    entries.addAll([
      ContextMenuEntrySpec.item(
        action: ContextMenuAction.copyToOpposite,
        label: isMulti
            ? 'Extract $count Items to Opposite Panel'
            : 'Extract to Opposite Panel',
        icon: Icons.drive_file_move_outlined,
        shortcutActionId: 'copyOperation',
      ),
      ContextMenuEntrySpec.item(
        action: ContextMenuAction.copyPath,
        label: isMulti ? 'Copy Paths' : 'Copy Path',
        icon: Icons.link_outlined,
        shortcutActionId: 'copyPath',
      ),
      const ContextMenuEntrySpec.divider(),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.info,
        label: 'Info',
        icon: Icons.info_outline,
        shortcutActionId: 'showInfo',
      ),
    ]);

    return entries;
  }

  static List<ContextMenuEntrySpec> _buildRemoteEntries({
    required FileSystemItem item,
    required bool isMulti,
    required int count,
  }) {
    final entries = <ContextMenuEntrySpec>[];

    if (!isMulti) {
      entries.add(
        const ContextMenuEntrySpec.item(
          action: ContextMenuAction.open,
          label: 'Open',
          icon: Icons.open_in_browser_outlined,
          shortcutActionId: 'enterDirectory',
        ),
      );
      if (item.isDirectory) {
        entries.addAll(const [
          ContextMenuEntrySpec.item(
            action: ContextMenuAction.openInNewTab,
            label: 'Open in New Tab',
            icon: Icons.tab_outlined,
          ),
          ContextMenuEntrySpec.item(
            action: ContextMenuAction.openInOppositePanel,
            label: 'Open in Opposite Panel',
            icon: Icons.compare_arrows_outlined,
          ),
        ]);
      }
      entries.add(const ContextMenuEntrySpec.divider());
    }

    entries.addAll([
      ContextMenuEntrySpec.item(
        action: ContextMenuAction.copyToOpposite,
        label: isMulti
            ? 'Copy $count Items to Opposite Panel'
            : 'Copy to Opposite Panel',
        icon: Icons.file_copy_outlined,
        shortcutActionId: 'copyOperation',
      ),
      ContextMenuEntrySpec.item(
        action: ContextMenuAction.moveToOpposite,
        label: isMulti
            ? 'Move $count Items to Opposite Panel'
            : 'Move to Opposite Panel',
        icon: Icons.drive_file_move_outlined,
        shortcutActionId: 'moveOperation',
      ),
      ContextMenuEntrySpec.item(
        action: ContextMenuAction.copyPath,
        label: isMulti ? 'Copy Paths' : 'Copy Path',
        icon: Icons.link_outlined,
        shortcutActionId: 'copyPath',
      ),
    ]);

    if (!isMulti) {
      entries.addAll(const [
        ContextMenuEntrySpec.divider(),
        ContextMenuEntrySpec.item(
          action: ContextMenuAction.rename,
          label: 'Rename',
          icon: Icons.drive_file_rename_outline,
          shortcutActionId: 'rename',
        ),
        ContextMenuEntrySpec.item(
          action: ContextMenuAction.editPermissions,
          label: 'Permissions...',
          icon: Icons.lock_outline,
          shortcutActionId: 'editPermissions',
        ),
      ]);
    }

    entries.addAll([
      const ContextMenuEntrySpec.divider(),
      ContextMenuEntrySpec.item(
        action: ContextMenuAction.permanentDelete,
        label: isMulti
            ? 'Delete $count Items Permanently'
            : 'Delete Permanently',
        icon: Icons.delete_forever_outlined,
        shortcutActionId: 'permanentDelete',
        isDestructive: true,
      ),
      const ContextMenuEntrySpec.divider(),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.info,
        label: 'Info',
        icon: Icons.info_outline,
        shortcutActionId: 'showInfo',
      ),
    ]);

    return entries;
  }

  static List<ContextMenuEntrySpec> _buildLocalMultiEntries({
    required int count,
    bool canCompareSelected = false,
  }) {
    return [
      if (canCompareSelected) ...[
        const ContextMenuEntrySpec.item(
          action: ContextMenuAction.compareFiles,
          label: 'Compare Selected Files',
          icon: Icons.compare_outlined,
          shortcutActionId: 'compareFiles',
        ),
        const ContextMenuEntrySpec.divider(),
      ],
      ContextMenuEntrySpec.item(
        action: ContextMenuAction.copyToOpposite,
        label: 'Copy $count Items to Opposite Panel',
        icon: Icons.file_copy_outlined,
        shortcutActionId: 'copyOperation',
      ),
      ContextMenuEntrySpec.item(
        action: ContextMenuAction.moveToOpposite,
        label: 'Move $count Items to Opposite Panel',
        icon: Icons.drive_file_move_outlined,
        shortcutActionId: 'moveOperation',
      ),
      const ContextMenuEntrySpec.divider(),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.copyToClipboard,
        label: 'Copy',
        icon: Icons.copy_outlined,
        shortcutActionId: 'copyToClipboard',
      ),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.cutToClipboard,
        label: 'Cut',
        icon: Icons.content_cut_outlined,
        shortcutActionId: 'cutToClipboard',
      ),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.copyPath,
        label: 'Copy Paths',
        icon: Icons.link_outlined,
        shortcutActionId: 'copyPath',
      ),
      const ContextMenuEntrySpec.divider(),
      ContextMenuEntrySpec.item(
        action: ContextMenuAction.compress,
        label: 'Compress $count Items...',
        icon: Icons.folder_zip_outlined,
        shortcutActionId: 'compress',
      ),
      const ContextMenuEntrySpec.divider(),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.moveToTrash,
        label: 'Move to Trash',
        icon: Icons.delete_outline,
        shortcutActionId: 'deleteToTrash',
      ),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.permanentDelete,
        label: 'Delete Permanently',
        icon: Icons.delete_forever_outlined,
        shortcutActionId: 'permanentDelete',
        isDestructive: true,
      ),
      const ContextMenuEntrySpec.divider(),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.info,
        label: 'Info',
        icon: Icons.info_outline,
        shortcutActionId: 'showInfo',
      ),
    ];
  }

  static List<ContextMenuEntrySpec> _buildLocalDirectoryEntries() {
    return [
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.open,
        label: 'Open',
        icon: Icons.folder_open_outlined,
        shortcutActionId: 'enterDirectory',
      ),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.openInNewTab,
        label: 'Open in New Tab',
        icon: Icons.tab_outlined,
      ),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.openInOppositePanel,
        label: 'Open in Opposite Panel',
        icon: Icons.compare_arrows_outlined,
      ),
      const ContextMenuEntrySpec.divider(),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.copyToOpposite,
        label: 'Copy to Opposite Panel',
        icon: Icons.file_copy_outlined,
        shortcutActionId: 'copyOperation',
      ),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.moveToOpposite,
        label: 'Move to Opposite Panel',
        icon: Icons.drive_file_move_outlined,
        shortcutActionId: 'moveOperation',
      ),
      const ContextMenuEntrySpec.divider(),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.copyToClipboard,
        label: 'Copy',
        icon: Icons.copy_outlined,
        shortcutActionId: 'copyToClipboard',
      ),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.cutToClipboard,
        label: 'Cut',
        icon: Icons.content_cut_outlined,
        shortcutActionId: 'cutToClipboard',
      ),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.copyPath,
        label: 'Copy Path',
        icon: Icons.link_outlined,
        shortcutActionId: 'copyPath',
      ),
      const ContextMenuEntrySpec.divider(),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.rename,
        label: 'Rename',
        icon: Icons.drive_file_rename_outline,
        shortcutActionId: 'rename',
      ),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.compress,
        label: 'Compress to ZIP',
        icon: Icons.folder_zip_outlined,
        shortcutActionId: 'compress',
      ),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.calculateDirectorySize,
        label: 'Calculate Size',
        icon: Icons.calculate_outlined,
      ),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.bookmarkFolder,
        label: 'Bookmark Folder...',
        icon: Icons.bookmark_add_outlined,
      ),
      if (!Platform.isWindows)
        const ContextMenuEntrySpec.item(
          action: ContextMenuAction.editPermissions,
          label: 'Permissions...',
          icon: Icons.lock_outline,
          shortcutActionId: 'editPermissions',
        ),
      const ContextMenuEntrySpec.divider(),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.openTerminalHere,
        label: 'Open Terminal Here',
        icon: Icons.terminal_outlined,
        shortcutActionId: 'openTerminal',
      ),
      ContextMenuEntrySpec.item(
        action: ContextMenuAction.openDefaultManager,
        label: _defaultFileManagerLabel(forFile: false),
        icon: Icons.open_in_new_outlined,
        shortcutActionId: 'openDefaultManager',
      ),
      const ContextMenuEntrySpec.divider(),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.moveToTrash,
        label: 'Move to Trash',
        icon: Icons.delete_outline,
        shortcutActionId: 'deleteToTrash',
      ),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.permanentDelete,
        label: 'Delete Permanently',
        icon: Icons.delete_forever_outlined,
        shortcutActionId: 'permanentDelete',
        isDestructive: true,
      ),
      const ContextMenuEntrySpec.divider(),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.info,
        label: 'Info',
        icon: Icons.info_outline,
        shortcutActionId: 'showInfo',
      ),
    ];
  }

  static List<ContextMenuEntrySpec> _buildLocalZipEntries(FileSystemItem item) {
    final stem = p.basenameWithoutExtension(item.name);
    return [
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.open,
        label: 'Browse Archive',
        icon: Icons.folder_zip_outlined,
        shortcutActionId: 'enterDirectory',
      ),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.openInNewTab,
        label: 'Open in New Tab',
        icon: Icons.tab_outlined,
      ),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.openWith,
        label: 'Open With...',
        icon: Icons.open_with_outlined,
        shortcutActionId: 'openWith',
      ),
      const ContextMenuEntrySpec.divider(),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.extractHere,
        label: 'Extract Here',
        icon: Icons.unarchive_outlined,
        shortcutActionId: 'extractHere',
      ),
      ContextMenuEntrySpec.item(
        action: ContextMenuAction.extractToFolder,
        label: 'Extract to "$stem/"',
        icon: Icons.create_new_folder_outlined,
      ),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.extractToOpposite,
        label: 'Extract to Opposite Panel',
        icon: Icons.drive_file_move_outlined,
        shortcutActionId: 'extractToOpposite',
      ),
      const ContextMenuEntrySpec.divider(),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.copyToOpposite,
        label: 'Copy to Opposite Panel',
        icon: Icons.file_copy_outlined,
        shortcutActionId: 'copyOperation',
      ),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.moveToOpposite,
        label: 'Move to Opposite Panel',
        icon: Icons.drive_file_move_outlined,
        shortcutActionId: 'moveOperation',
      ),
      const ContextMenuEntrySpec.divider(),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.copyToClipboard,
        label: 'Copy',
        icon: Icons.copy_outlined,
        shortcutActionId: 'copyToClipboard',
      ),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.cutToClipboard,
        label: 'Cut',
        icon: Icons.content_cut_outlined,
        shortcutActionId: 'cutToClipboard',
      ),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.copyPath,
        label: 'Copy Path',
        icon: Icons.link_outlined,
        shortcutActionId: 'copyPath',
      ),
      const ContextMenuEntrySpec.divider(),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.rename,
        label: 'Rename',
        icon: Icons.drive_file_rename_outline,
        shortcutActionId: 'rename',
      ),
      if (!Platform.isWindows)
        const ContextMenuEntrySpec.item(
          action: ContextMenuAction.editPermissions,
          label: 'Permissions...',
          icon: Icons.lock_outline,
          shortcutActionId: 'editPermissions',
        ),
      ContextMenuEntrySpec.item(
        action: ContextMenuAction.openDefaultManager,
        label: _defaultFileManagerLabel(forFile: true),
        icon: Icons.open_in_new_outlined,
        shortcutActionId: 'openDefaultManager',
      ),
      const ContextMenuEntrySpec.divider(),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.moveToTrash,
        label: 'Move to Trash',
        icon: Icons.delete_outline,
        shortcutActionId: 'deleteToTrash',
      ),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.permanentDelete,
        label: 'Delete Permanently',
        icon: Icons.delete_forever_outlined,
        shortcutActionId: 'permanentDelete',
        isDestructive: true,
      ),
      const ContextMenuEntrySpec.divider(),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.info,
        label: 'Info',
        icon: Icons.info_outline,
        shortcutActionId: 'showInfo',
      ),
    ];
  }

  static List<ContextMenuEntrySpec> _buildLocalFileEntries({
    bool canCompareWithOpposite = false,
  }) {
    return [
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.open,
        label: 'Open',
        icon: Icons.open_in_browser_outlined,
        shortcutActionId: 'enterDirectory',
      ),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.openWith,
        label: 'Open With...',
        icon: Icons.open_with_outlined,
        shortcutActionId: 'openWith',
      ),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.preview,
        label: 'Preview',
        icon: Icons.preview_outlined,
        shortcutActionId: 'filePreview',
      ),
      if (canCompareWithOpposite)
        const ContextMenuEntrySpec.item(
          action: ContextMenuAction.compareFiles,
          label: 'Compare with Opposite',
          icon: Icons.compare_outlined,
          shortcutActionId: 'compareFiles',
        ),
      const ContextMenuEntrySpec.divider(),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.copyToOpposite,
        label: 'Copy to Opposite Panel',
        icon: Icons.file_copy_outlined,
        shortcutActionId: 'copyOperation',
      ),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.moveToOpposite,
        label: 'Move to Opposite Panel',
        icon: Icons.drive_file_move_outlined,
        shortcutActionId: 'moveOperation',
      ),
      const ContextMenuEntrySpec.divider(),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.copyToClipboard,
        label: 'Copy',
        icon: Icons.copy_outlined,
        shortcutActionId: 'copyToClipboard',
      ),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.cutToClipboard,
        label: 'Cut',
        icon: Icons.content_cut_outlined,
        shortcutActionId: 'cutToClipboard',
      ),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.copyPath,
        label: 'Copy Path',
        icon: Icons.link_outlined,
        shortcutActionId: 'copyPath',
      ),
      const ContextMenuEntrySpec.divider(),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.rename,
        label: 'Rename',
        icon: Icons.drive_file_rename_outline,
        shortcutActionId: 'rename',
      ),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.compress,
        label: 'Compress to ZIP',
        icon: Icons.folder_zip_outlined,
        shortcutActionId: 'compress',
      ),
      if (!Platform.isWindows)
        const ContextMenuEntrySpec.item(
          action: ContextMenuAction.editPermissions,
          label: 'Permissions...',
          icon: Icons.lock_outline,
          shortcutActionId: 'editPermissions',
        ),
      ContextMenuEntrySpec.item(
        action: ContextMenuAction.openDefaultManager,
        label: _defaultFileManagerLabel(forFile: true),
        icon: Icons.open_in_new_outlined,
        shortcutActionId: 'openDefaultManager',
      ),
      const ContextMenuEntrySpec.divider(),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.moveToTrash,
        label: 'Move to Trash',
        icon: Icons.delete_outline,
        shortcutActionId: 'deleteToTrash',
      ),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.permanentDelete,
        label: 'Delete Permanently',
        icon: Icons.delete_forever_outlined,
        shortcutActionId: 'permanentDelete',
        isDestructive: true,
      ),
      const ContextMenuEntrySpec.divider(),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.info,
        label: 'Info',
        icon: Icons.info_outline,
        shortcutActionId: 'showInfo',
      ),
    ];
  }

  static String _defaultFileManagerLabel({required bool forFile}) {
    if (Platform.isMacOS) {
      return forFile ? 'Reveal in Finder' : 'Open in Finder';
    }
    if (Platform.isWindows) {
      return forFile ? 'Show in Explorer' : 'Open in Explorer';
    }
    return 'Open in File Manager';
  }

  static Future<void> show({
    required BuildContext context,
    required WidgetRef ref,
    required Offset globalPosition,
    required String panelId,
    required String tabId,
    required PanelState panelState,
    required PanelController controller,
    FileSystemItem? clickedItem,
  }) async {
    final bool isMultiTarget =
        clickedItem != null &&
        !clickedItem.isParentDetails &&
        panelState.selectedItems.contains(clickedItem.path) &&
        panelState.selectedItems.length > 1;

    final List<FileSystemItem> targetItems;
    if (clickedItem == null) {
      targetItems = const [];
    } else if (isMultiTarget) {
      targetItems = panelState.items
          .where(
            (item) =>
                panelState.selectedItems.contains(item.path) &&
                !item.isParentDetails,
          )
          .toList();
    } else {
      targetItems = [clickedItem];
    }

    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    final showHiddenFiles = ref.read(userSettingsProvider).showHiddenFiles;
    bool canPaste = false;
    if (clickedItem == null &&
        !panelState.currentPath.startsWith('ssh://') &&
        !ItemMetadataService.isZipPath(panelState.currentPath)) {
      canPaste =
          ref.read(internalClipboardProvider).cutPaths.isNotEmpty ||
          await SystemClipboard.hasFilePaths();
    }

    if (!context.mounted) return;

    final canCompareWithOpposite =
        clickedItem != null &&
        !clickedItem.isDirectory &&
        !clickedItem.isParentDetails &&
        targetItems.length == 1 &&
        !panelState.currentPath.startsWith('ssh://') &&
        !ItemMetadataService.isZipPath(panelState.currentPath) &&
        PanelFeatureActions.resolveCompareFilePaths(ref) != null;

    final entries = buildEntries(
      currentPath: panelState.currentPath,
      clickedItem: clickedItem,
      targetItems: targetItems,
      hasSelection: panelState.selectedItems.isNotEmpty,
      showHiddenFiles: showHiddenFiles,
      canPaste: canPaste,
      canCompareWithOpposite: canCompareWithOpposite,
    );

    final fimaTheme = ref.read(themeProvider);
    final settingsController = ref.read(userSettingsProvider.notifier);

    final position = RelativeRect.fromRect(
      Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
      Offset.zero & overlay.size,
    );

    final selected = await showMenu<ContextMenuAction>(
      context: context,
      position: position,
      color: fimaTheme.surfaceColor,
      elevation: 16,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: fimaTheme.borderColor),
      ),
      constraints: const BoxConstraints(minWidth: 230, maxWidth: 320),
      items: entries
          .map(
            (entry) => _toPopupMenuEntry(
              entry: entry,
              fimaTheme: fimaTheme,
              settingsController: settingsController,
            ),
          )
          .toList(),
    );

    if (selected == null || !context.mounted) return;

    await _executeAction(
      action: selected,
      context: context,
      ref: ref,
      panelId: panelId,
      tabId: tabId,
      panelState: panelState,
      controller: controller,
      clickedItem: clickedItem,
      targetItems: targetItems,
    );
  }

  static PopupMenuEntry<ContextMenuAction> _toPopupMenuEntry({
    required ContextMenuEntrySpec entry,
    required FimaTheme fimaTheme,
    required SettingsController settingsController,
  }) {
    if (entry.isDivider) {
      return const _ThemedMenuDivider();
    }

    final shortcut = entry.shortcutActionId != null
        ? settingsController.getEffectiveShortcut(entry.shortcutActionId!)
        : null;

    final Color fgColor;
    if (!entry.enabled) {
      fgColor = fimaTheme.secondaryTextColor.withValues(alpha: 0.45);
    } else if (entry.isDestructive) {
      fgColor = Colors.redAccent;
    } else {
      fgColor = fimaTheme.textColor;
    }

    return PopupMenuItem<ContextMenuAction>(
      value: entry.action,
      enabled: entry.enabled,
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(
            entry.icon,
            size: 15,
            color: entry.isDestructive
                ? fgColor
                : entry.enabled
                ? fimaTheme.secondaryTextColor
                : fgColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.label ?? '',
              style: TextStyle(fontSize: 12.5, color: fgColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (shortcut != null && shortcut.isNotEmpty) ...[
            const SizedBox(width: 16),
            Text(
              shortcut,
              style: TextStyle(
                fontSize: 11,
                color: fimaTheme.secondaryTextColor.withValues(
                  alpha: entry.enabled ? 0.75 : 0.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Future<void> _executeAction({
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
          final applications = ApplicationService().getInstalledApplications();
          if (!context.mounted) return;
          final selectedApp = await ApplicationPickerDialog.show(
            context,
            applications,
          );
          if (selectedApp != null) {
            await controller.openWithApplication(selectedApp, clickedItem.path);
          }
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
          if (destPath.isNotEmpty) {
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
        await _handleCompress(context, controller, targetItems);
        break;
      case ContextMenuAction.createDirectory:
        if (panelState.currentPath.isEmpty) return;
        final dirName = await showDialog<String>(
          context: context,
          barrierColor: Colors.transparent,
          builder: (ctx) => const TextInputDialog(
            title: 'Create Directory',
            label: 'Directory Name',
            okButtonLabel: 'Create',
          ),
        );
        if (dirName != null && dirName.isNotEmpty) {
          await controller.createDirectory(dirName);
        }
        break;
      case ContextMenuAction.createFile:
        if (panelState.currentPath.isEmpty) return;
        final fileName = await showDialog<String>(
          context: context,
          barrierColor: Colors.transparent,
          builder: (ctx) => const TextInputDialog(
            title: 'Create File',
            label: 'File Name',
            okButtonLabel: 'Create',
          ),
        );
        if (fileName != null && fileName.isNotEmpty) {
          await controller.createFile(fileName);
        }
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
        if (termPath.isNotEmpty &&
            !FimaPath.isSshPath(termPath) &&
            !FimaPath.isZipPath(termPath)) {
          final useBuiltIn = ref.read(userSettingsProvider).useBuiltInTerminal;
          if (useBuiltIn) {
            ref
                .read(overlayProvider.notifier)
                .showTerminal(panelId == 'left', termPath, tabId: tabId);
          } else {
            await controller.openTerminal(termPath);
          }
        }
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
        final count = targetItems.length;
        if (count > 0) {
          final confirmed = await showDialog<bool>(
            context: context,
            barrierColor: Colors.transparent,
            builder: (ctx) => DeleteConfirmationDialog(count: count),
          );
          if (confirmed == true) {
            await controller.deleteSelectedItems(permanent: true);
          }
        }
        break;
      case ContextMenuAction.info:
        final infoItems = targetItems.isNotEmpty
            ? targetItems
            : [
                FileSystemItem(
                  path: panelState.currentPath,
                  name: p.basename(panelState.currentPath).isEmpty
                      ? panelState.currentPath
                      : p.basename(panelState.currentPath),
                  size: 0,
                  modified: DateTime.now(),
                  isDirectory: true,
                ),
              ];
        await showItemInfoDialog(
          context,
          items: infoItems,
          currentPath: panelState.currentPath,
        );
        break;
    }
  }

  static Future<void> _handleCompress(
    BuildContext context,
    PanelController controller,
    List<FileSystemItem> targetItems,
  ) async {
    final paths = targetItems.map((e) => e.path).toList();
    if (paths.isEmpty) return;

    if (paths.length == 1) {
      final zipName = '${p.basename(paths.first)}.zip';
      await controller.compressItems(paths, zipName);
      await controller.refresh();
    } else {
      final name = await showDialog<String>(
        context: context,
        barrierColor: Colors.transparent,
        builder: (ctx) => const TextInputDialog(
          title: 'Compress Items',
          label: 'Archive Name (e.g. archive.zip)',
          okButtonLabel: 'Compress',
        ),
      );
      if (name != null && name.isNotEmpty) {
        final zipName = name.toLowerCase().endsWith('.zip')
            ? name
            : '$name.zip';
        await controller.compressItems(paths, zipName);
        await controller.refresh();
      }
    }
  }
}

class _ThemedMenuDivider extends PopupMenuEntry<ContextMenuAction> {
  const _ThemedMenuDivider();

  @override
  double get height => 9;

  @override
  bool represents(ContextMenuAction? value) => false;

  @override
  State<_ThemedMenuDivider> createState() => _ThemedMenuDividerState();
}

class _ThemedMenuDividerState extends State<_ThemedMenuDivider> {
  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final fimaTheme = ref.watch(themeProvider);
        return Divider(
          height: 9,
          thickness: 1,
          color: fimaTheme.borderColor.withValues(alpha: 0.7),
        );
      },
    );
  }
}
