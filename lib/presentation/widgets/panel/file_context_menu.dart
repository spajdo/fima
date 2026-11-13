import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fima/domain/entity/app_theme.dart';
import 'package:fima/domain/entity/file_system_item.dart';
import 'package:fima/domain/entity/panel_state.dart';
import 'package:fima/domain/utils/fima_path.dart';
import 'package:fima/infrastructure/service/system_clipboard_service.dart';
import 'package:fima/presentation/providers/file_system_provider.dart';
import 'package:fima/presentation/providers/internal_clipboard_provider.dart';
import 'package:fima/presentation/providers/panel_feature_actions.dart';
import 'package:fima/presentation/providers/settings_provider.dart';
import 'package:fima/presentation/providers/theme_provider.dart';
import 'package:fima/presentation/widgets/panel/context_menu/context_menu_executor.dart';
import 'package:fima/presentation/widgets/panel/context_menu/context_menu_spec.dart';

export 'package:fima/presentation/widgets/panel/context_menu/context_menu_spec.dart';

/// Displays themed right-click context menus for panel files, folders, and
/// empty directory space.
class FileContextMenu {
  static List<ContextMenuEntrySpec> buildEntries({
    required String currentPath,
    required FileSystemItem? clickedItem,
    required List<FileSystemItem> targetItems,
    required bool hasSelection,
    required bool showHiddenFiles,
    required bool canPaste,
    bool canCompareWithOpposite = false,
  }) {
    return ContextMenuBuilder.buildEntries(
      currentPath: currentPath,
      clickedItem: clickedItem,
      targetItems: targetItems,
      hasSelection: hasSelection,
      showHiddenFiles: showHiddenFiles,
      canPaste: canPaste,
      canCompareWithOpposite: canCompareWithOpposite,
    );
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
        !FimaPath.isSshPath(panelState.currentPath) &&
        !FimaPath.isZipPath(panelState.currentPath)) {
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
        !FimaPath.isSshPath(panelState.currentPath) &&
        !FimaPath.isZipPath(panelState.currentPath) &&
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

    await ContextMenuExecutor.execute(
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
