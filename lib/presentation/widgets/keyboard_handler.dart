import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fima/domain/entity/file_system_item.dart';
import 'package:fima/domain/entity/key_map_action.dart';
import 'package:fima/domain/entity/workspace.dart';
import 'package:fima/domain/utils/fima_path.dart';
import 'package:fima/infrastructure/service/application_service.dart';
import 'package:fima/infrastructure/service/keyboard_utils.dart';
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

const _keyRepeatInitialDelay = Duration(milliseconds: 150);
const _keyRepeatInterval = Duration(milliseconds: 50);

class KeyboardHandler extends ConsumerStatefulWidget {
  final Widget child;

  const KeyboardHandler({super.key, required this.child});

  @override
  ConsumerState<KeyboardHandler> createState() => _KeyboardHandlerState();
}

class _KeyboardHandlerState extends ConsumerState<KeyboardHandler> {
  final Map<LogicalKeyboardKey, Timer> _keyRepeatTimers = {};

  void _startKeyRepeat(
    BuildContext context,
    WidgetRef ref,
    LogicalKeyboardKey key,
  ) {
    _stopKeyRepeat(key);

    void moveAction() {
      final focusController = ref.read(focusProvider.notifier);
      final activePanelId = focusController.getActivePanelId();
      final activeTabId = ref
          .read(panelTabsProvider(activePanelId))
          .activeTabId;
      final panelController = ref.read(
        panelStateProvider(activeTabId).notifier,
      );

      if (key == LogicalKeyboardKey.arrowUp) {
        panelController.moveSelectionUp();
      } else if (key == LogicalKeyboardKey.arrowDown) {
        panelController.moveSelectionDown();
      } else if (key == LogicalKeyboardKey.arrowLeft) {
        panelController.moveToFirst();
      } else if (key == LogicalKeyboardKey.arrowRight) {
        panelController.moveToLast();
      } else if (key == LogicalKeyboardKey.home) {
        panelController.moveToFirst();
      } else if (key == LogicalKeyboardKey.end) {
        panelController.moveToLast();
      }
    }

    moveAction();

    _keyRepeatTimers[key] = Timer(_keyRepeatInitialDelay, () {
      if (_keyRepeatTimers.containsKey(key)) {
        moveAction();
        _keyRepeatTimers[key] = Timer.periodic(_keyRepeatInterval, (_) {
          if (_keyRepeatTimers.containsKey(key)) {
            moveAction();
          }
        });
      }
    });
  }

  void _stopKeyRepeat(LogicalKeyboardKey key) {
    _keyRepeatTimers[key]?.cancel();
    _keyRepeatTimers.remove(key);
  }

