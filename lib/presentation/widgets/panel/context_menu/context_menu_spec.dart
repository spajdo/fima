import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'package:fima/domain/entity/file_system_item.dart';
import 'package:fima/domain/utils/fima_path.dart';

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

/// Builds context-aware menu entries for local, ZIP archive, and SSH targets.
class ContextMenuBuilder {
  const ContextMenuBuilder._();

  static List<ContextMenuEntrySpec> buildEntries({
    required String currentPath,
    required FileSystemItem? clickedItem,
    required List<FileSystemItem> targetItems,
    required bool hasSelection,
    required bool showHiddenFiles,
    required bool canPaste,
    bool canCompareWithOpposite = false,
  }) {
    final isRemote = FimaPath.isSshPath(currentPath);
    final isInsideZip = !isRemote && FimaPath.isZipPath(currentPath);

    if (clickedItem == null) {
      return _buildBackgroundEntries(
        isRemote: isRemote,
        isInsideZip: isInsideZip,
        hasSelection: hasSelection,
        showHiddenFiles: showHiddenFiles,
        canPaste: canPaste,
      );
    }

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

    entries.addAll(_infoSection());
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
      ..._infoSection(),
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
      ..._transferEntries(isMulti: isMulti, count: count),
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
      ..._infoSection(),
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
      ..._transferEntries(isMulti: true, count: count),
      const ContextMenuEntrySpec.divider(),
      ..._clipboardEntries(copyPathLabel: 'Copy Paths'),
      const ContextMenuEntrySpec.divider(),
      ContextMenuEntrySpec.item(
        action: ContextMenuAction.compress,
        label: 'Compress $count Items...',
        icon: Icons.folder_zip_outlined,
        shortcutActionId: 'compress',
      ),
      ..._localDeleteAndInfoSection(),
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
      ..._transferEntries(isMulti: false, count: 1),
      const ContextMenuEntrySpec.divider(),
      ..._clipboardEntries(copyPathLabel: 'Copy Path'),
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
      if (!Platform.isWindows) _permissionsEntry(),
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
      ..._localDeleteAndInfoSection(),
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
      ..._transferEntries(isMulti: false, count: 1),
      const ContextMenuEntrySpec.divider(),
      ..._clipboardEntries(copyPathLabel: 'Copy Path'),
      const ContextMenuEntrySpec.divider(),
      const ContextMenuEntrySpec.item(
        action: ContextMenuAction.rename,
        label: 'Rename',
        icon: Icons.drive_file_rename_outline,
        shortcutActionId: 'rename',
      ),
      if (!Platform.isWindows) _permissionsEntry(),
      ContextMenuEntrySpec.item(
        action: ContextMenuAction.openDefaultManager,
        label: _defaultFileManagerLabel(forFile: true),
        icon: Icons.open_in_new_outlined,
        shortcutActionId: 'openDefaultManager',
      ),
      ..._localDeleteAndInfoSection(),
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
      ..._transferEntries(isMulti: false, count: 1),
      const ContextMenuEntrySpec.divider(),
      ..._clipboardEntries(copyPathLabel: 'Copy Path'),
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
      if (!Platform.isWindows) _permissionsEntry(),
      ContextMenuEntrySpec.item(
        action: ContextMenuAction.openDefaultManager,
        label: _defaultFileManagerLabel(forFile: true),
        icon: Icons.open_in_new_outlined,
        shortcutActionId: 'openDefaultManager',
      ),
      ..._localDeleteAndInfoSection(),
    ];
  }

  static List<ContextMenuEntrySpec> _transferEntries({
    required bool isMulti,
    required int count,
  }) {
    return [
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
    ];
  }

  static List<ContextMenuEntrySpec> _clipboardEntries({
    required String copyPathLabel,
  }) {
    return [
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
      ContextMenuEntrySpec.item(
        action: ContextMenuAction.copyPath,
        label: copyPathLabel,
        icon: Icons.link_outlined,
        shortcutActionId: 'copyPath',
      ),
    ];
  }

  static ContextMenuEntrySpec _permissionsEntry() {
    return const ContextMenuEntrySpec.item(
      action: ContextMenuAction.editPermissions,
      label: 'Permissions...',
      icon: Icons.lock_outline,
      shortcutActionId: 'editPermissions',
    );
  }

  static List<ContextMenuEntrySpec> _localDeleteAndInfoSection() {
    return const [
      ContextMenuEntrySpec.divider(),
      ContextMenuEntrySpec.item(
        action: ContextMenuAction.moveToTrash,
        label: 'Move to Trash',
        icon: Icons.delete_outline,
        shortcutActionId: 'deleteToTrash',
      ),
      ContextMenuEntrySpec.item(
        action: ContextMenuAction.permanentDelete,
        label: 'Delete Permanently',
        icon: Icons.delete_forever_outlined,
        shortcutActionId: 'permanentDelete',
        isDestructive: true,
      ),
      ContextMenuEntrySpec.divider(),
      ContextMenuEntrySpec.item(
        action: ContextMenuAction.info,
        label: 'Info',
        icon: Icons.info_outline,
        shortcutActionId: 'showInfo',
      ),
    ];
  }

  static List<ContextMenuEntrySpec> _infoSection() {
    return const [
      ContextMenuEntrySpec.divider(),
      ContextMenuEntrySpec.item(
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
}
