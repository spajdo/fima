import 'dart:io';

class KeyMapAction {
  final String id;
  final String label;
  final String defaultShortcutLinux;
  final String defaultShortcutMacOS;
  final bool isEditable;
  final bool showInOmniPanel;
  final int? omniPanelOrder;

  const KeyMapAction({
    required this.id,
    required this.label,
    required this.defaultShortcutLinux,
    required this.defaultShortcutMacOS,
    this.isEditable = true,
    this.showInOmniPanel = false,
    this.omniPanelOrder,
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
      id: 'copyPath',
      label: 'Copy Path',
      defaultShortcutLinux: 'Ctrl+Shift+C',
      defaultShortcutMacOS: '⌃ + ⇧ + C',
      showInOmniPanel: true,
      omniPanelOrder: 1,
    ),
    KeyMapAction(
      id: 'openTerminal',
      label: 'Open Terminal',
      defaultShortcutLinux: 'F9',
      defaultShortcutMacOS: 'F9',
      showInOmniPanel: true,
      omniPanelOrder: 2,
    ),
    KeyMapAction(
      id: 'copyOperation',
      label: 'Copy',
      defaultShortcutLinux: 'F5',
      defaultShortcutMacOS: 'F5',
      showInOmniPanel: true,
      omniPanelOrder: 3,
    ),
    KeyMapAction(
      id: 'moveOperation',
      label: 'Move',
      defaultShortcutLinux: 'F6',
      defaultShortcutMacOS: 'F6',
      showInOmniPanel: true,
      omniPanelOrder: 4,
    ),
    KeyMapAction(
      id: 'rename',
      label: 'Rename',
      defaultShortcutLinux: 'F2',
      defaultShortcutMacOS: 'F2',
      showInOmniPanel: true,
      omniPanelOrder: 5,
    ),
    KeyMapAction(
      id: 'createDirectory',
      label: 'Create Directory',
      defaultShortcutLinux: 'F7',
      defaultShortcutMacOS: 'F7',
      showInOmniPanel: true,
      omniPanelOrder: 6,
    ),
    KeyMapAction(
      id: 'createFile',
      label: 'Create File',
      defaultShortcutLinux: 'F8',
      defaultShortcutMacOS: 'F8',
      showInOmniPanel: true,
      omniPanelOrder: 7,
    ),
    KeyMapAction(
      id: 'openWith',
      label: 'Open With...',
      defaultShortcutLinux: 'F4',
      defaultShortcutMacOS: 'F4',
      showInOmniPanel: true,
      omniPanelOrder: 8,
    ),
    KeyMapAction(
      id: 'openDefaultManager',
      label: 'Open Default File Manager',
      defaultShortcutLinux: 'F10',
      defaultShortcutMacOS: 'F10',
      showInOmniPanel: true,
      omniPanelOrder: 9,
    ),
    KeyMapAction(
      id: 'saveWorkspace',
      label: 'Save as Workspace',
      defaultShortcutLinux: 'Ctrl+Shift+S',
      defaultShortcutMacOS: '⌘ + ⇧ + S',
      showInOmniPanel: true,
      omniPanelOrder: 10,
    ),
    KeyMapAction(
      id: 'deleteToTrash',
      label: 'Move to Trash',
      defaultShortcutLinux: 'Delete',
      defaultShortcutMacOS: 'Delete',
      showInOmniPanel: true,
      omniPanelOrder: 11,
    ),
    KeyMapAction(
      id: 'permanentDelete',
      label: 'Permanent Delete',
      defaultShortcutLinux: 'Shift+Delete',
      defaultShortcutMacOS: 'Shift+Delete',
      showInOmniPanel: true,
      omniPanelOrder: 12,
    ),
    KeyMapAction(
      id: 'toggleHiddenFiles',
      label: 'Toggle Hidden Files',
      defaultShortcutLinux: 'Ctrl+H',
      defaultShortcutMacOS: '⌘ + H',
      showInOmniPanel: true,
      omniPanelOrder: 13,
    ),
    KeyMapAction(
      id: 'copyToClipboard',
      label: 'Copy to Clipboard',
      defaultShortcutLinux: 'Ctrl+C',
      defaultShortcutMacOS: '⌘ + C',
      showInOmniPanel: true,
      omniPanelOrder: 14,
    ),
    KeyMapAction(
      id: 'cutToClipboard',
      label: 'Cut to Clipboard',
      defaultShortcutLinux: 'Ctrl+X',
      defaultShortcutMacOS: '⌘ + X',
      showInOmniPanel: true,
      omniPanelOrder: 15,
    ),
    KeyMapAction(
      id: 'pasteFromClipboard',
      label: 'Paste from Clipboard',
      defaultShortcutLinux: 'Ctrl+V',
      defaultShortcutMacOS: '⌘ + V',
      showInOmniPanel: true,
      omniPanelOrder: 16,
    ),
    KeyMapAction(
      id: 'selectAll',
      label: 'Select All',
      defaultShortcutLinux: 'Ctrl+A',
      defaultShortcutMacOS: '⌘ + A',
      showInOmniPanel: true,
      omniPanelOrder: 17,
    ),
    KeyMapAction(
      id: 'deselectAll',
      label: 'Deselect All',
      defaultShortcutLinux: 'Ctrl+D',
      defaultShortcutMacOS: '⌘ + D',
      showInOmniPanel: true,
      omniPanelOrder: 18,
    ),
    KeyMapAction(
      id: 'jumpToTop',
      label: 'Jump to Top',
      defaultShortcutLinux: 'Arrow Left',
      defaultShortcutMacOS: 'Arrow Left',
      showInOmniPanel: true,
      omniPanelOrder: 19,
    ),
    KeyMapAction(
      id: 'jumpToBottom',
      label: 'Jump to Bottom',
      defaultShortcutLinux: 'Arrow Right',
      defaultShortcutMacOS: 'Arrow Right',
      showInOmniPanel: true,
      omniPanelOrder: 20,
    ),
    KeyMapAction(
      id: 'clearQuickFilter',
      label: 'Clear Quick Filter',
      defaultShortcutLinux: 'Ctrl+Backspace',
      defaultShortcutMacOS: '⌘ + ⌫',
      showInOmniPanel: true,
      omniPanelOrder: 21,
    ),
    KeyMapAction(
      id: 'workspaceDialog',
      label: 'Workspace Dialog',
      defaultShortcutLinux: 'Ctrl+W',
      defaultShortcutMacOS: '⌘ + W',
      showInOmniPanel: true,
      omniPanelOrder: 22,
    ),
    KeyMapAction(
      id: 'settings',
      label: 'Settings',
      defaultShortcutLinux: 'Ctrl+Alt+S',
      defaultShortcutMacOS: '⌘ + ,',
      showInOmniPanel: true,
      omniPanelOrder: 23,
    ),
    KeyMapAction(
      id: 'moveUp',
      label: 'Move Up',
      defaultShortcutLinux: 'Arrow Up',
      defaultShortcutMacOS: 'Arrow Up',
      showInOmniPanel: false,
    ),
    KeyMapAction(
      id: 'moveDown',
      label: 'Move Down',
      defaultShortcutLinux: 'Arrow Down',
      defaultShortcutMacOS: 'Arrow Down',
      showInOmniPanel: false,
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
      id: 'switchPanel',
      label: 'Switch Panel',
      defaultShortcutLinux: 'Tab',
      defaultShortcutMacOS: 'Tab',
    ),
    KeyMapAction(
      id: 'clearFilter',
      label: 'Clear Filter',
      defaultShortcutLinux: 'Escape',
      defaultShortcutMacOS: 'Escape',
    ),
    KeyMapAction(
      id: 'omniPanelPaths',
      label: 'Omni Panel (Paths)',
      defaultShortcutLinux: 'Ctrl+P',
      defaultShortcutMacOS: '⌘ + P',
      isEditable: false,
    ),
    KeyMapAction(
      id: 'omniPanelActions',
      label: 'Omni Panel (Actions)',
      defaultShortcutLinux: 'Ctrl+Shift+P',
      defaultShortcutMacOS: '⌘ + ⇧ + P',
      isEditable: false,
    ),
  ];

  static String normalizeShortcut(String shortcut) {
    if (shortcut.isEmpty) return '';
    final parts = shortcut.split('+').map((p) => p.trim()).toList();
    parts.sort();
    return parts.join('+');
  }

  static bool shortcutsMatch(String shortcut1, String shortcut2) {
    if (shortcut1.isEmpty && shortcut2.isEmpty) return true;
    if (shortcut1.isEmpty || shortcut2.isEmpty) return false;
    return normalizeShortcut(shortcut1) == normalizeShortcut(shortcut2);
  }

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

  static List<KeyMapAction> get omniPanelActions =>
      all.where((action) => action.showInOmniPanel).toList();
}