  @override
  void dispose() {
    for (final timer in _keyRepeatTimers.values) {
      timer.cancel();
    }
    _keyRepeatTimers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardFocusNode = ref.watch(keyboardHandlerFocusNodeProvider);
    return Focus(
      focusNode: keyboardFocusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        final isNavigationKey =
            event.logicalKey == LogicalKeyboardKey.arrowUp ||
            event.logicalKey == LogicalKeyboardKey.arrowDown ||
            event.logicalKey == LogicalKeyboardKey.arrowLeft ||
            event.logicalKey == LogicalKeyboardKey.arrowRight ||
            event.logicalKey == LogicalKeyboardKey.home ||
            event.logicalKey == LogicalKeyboardKey.end;

        if (event is KeyUpEvent) {
          if (isNavigationKey) {
            _stopKeyRepeat(event.logicalKey);
          }
          return KeyEventResult.ignored;
        }

        final focusController = ref.read(focusProvider.notifier);
        final activePanelId = focusController.getActivePanelId();
        final activeTabId = ref
            .read(panelTabsProvider(activePanelId))
            .activeTabId;
        final panelController = ref.read(
          panelStateProvider(activeTabId).notifier,
        );
        final currentPanelState = ref.read(panelStateProvider(activeTabId));

        // If renaming or editing the path bar is in progress, disable all
        // panel shortcuts; the active field handles Escape, Enter, and input.
        if (currentPanelState.editingPath != null ||
            currentPanelState.isEditingPath) {
          return KeyEventResult.ignored;
        }

        // If overlay is active, handle ESC or ignore before panel navigation/shortcuts.
        final overlayState = ref.read(overlayProvider);
        if (overlayState.isActive) {
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            // Terminal overlay intercepts Escape itself (confirmation dialog).
            if (overlayState.type == OverlayType.terminal) {
              return KeyEventResult.ignored;
            }
            ref.read(overlayProvider.notifier).close();
            return KeyEventResult.handled;
          }

          if (overlayState.type == OverlayType.terminal) {
            // When terminal is open, only block keys while the terminal's
            // own panel is active. If the user switched to the opposite
            // panel we fall through and let the normal key-processing run.
            final focusState = ref.read(focusProvider);
            final terminalIsLeft = overlayState.isLeftPanel;
            final activeIsLeft = focusState.activePanel == ActivePanel.left;
            if (terminalIsLeft == activeIsLeft) {
              // Same panel as terminal -> let the terminal handle keys.
              return KeyEventResult.ignored;
            }
            // Opposite panel is active -> fall through to normal handling.
          } else {
            // Non-terminal overlay (settings, etc.) - swallow all keys.
            return KeyEventResult.ignored;
          }
        }

        final hasAnyModifier =
            HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed ||
            HardwareKeyboard.instance.isAltPressed ||
            HardwareKeyboard.instance.isShiftPressed;

        if (isNavigationKey && !hasAnyModifier) {
          if (event is KeyDownEvent) {
            _startKeyRepeat(context, ref, event.logicalKey);
            return KeyEventResult.handled;
          }
          if (event is KeyRepeatEvent) {
            // Timer already drives held navigation repeat; avoid double move.
            return KeyEventResult.handled;
          }
        }

        // Handle Backspace for quick filter
        if (event.logicalKey == LogicalKeyboardKey.backspace) {
          if (HardwareKeyboard.instance.isControlPressed) {
            if (currentPanelState.quickFilterText.isNotEmpty) {
              panelController.clearQuickFilter();
              return KeyEventResult.handled;
            }
          } else if (currentPanelState.quickFilterText.isNotEmpty) {
            final filterText = currentPanelState.quickFilterText;
            final newText = filterText.substring(0, filterText.length - 1);
            if (newText.isEmpty) {
              panelController.clearQuickFilter();
            } else {
              panelController.setQuickFilter(newText);
            }
            return KeyEventResult.handled;
          }
        }

        // Check for custom keyboard shortcuts.
        // Shortcuts execute regardless of quick-filter state: filter input only
        // captures plain characters without modifiers, so modifier/function-key
        // shortcuts (Ctrl+C, F2, Delete, …) cannot conflict with filter typing.
        final currentShortcut = KeyboardUtils.buildShortcutString(event);
        if (currentShortcut.isNotEmpty) {
          final actionId = ref
              .read(userSettingsProvider.notifier)
              .findActionByShortcut(currentShortcut);
          if (actionId != null) {
            // Skip global actions -- they are handled by GlobalHotkeyService,
            // not the in-app keyboard handler.
            final action = KeyMapActionDefs.getById(actionId);
            if (action != null && action.isGlobal) {
              return KeyEventResult.ignored;
            }

            final result = _handleCustomShortcut(
              ref,
              context,
              actionId,
              activePanelId,
              activeTabId,
              panelController,
              currentPanelState,
              currentShortcut,
            );
            if (result != null) {
              return result;
            }
          }
        }

        // QuickFilter: plain printable character keys (no Ctrl/Alt/Meta)
        if (!HardwareKeyboard.instance.isControlPressed &&
            !HardwareKeyboard.instance.isMetaPressed &&
            !HardwareKeyboard.instance.isAltPressed) {
          final character = event.character;
          if (character != null &&
              character.length == 1 &&
              !character.contains('\n') &&
              !character.contains('\r') &&
              !character.contains('\t') &&
              character.codeUnitAt(0) >= 32) {
            final newText = currentPanelState.quickFilterText + character;
            panelController.setQuickFilter(newText);
            return KeyEventResult.handled;
          }
        }

        return KeyEventResult.ignored;
      },
      child: widget.child,
    );
  }

  Future<void> _openTerminal(String path) async {
    // Linux generic way to open terminal
    // Try generic emulator first, then specific ones
    if (Platform.isLinux) {
      try {
        // Try x-terminal-emulator first (Debian/Ubuntu/standard alternative)
        await Process.run('x-terminal-emulator', [], workingDirectory: path);
      } catch (e) {
        // Fallbacks
        final terminals = [
          'gnome-terminal',
          'konsole',
          'xfce4-terminal',
          'mate-terminal',
          'terminator',
          'xterm',
        ];
        for (final terminal in terminals) {
          try {
            // Most terminals accept working directory as is or need --working-directory
            // But Process.run workingDirectory argument usually handles it if the terminal respects cwd
            await Process.run(terminal, [], workingDirectory: path);
            return; // Success
          } catch (_) {
            // Continue to next
          }
        }
        debugPrint('Could not find a supported terminal to open.');
      }
    } else if (Platform.isMacOS) {
      // Mac implementation
      try {
        await Process.run('open', ['-a', 'Terminal', path]);
      } catch (e) {
        debugPrint('Error opening Mac terminal: $e');
      }
    } else if (Platform.isWindows) {
      // Windows implementation
      try {
        await Process.run('cmd', [
          '/K',
          'start',
          'cd',
          '/d',
          path,
        ], runInShell: true);
      } catch (e) {
        debugPrint('Error opening Windows terminal: $e');
      }
    }
  }

  Future<void> _openFileManager(String path) async {
    if (Platform.isLinux) {
      try {
        await Process.run('xdg-open', [path]);
      } catch (e) {
        debugPrint('Error opening file manager: $e');
      }
    } else if (Platform.isMacOS) {
      try {
        await Process.run('open', [path]);
      } catch (e) {
        debugPrint('Error opening file manager: $e');
      }
    } else if (Platform.isWindows) {
      try {
        await Process.run('explorer', [path]);
      } catch (e) {
        debugPrint('Error opening file manager: $e');
      }
    }
  }

  void _openWithApplication(BuildContext context, WidgetRef ref) {
    final activePanelId = ref.read(focusProvider.notifier).getActivePanelId();
    final activeTabId = ref.read(panelTabsProvider(activePanelId)).activeTabId;
    final panelState = ref.read(panelStateProvider(activeTabId));
    String? targetPath;

    if (panelState.selectedItems.isNotEmpty) {
      targetPath = panelState.selectedItems.first;
    } else if (panelState.focusedIndex >= 0 &&
        panelState.focusedIndex < panelState.items.length &&
        !panelState.items[panelState.focusedIndex].isParentDetails) {
      targetPath = panelState.items[panelState.focusedIndex].path;
    }

    if (targetPath == null || targetPath.isEmpty) return;

    final appService = ApplicationService();
    final applications = appService.getInstalledApplications();

    ApplicationPickerDialog.show(context, applications).then((selectedApp) {
      if (selectedApp != null) {
        ref
            .read(panelStateProvider(activeTabId).notifier)
            .openWithApplication(selectedApp, targetPath!);
      }
    });
  }

  void _copyPathToClipboard(WidgetRef ref, String activeTabId) {
    final panelState = ref.read(panelStateProvider(activeTabId));
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

  KeyEventResult? _handleCustomShortcut(
    WidgetRef ref,
    BuildContext context,
    String actionId,
    String activePanelId,
    String activeTabId,
    dynamic panelController,
    dynamic currentPanelState,
    String currentShortcut,
  ) {
    switch (actionId) {
      case 'moveUp':
        panelController.moveSelectionUp();
        return KeyEventResult.handled;
      case 'moveDown':
        panelController.moveSelectionDown();
        return KeyEventResult.handled;
      case 'moveToFirst':
        panelController.moveToFirst();
        return KeyEventResult.handled;
      case 'moveToLast':
        panelController.moveToLast();
        return KeyEventResult.handled;
      case 'jumpToTop':
        panelController.moveToFirst();
        return KeyEventResult.handled;
      case 'jumpToBottom':
        panelController.moveToLast();
        return KeyEventResult.handled;
      case 'enterDirectory':
        panelController.enterFocusedItem();
        return KeyEventResult.handled;
      case 'navigateParent':
        panelController.navigateToParent();
        return KeyEventResult.handled;
      case 'toggleSelection':
        panelController.toggleSelectionAtFocus();
        return KeyEventResult.handled;
      case 'selectAll':
        panelController.selectAll();
        return KeyEventResult.handled;
      case 'deselectAll':
        panelController.deselectAll();
        return KeyEventResult.handled;
      case 'copyToClipboard':
        ref
            .read(clipboardActionsProvider)
            .copyOrCut(activeTabId, ClipboardOperation.copy);
        return KeyEventResult.handled;
      case 'cutToClipboard':
        ref
            .read(clipboardActionsProvider)
            .copyOrCut(activeTabId, ClipboardOperation.cut);
        return KeyEventResult.handled;
      case 'pasteFromClipboard':
        ref.read(clipboardActionsProvider).paste(activeTabId);
        return KeyEventResult.handled;
      case 'switchPanel':
        ref.read(focusProvider.notifier).switchPanel();
        return KeyEventResult.handled;
      case 'newTab':
        ref.read(panelTabsProvider(activePanelId).notifier).createTab();
        return KeyEventResult.handled;
      case 'closeTab':
        ref.read(panelTabsProvider(activePanelId).notifier).closeActiveTab();
        return KeyEventResult.handled;
      case 'nextTab':
        ref.read(panelTabsProvider(activePanelId).notifier).nextTab();
        return KeyEventResult.handled;
      case 'previousTab':
        ref.read(panelTabsProvider(activePanelId).notifier).previousTab();
        return KeyEventResult.handled;
      case 'toggleHiddenFiles':
        ref.read(userSettingsProvider.notifier).toggleShowHiddenFiles();
        return KeyEventResult.handled;
      case 'deleteToTrash':
        panelController.deleteSelectedItems(permanent: false);
        return KeyEventResult.handled;
      case 'permanentDelete':
        _showDeleteConfirmation(context, ref, activeTabId, permanent: true);
        return KeyEventResult.handled;
      case 'copyOperation':
        ref.read(operationStatusProvider.notifier).startCopy();
        return KeyEventResult.handled;
      case 'moveOperation':
        ref.read(operationStatusProvider.notifier).startMove();
        return KeyEventResult.handled;
      case 'compress':
        _showCompressDialog(
          context,
          ref,
          activeTabId,
          panelController,
          currentPanelState,
        );
        return KeyEventResult.handled;
      case 'rename':
        panelController.startRenaming();
        return KeyEventResult.handled;
      case 'createDirectory':
        _showCreateDialog(context, ref, activeTabId, isDirectory: true);
        return KeyEventResult.handled;
      case 'createFile':
        _showCreateDialog(context, ref, activeTabId, isDirectory: false);
        return KeyEventResult.handled;
      case 'openTerminal':
        final path = ref.read(panelStateProvider(activeTabId)).currentPath;
        if (path.isNotEmpty &&
            !FimaPath.isSshPath(path) &&
            !FimaPath.isZipPath(path)) {
          final useBuiltIn = ref.read(userSettingsProvider).useBuiltInTerminal;
          if (useBuiltIn) {
            final focusState = ref.read(focusProvider);
            final isLeftPanel = focusState.activePanel == ActivePanel.left;
            ref
                .read(overlayProvider.notifier)
                .showTerminal(isLeftPanel, path, tabId: activeTabId);
          } else {
            _openTerminal(path);
          }
        }
        return KeyEventResult.handled;
      case 'openWith':
        _openWithApplication(context, ref);
        return KeyEventResult.handled;
      case 'openDefaultManager':
        final path = ref.read(panelStateProvider(activeTabId)).currentPath;
        if (path.isNotEmpty) {
          _openFileManager(path);
        }
        return KeyEventResult.handled;
      case 'saveWorkspace':
        _showSaveWorkspaceDialog(context, ref);
        return KeyEventResult.handled;
      case 'settings':
        final focusState = ref.read(focusProvider);
        final isLeftPanel = focusState.activePanel == ActivePanel.left;
        ref.read(overlayProvider.notifier).showSettings(isLeftPanel);
        return KeyEventResult.handled;
      case 'workspaceDialog':
        showDialog(
          context: context,
          barrierColor: Colors.transparent,
          builder: (context) => const OmniDialog(initialText: 'w '),
        );
        return KeyEventResult.handled;
      case 'remoteDialog':
        showDialog(
          context: context,
          barrierColor: Colors.transparent,
          builder: (context) => const OmniDialog(initialText: 'r '),
        );
        return KeyEventResult.handled;
      case 'editPath':
        panelController.startEditingPath();
        return KeyEventResult.handled;
      case 'connectToServer':
        showDialog(
          context: context,
          barrierColor: Colors.black54,
          builder: (context) => const ConnectServerDialog(),
        );
        return KeyEventResult.handled;
      case 'omniPanelPaths':
        showDialog(
          context: context,
          barrierColor: Colors.transparent,
          builder: (context) => const OmniDialog(initialText: ''),
        );
        return KeyEventResult.handled;
      case 'omniPanelActions':
        showDialog(
          context: context,
          barrierColor: Colors.transparent,
          builder: (context) => const OmniDialog(initialText: '>'),
        );
        return KeyEventResult.handled;
      case 'clearQuickFilter':
        panelController.clearQuickFilter();
        return KeyEventResult.handled;
      case 'clearFilter':
        if (currentPanelState.quickFilterText.isNotEmpty) {
          panelController.clearQuickFilter();
        }
        return KeyEventResult.handled;
      case 'showShortcuts':
        showDialog(
          context: context,
          barrierColor: Colors.black54,
          builder: (context) => const ShortcutsDialog(),
        );
        return KeyEventResult.handled;
      case 'copyPath':
        _copyPathToClipboard(ref, activeTabId);
        return KeyEventResult.handled;
      case 'extractHere':
        if (currentPanelState.focusedIndex >= 0 &&
            currentPanelState.focusedIndex < currentPanelState.items.length) {
          final item = currentPanelState.items[currentPanelState.focusedIndex];
          if (!item.isParentDetails &&
              item.path.toLowerCase().endsWith('.zip') &&
              !FimaPath.isSshPath(item.path)) {
            panelController
                .extractArchive(item.path, currentPanelState.currentPath)
                .then((_) {
                  panelController.refresh();
                });
          }
        }
        return KeyEventResult.handled;
      case 'extractToOpposite':
        if (currentPanelState.focusedIndex >= 0 &&
            currentPanelState.focusedIndex < currentPanelState.items.length) {
          final item = currentPanelState.items[currentPanelState.focusedIndex];
          if (!item.isParentDetails &&
              item.path.toLowerCase().endsWith('.zip') &&
              !FimaPath.isSshPath(item.path)) {
            final oppositePanelId = activePanelId == 'left' ? 'right' : 'left';
            final oppositeTabId = ref
                .read(panelTabsProvider(oppositePanelId))
                .activeTabId;
            final destPath = ref
                .read(panelStateProvider(oppositeTabId))
                .currentPath;
            if (!FimaPath.isSshPath(destPath) &&
                !FimaPath.isZipPath(destPath)) {
              panelController.extractArchive(item.path, destPath).then((_) {
                ref.read(panelStateProvider(oppositeTabId).notifier).refresh();
              });
            }
          }
        }
        return KeyEventResult.handled;
      case 'filePreview':
        _showFilePreviewDialog(context, ref, activeTabId);
        return KeyEventResult.handled;
      case 'showInfo':
        _showInfoDialog(context, ref, activeTabId);
        return KeyEventResult.handled;
      case 'saveBookmark':
        PanelFeatureActions.promptSaveBookmark(context, ref);
        return KeyEventResult.handled;
      case 'bookmarkDialog':
        showDialog(
          context: context,
          barrierColor: Colors.transparent,
          builder: (context) => const OmniDialog(initialText: 'b '),
        );
        return KeyEventResult.handled;
      case 'calculateDirectorySizes':
        panelController.calculateAllDirectorySizes();
        return KeyEventResult.handled;
      case 'compareFiles':
        PanelFeatureActions.openCompareFiles(context, ref);
        return KeyEventResult.handled;
      case 'editPermissions':
        PanelFeatureActions.openEditPermissions(context, ref);
        return KeyEventResult.handled;
      default:
        return null;
    }
  }

  void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    String activeTabId, {
    required bool permanent,
  }) {
    final panelState = ref.read(panelStateProvider(activeTabId));
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
          ref
              .read(panelStateProvider(activeTabId).notifier)
              .deleteSelectedItems(permanent: permanent);
        }
      });
    }
  }

  void _showFilePreviewDialog(
    BuildContext context,
    WidgetRef ref,
    String activeTabId,
  ) {
    final panelState = ref.read(panelStateProvider(activeTabId));
    if (panelState.focusedIndex >= 0 &&
        panelState.focusedIndex < panelState.items.length) {
      final item = panelState.items[panelState.focusedIndex];
      if (!item.isDirectory && !item.isParentDetails) {
        showFilePreviewDialog(context, item);
      }
    }
  }

  void _showInfoDialog(
    BuildContext context,
    WidgetRef ref,
    String activeTabId,
  ) {
    final panelState = ref.read(panelStateProvider(activeTabId));
    List<FileSystemItem> targetItems = panelState.items
        .where(
          (item) =>
              panelState.selectedItems.contains(item.path) &&
              !item.isParentDetails,
        )
        .toList();

    if (targetItems.isEmpty &&
        panelState.focusedIndex >= 0 &&
        panelState.focusedIndex < panelState.items.length) {
      final focused = panelState.items[panelState.focusedIndex];
      if (!focused.isParentDetails) {
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

  void _showCreateDialog(
    BuildContext context,
    WidgetRef ref,
    String activeTabId, {
    required bool isDirectory,
  }) {
    final panelState = ref.read(panelStateProvider(activeTabId));
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
        final controller = ref.read(panelStateProvider(activeTabId).notifier);
        if (isDirectory) {
          controller.createDirectory(name.toString());
        } else {
          controller.createFile(name.toString());
        }
      }
    });
  }

  void _showSaveWorkspaceDialog(BuildContext context, WidgetRef ref) {
    final leftTabsState = ref.read(panelTabsProvider('left'));
    final rightTabsState = ref.read(panelTabsProvider('right'));

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
        ref.read(userSettingsProvider.notifier).addWorkspace(workspace);
      }
    });
  }

  void _showCompressDialog(
    BuildContext context,
    WidgetRef ref,
    String activePanelId,
    dynamic panelController,
    dynamic panelState,
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

    if (paths.isEmpty) return;

    if (paths.length == 1) {
      // Single item: compress directly using its name
      final itemName = FimaPath.basename(paths.first);
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
