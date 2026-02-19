import 'dart:io';

class KeyMapAction {
  final String id;
  final String label;
  final String defaultShortcutLinux;
  final String defaultShortcutMacOS;
  final bool isEditable;

  const KeyMapAction({
    required this.id,
    required this.label,
    required this.defaultShortcutLinux,
    required this.defaultShortcutMacOS,
    this.isEditable = true,
  });

  String get defaultShortcut {
    if (Platform.isMacOS) {
      return defaultShortcutMacOS;
    }
    return defaultShortcutLinux;
  }

  String get platformModifier {
    if (Platform.isMacOS) {
      return '⌘';
    }
    return 'Ctrl';
  }
}

class KeyMapActionDefs {
  static const List<KeyMapAction> all = [
    KeyMapAction(
      id: 'moveUp',
      label: 'Move Up',
      defaultShortcutLinux: 'Arrow Up',
      defaultShortcutMacOS: 'Arrow Up',
    ),
    KeyMapAction(
      id: 'moveDown',
      label: 'Move Down',
      defaultShortcutLinux: 'Arrow Down',
      defaultShortcutMacOS: 'Arrow Down',
    ),
    KeyMapAction(
      id: 'moveToFirst',
      label: 'Move to First',
      defaultShortcutLinux: 'Home',
      defaultShortcutMacOS: 'Home',
    ),
    KeyMapAction(
      id: 'moveToLast',
      label: 'Move to Last',
      defaultShortcutLinux: 'End',
      defaultShortcutMacOS: 'End',
    ),
    KeyMapAction(
      id: 'jumpToTop',
      label: 'Jump to Top',
      defaultShortcutLinux: 'Arrow Left',
      defaultShortcutMacOS: 'Arrow Left',
    ),
    KeyMapAction(
      id: 'jumpToBottom',
      label: 'Jump to Bottom',
      defaultShortcutLinux: 'Arrow Right',
      defaultShortcutMacOS: 'Arrow Right',
    ),
    KeyMapAction(
      id: 'enterDirectory',
      label: 'Enter Directory / Open File',
      defaultShortcutLinux: 'Enter',
      defaultShortcutMacOS: 'Enter',
    ),
    KeyMapAction(
      id: 'navigateParent',
      label: 'Navigate to Parent',
      defaultShortcutLinux: 'Backspace',
      defaultShortcutMacOS: 'Backspace',
    ),
    KeyMapAction(
      id: 'toggleSelection',
      label: 'Toggle Selection',
      defaultShortcutLinux: 'Space',
      defaultShortcutMacOS: 'Space',
    ),
    KeyMapAction(
      id: 'selectAll',
      label: 'Select All',
      defaultShortcutLinux: 'Ctrl+A',
      defaultShortcutMacOS: '⌘+A',
    ),
    KeyMapAction(
      id: 'deselectAll',
      label: 'Deselect All',
      defaultShortcutLinux: 'Ctrl+D',
      defaultShortcutMacOS: '⌘+D',
    ),
    KeyMapAction(
      id: 'copyToClipboard',
      label: 'Copy to Clipboard',
      defaultShortcutLinux: 'Ctrl+C',
      defaultShortcutMacOS: '⌘+C',
    ),
    KeyMapAction(
      id: 'cutToClipboard',
      label: 'Cut to Clipboard',
      defaultShortcutLinux: 'Ctrl+X',
      defaultShortcutMacOS: '⌘+X',
    ),
    KeyMapAction(
      id: 'pasteFromClipboard',
      label: 'Paste from Clipboard',
      defaultShortcutLinux: 'Ctrl+V',
      defaultShortcutMacOS: '⌘+V',
    ),
    KeyMapAction(
      id: 'switchPanel',
      label: 'Switch Panel',
      defaultShortcutLinux: 'Tab',
      defaultShortcutMacOS: 'Tab',
    ),
    KeyMapAction(
      id: 'toggleHiddenFiles',
      label: 'Toggle Hidden Files',
      defaultShortcutLinux: 'Ctrl+H',
      defaultShortcutMacOS: '⌘+H',
    ),
    KeyMapAction(
      id: 'deleteToTrash',
      label: 'Move to Trash',
      defaultShortcutLinux: 'Delete',
      defaultShortcutMacOS: 'Delete',
    ),
    KeyMapAction(
      id: 'permanentDelete',
      label: 'Permanent Delete',
      defaultShortcutLinux: 'Shift+Delete',
      defaultShortcutMacOS: 'Shift+Delete',
    ),
    KeyMapAction(
      id: 'copyOperation',
      label: 'Copy Operation',
      defaultShortcutLinux: 'F5',
      defaultShortcutMacOS: 'F5',
    ),
    KeyMapAction(
      id: 'moveOperation',
      label: 'Move Operation',
      defaultShortcutLinux: 'F6',
      defaultShortcutMacOS: 'F6',
    ),
    KeyMapAction(
      id: 'rename',
      label: 'Rename',
      defaultShortcutLinux: 'F2',
      defaultShortcutMacOS: 'F2',
    ),
    KeyMapAction(
      id: 'createDirectory',
      label: 'Create Directory',
      defaultShortcutLinux: 'F7',
      defaultShortcutMacOS: 'F7',
    ),
    KeyMapAction(
      id: 'createFile',
      label: 'Create File',
      defaultShortcutLinux: 'F8',
      defaultShortcutMacOS: 'F8',
    ),
    KeyMapAction(
      id: 'openTerminal',
      label: 'Open Terminal',
      defaultShortcutLinux: 'F9',
      defaultShortcutMacOS: 'F9',
    ),
    KeyMapAction(
      id: 'openWith',
      label: 'Open With...',
      defaultShortcutLinux: 'F4',
      defaultShortcutMacOS: 'F4',
    ),
    KeyMapAction(
      id: 'openDefaultManager',
      label: 'Open Default File Manager',
      defaultShortcutLinux: 'F10',
      defaultShortcutMacOS: 'F10',
    ),
    KeyMapAction(
      id: 'saveWorkspace',
      label: 'Save as Workspace',
      defaultShortcutLinux: 'Ctrl+Shift+S',
      defaultShortcutMacOS: '⌘+Shift+S',
    ),
    KeyMapAction(
      id: 'settings',
      label: 'Open Settings',
      defaultShortcutLinux: 'Ctrl+Alt+S',
      defaultShortcutMacOS: '⌘+Alt+S',
    ),
    KeyMapAction(
      id: 'omniPanelPaths',
      label: 'Omni Panel (Paths)',
      defaultShortcutLinux: 'Ctrl+P',
      defaultShortcutMacOS: '⌘+P',
      isEditable: false,
    ),
    KeyMapAction(
      id: 'omniPanelActions',
      label: 'Omni Panel (Actions)',
      defaultShortcutLinux: 'Ctrl+Shift+P',
      defaultShortcutMacOS: '⌘+Shift+P',
      isEditable: false,
    ),
    KeyMapAction(
      id: 'workspaceDialog',
      label: 'Workspace Dialog',
      defaultShortcutLinux: 'Ctrl+W',
      defaultShortcutMacOS: '⌘+W',
    ),
    KeyMapAction(
      id: 'clearQuickFilter',
      label: 'Clear Quick Filter',
      defaultShortcutLinux: 'Ctrl+Backspace',
      defaultShortcutMacOS: '⌘+Backspace',
    ),
    KeyMapAction(
      id: 'clearFilter',
      label: 'Clear Filter',
      defaultShortcutLinux: 'Escape',
      defaultShortcutMacOS: 'Escape',
    ),
  ];

  static KeyMapAction? getById(String id) {
    try {
      return all.firstWhere((action) => action.id == id);
    } catch (_) {
      return null;
    }
  }

  static String? getDefaultShortcut(String id) {
    final action = getById(id);
    return action?.defaultShortcut;
  }
}
