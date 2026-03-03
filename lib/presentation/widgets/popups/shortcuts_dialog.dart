import 'dart:io';

import 'package:fima/presentation/providers/settings_provider.dart';
import 'package:fima/presentation/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A grouped shortcut entry shown in the cheat-sheet dialog.
class _ShortcutEntry {
  final String label;
  final String shortcut;
  const _ShortcutEntry(this.label, this.shortcut);
}

/// A named category of shortcuts.
class _ShortcutCategory {
  final String title;
  final List<_ShortcutEntry> entries;
  const _ShortcutCategory(this.title, this.entries);
}

class ShortcutsDialog extends ConsumerStatefulWidget {
  const ShortcutsDialog({super.key});

  @override
  ConsumerState<ShortcutsDialog> createState() => _ShortcutsDialogState();
}

class _ShortcutsDialogState extends ConsumerState<ShortcutsDialog> {
  final FocusNode _okFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _okFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _okFocusNode.dispose();
    super.dispose();
  }

  List<_ShortcutCategory> _buildCategories(bool isMac) {
    final settings = ref.read(userSettingsProvider.notifier);

    String s(String id) => settings.getEffectiveShortcut(id) ?? '';

    return [
      _ShortcutCategory('NAVIGATION', [
        _ShortcutEntry('Move Up', s('moveUp')),
        _ShortcutEntry('Move Down', s('moveDown')),
        _ShortcutEntry('Jump to Top', s('jumpToTop')),
        _ShortcutEntry('Jump to Bottom', s('jumpToBottom')),
        _ShortcutEntry('Move to First', s('moveToFirst')),
        _ShortcutEntry('Move to Last', s('moveToLast')),
        _ShortcutEntry('Enter Directory / Open File', s('enterDirectory')),
        _ShortcutEntry('Navigate to Parent', s('navigateParent')),
        _ShortcutEntry('Switch Panel', s('switchPanel')),
        _ShortcutEntry('Toggle Selection', s('toggleSelection')),
      ]),
      _ShortcutCategory('SEARCH & FILTER', [
        _ShortcutEntry('Quick Filter', 'Type any text'),
        _ShortcutEntry('Clear Quick Filter', s('clearQuickFilter')),
        _ShortcutEntry('Clear Filter / Close Overlay', s('clearFilter')),
        _ShortcutEntry('Jump to Folder', s('omniPanelPaths')),
        _ShortcutEntry('Actions Menu', s('omniPanelActions')),
      ]),
      _ShortcutCategory('FILE OPERATIONS', [
        _ShortcutEntry('Rename', s('rename')),
        _ShortcutEntry('Copy', s('copyOperation')),
        _ShortcutEntry('Move', s('moveOperation')),
        _ShortcutEntry('Create Directory', s('createDirectory')),
        _ShortcutEntry('Create File', s('createFile')),
        _ShortcutEntry('Move to Trash', s('deleteToTrash')),
        _ShortcutEntry('Permanent Delete', s('permanentDelete')),
        _ShortcutEntry('File Preview', s('filePreview')),
        _ShortcutEntry('Open With...', s('openWith')),
        _ShortcutEntry('Open Default File Manager', s('openDefaultManager')),
        _ShortcutEntry('Toggle Hidden Files', s('toggleHiddenFiles')),
      ]),
      _ShortcutCategory('CLIPBOARD', [
        _ShortcutEntry('Copy to Clipboard', s('copyToClipboard')),
        _ShortcutEntry('Cut to Clipboard', s('cutToClipboard')),
        _ShortcutEntry('Paste from Clipboard', s('pasteFromClipboard')),
        _ShortcutEntry('Copy Path', s('copyPath')),
      ]),
      _ShortcutCategory('SELECTION', [
        _ShortcutEntry('Select All', s('selectAll')),
        _ShortcutEntry('Deselect All', s('deselectAll')),
      ]),
      _ShortcutCategory('ARCHIVES', [
        _ShortcutEntry('Compress', s('compress')),
        _ShortcutEntry('Extract Here', s('extractHere')),
        _ShortcutEntry('Extract to Opposite Panel', s('extractToOpposite')),
      ]),
      _ShortcutCategory('WORKSPACES & REMOTE', [
        _ShortcutEntry('Workspaces', s('workspaceDialog')),
        _ShortcutEntry('Save as Workspace', s('saveWorkspace')),
        _ShortcutEntry('Connect to Server', s('connectToServer')),
        _ShortcutEntry('Remote Connections', s('remoteDialog')),
      ]),
      _ShortcutCategory('APP', [
        _ShortcutEntry('Settings', s('settings')),
        _ShortcutEntry('Open Terminal', s('openTerminal')),
        _ShortcutEntry('Show All Shortcuts', s('showShortcuts')),
      ]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final isMac = Platform.isMacOS;
    final categories = _buildCategories(isMac);

    // Split into 3 roughly equal columns
    final col1 = <_ShortcutCategory>[];
    final col2 = <_ShortcutCategory>[];
    final col3 = <_ShortcutCategory>[];
    final cols = [col1, col2, col3];
    final counts = [0, 0, 0];

    for (final cat in categories) {
      // Find the column with fewest items
      int minIdx = 0;
      for (int i = 1; i < 3; i++) {
        if (counts[i] < counts[minIdx]) minIdx = i;
      }
      cols[minIdx].add(cat);
      counts[minIdx] += cat.entries.length + 2; // +2 for header
    }

    final headerStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: theme.textColor,
      letterSpacing: 1.2,
    );

    final labelStyle = TextStyle(fontSize: 13.5, color: theme.textColor);

    final shortcutStyle = TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
      color: theme.accentColor,
    );

    Widget buildColumn(List<_ShortcutCategory> cats) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final cat in cats) ...[
          Container(
            width: double.infinity,
            color: theme.borderColor.withOpacity(0.3),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(cat.title, style: headerStyle),
          ),
          for (final e in cat.entries)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      e.label,
                      style: labelStyle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(e.shortcut, style: shortcutStyle),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      ],
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1050, maxHeight: 780),
        decoration: BoxDecoration(
          color: theme.backgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.surfaceColor,
                border: Border(bottom: BorderSide(color: theme.borderColor)),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(9),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.keyboard_outlined,
                    size: 18,
                    color: theme.secondaryTextColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'fima  ·  Keyboard Shortcuts',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.textColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 16,
                      color: theme.secondaryTextColor,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 16,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Body: 3 columns
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: buildColumn(col1)),
                      Container(
                        width: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        color: theme.borderColor.withOpacity(0.4),
                      ),
                      Expanded(child: buildColumn(col2)),
                      Container(
                        width: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        color: theme.borderColor.withOpacity(0.4),
                      ),
                      Expanded(child: buildColumn(col3)),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: theme.surfaceColor,
                border: Border(top: BorderSide(color: theme.borderColor)),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(9),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton(
                    focusNode: _okFocusNode,
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 10,
                      ),
                      backgroundColor: theme.accentColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
