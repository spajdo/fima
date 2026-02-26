import 'dart:io';

import 'package:fima/domain/entity/file_operation.dart';
import 'package:fima/domain/entity/workspace.dart';
import 'package:fima/infrastructure/service/keyboard_utils.dart';
import 'package:fima/infrastructure/service/linux_application_service.dart';
import 'package:fima/infrastructure/service/system_clipboard_service.dart';
import 'package:fima/presentation/providers/file_system_provider.dart';
import 'package:fima/presentation/providers/focus_provider.dart';
import 'package:fima/presentation/providers/internal_clipboard_provider.dart';
import 'package:fima/presentation/providers/operation_status_provider.dart';
import 'package:fima/presentation/providers/overlay_provider.dart';
import 'package:fima/presentation/providers/settings_provider.dart';
import 'package:fima/presentation/widgets/popups/application_picker_dialog.dart';
import 'package:fima/presentation/widgets/popups/delete_confirmation_dialog.dart';
import 'package:fima/presentation/widgets/popups/omni_dialog.dart';
import 'package:fima/presentation/widgets/popups/text_input_dialog.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      final panelController = ref.read(
        panelStateProvider(activePanelId).notifier,
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
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        final isNavigationKey =
            event.logicalKey == LogicalKeyboardKey.arrowUp ||
            event.logicalKey == LogicalKeyboardKey.arrowDown ||
            event.logicalKey == LogicalKeyboardKey.arrowLeft ||
            event.logicalKey == LogicalKeyboardKey.arrowRight ||
            event.logicalKey == LogicalKeyboardKey.home ||
            event.logicalKey == LogicalKeyboardKey.end;

        if (event is KeyDownEvent) {
          if (isNavigationKey) {
            _startKeyRepeat(context, ref, event.logicalKey);
            return KeyEventResult.ignored;
          }
          // Continue processing for other keys (Enter, Tab, Backspace, etc.)
        }

        if (event is KeyUpEvent) {
          if (isNavigationKey) {
            _stopKeyRepeat(event.logicalKey);
          }
          return KeyEventResult.ignored;
        }

        final focusController = ref.read(focusProvider.notifier);
        final activePanelId = focusController.getActivePanelId();
        final panelController = ref.read(
          panelStateProvider(activePanelId).notifier,
        );
        final currentPanelState = ref.read(panelStateProvider(activePanelId));

        // If renaming is in progress, disable all keyboard shortcuts
        // The RenameField will handle Escape, Enter, and text input.
        if (currentPanelState.editingPath != null) {
          return KeyEventResult.ignored;
        }

        // If overlay is active, handle ESC to close it
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
              // Same panel as terminal → let the terminal handle keys.
              return KeyEventResult.ignored;
            }
            // Opposite panel is active → fall through to normal handling.
          } else {
            // Non-terminal overlay (settings, etc.) – swallow all keys.
            return KeyEventResult.ignored;
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

        // Check for custom keyboard shortcuts
        // Skip if QuickFilter is active (let quick filter handling take priority)
        final currentShortcut = KeyboardUtils.buildShortcutString(event);
        if (currentShortcut.isNotEmpty &&
            currentPanelState.quickFilterText.isEmpty) {
          final actionId = ref
              .read(userSettingsProvider.notifier)
              .findActionByShortcut(currentShortcut);
          if (actionId != null) {
            final result = _handleCustomShortcut(
              ref,
              context,
              actionId,
              activePanelId,
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
    final panelState = ref.read(panelStateProvider(activePanelId));
    String? targetPath;

    if (panelState.selectedItems.isNotEmpty) {
      targetPath = panelState.selectedItems.first;
    } else if (panelState.focusedIndex >= 0 &&
        panelState.focusedIndex < panelState.items.length &&
        !panelState.items[panelState.focusedIndex].isParentDetails) {
      targetPath = panelState.items[panelState.focusedIndex].path;
    }

    if (targetPath == null || targetPath.isEmpty) return;

    final appService = LinuxApplicationService();
    final applications = appService.getInstalledApplications();

    ApplicationPickerDialog.show(context, applications).then((selectedApp) {
      if (selectedApp != null) {
        ref
            .read(panelStateProvider(activePanelId).notifier)
            .openWithApplication(selectedApp, targetPath!);
      }
    });
  }

  Future<void> _copyToClipboard(
    WidgetRef ref,
    String activePanelId,
    ClipboardOperation operation,
  ) async {
    final panelState = ref.read(panelStateProvider(activePanelId));
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

    if (paths.isNotEmpty) {
      await SystemClipboard.setFilePaths(paths, operation);

      if (operation == ClipboardOperation.cut) {
        ref
            .read(internalClipboardProvider.notifier)
            .setCutPaths(paths, panelState.currentPath);
      } else {
        ref.read(internalClipboardProvider.notifier).clearCutPaths();
      }
    }
  }

  void _copyPathToClipboard(WidgetRef ref, String activePanelId) {
    final panelState = ref.read(panelStateProvider(activePanelId));
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

  Future<void> _pasteFromClipboard(WidgetRef ref, String activePanelId) async {
    final clipboardData = await SystemClipboard.getFilePaths();
    final destPath = ref.read(panelStateProvider(activePanelId)).currentPath;

    if (destPath.isEmpty) return;

    final internalClipboard = ref.read(internalClipboardProvider);
    final repository = ref.read(fileSystemRepositoryProvider);

    // Check if we have internal cut paths that match the clipboard
    bool isInternalCut = false;
    List<String> paths;

    if (clipboardData != null) {
      paths = clipboardData.$1;

      // Check if clipboard matches our internal cut state
      if (internalClipboard.cutPaths.isNotEmpty &&
          paths.length == internalClipboard.cutPaths.length &&
          internalClipboard.cutSourcePath != null &&
          paths.every((p) => internalClipboard.cutPaths.contains(p))) {
        isInternalCut = true;
      }
    } else if (internalClipboard.cutPaths.isNotEmpty) {
      // No clipboard data but we have internal cut - use that
      paths = internalClipboard.cutPaths;
      isInternalCut = true;
    } else {
      return;
    }

    if (paths.isEmpty) return;

    // Determine source path for comparison
    String? sourcePath;
    if (isInternalCut && internalClipboard.cutSourcePath != null) {
      sourcePath = internalClipboard.cutSourcePath;
    } else if (paths.isNotEmpty) {
      // Get source directory from first path
      final firstPath = paths.first;
      final lastSlash = firstPath.lastIndexOf('/');
      if (lastSlash > 0) {
        sourcePath = firstPath.substring(0, lastSlash);
      }
    }

    // Check if pasting to same location - need to handle specially
    bool isSameLocation = sourcePath != null && sourcePath == destPath;

    if (isInternalCut) {
      // Move operation (cut + paste)
      List<String> finalPaths = paths;

      // If moving to same location, no need to rename, just refresh
      if (!isSameLocation) {
        final stream = repository.moveItems(
          finalPaths,
          destPath,
          CancellationToken(),
        );
        await for (final _ in stream) {
          // Wait for completion
        }
      }

      // Clear clipboard and internal state
      ref.read(internalClipboardProvider.notifier).clearCutPaths();

      // Refresh both panels
      final sourcePanelId = ref
          .read(focusProvider.notifier)
          .getInactivePanelId();

      // Compute which item to focus in the source panel after the move.
      // The panel state is still unmodified in Riverpod at this point.
      final sourcePanelState = ref.read(panelStateProvider(sourcePanelId));
      String? sourceSelectPath;
      final remaining = sourcePanelState.items
          .where((item) => !finalPaths.contains(item.path))
          .toList();
      if (remaining.isNotEmpty) {
        final focusedIdx = sourcePanelState.focusedIndex;
        if (focusedIdx >= 0 &&
            focusedIdx < sourcePanelState.items.length &&
            !finalPaths.contains(sourcePanelState.items[focusedIdx].path)) {
          // Focused item wasn't moved → keep it.
          sourceSelectPath = sourcePanelState.items[focusedIdx].path;
        } else {
          // Focused item moved → slide to the next item (or last if at end).
          final targetIdx = focusedIdx.clamp(0, remaining.length - 1);
          sourceSelectPath = remaining[targetIdx].path;
        }
      }

      ref
          .read(panelStateProvider(sourcePanelId).notifier)
          .loadPath(sourcePath!, selectItemPath: sourceSelectPath);
      ref
          .read(panelStateProvider(activePanelId).notifier)
          .loadPath(destPath, preserveFocusedIndex: true);
      return;
    } else {
      // Copy operation
      if (isSameLocation) {
        // Generate new names and copy with new names
        final newPaths = _generateCopyNames(paths, destPath);

        for (int i = 0; i < paths.length; i++) {
          final sourceFile = paths[i];
          final destFile = newPaths[i];
          await repository.copyItem(sourceFile, destFile);
        }

        // Select the first copied file
        final copiedFileName = newPaths.isNotEmpty
            ? newPaths.first.split('/').last
            : null;
        final destSelectPath = copiedFileName != null
            ? '$destPath/$copiedFileName'
            : null;
        ref
            .read(panelStateProvider(activePanelId).notifier)
            .loadPath(destPath, selectItemPath: destSelectPath);
      } else {
        final stream = repository.copyItems(
          paths,
          destPath,
          CancellationToken(),
        );
        await for (final _ in stream) {
          // Wait for completion
        }

        // Select the first copied file in destination
        final copiedFileName = paths.isNotEmpty
            ? paths.first.split('/').last
            : null;
        final destSelectPath = copiedFileName != null
            ? '$destPath/$copiedFileName'
            : null;
        ref
            .read(panelStateProvider(activePanelId).notifier)
            .loadPath(destPath, selectItemPath: destSelectPath);
      }
      return;
    }
  }

  List<String> _generateCopyNames(List<String> paths, String destPath) {
    final result = <String>[];

    for (final originalPath in paths) {
      final fileName = originalPath.split('/').last;
      final dotIndex = fileName.lastIndexOf('.');

      String baseName;
      String extension;

      if (dotIndex > 0) {
        baseName = fileName.substring(0, dotIndex);
        extension = fileName.substring(dotIndex);
      } else {
        baseName = fileName;
        extension = '';
      }

      String newName = '$baseName (copy)$extension';
      String newPath = '$destPath/$newName';

      // Check if file already exists and increment if needed
      int counter = 1;
      while (_fileExists(newPath)) {
        newName = '$baseName ($counter copy)$extension';
        newPath = '$destPath/$newName';
        counter++;
      }

      result.add(newPath);
    }

    return result;
  }

  bool _fileExists(String path) {
    final file = File(path);
    final dir = Directory(path);
    return file.existsSync() || dir.existsSync();
  }

  KeyEventResult? _handleCustomShortcut(
    WidgetRef ref,
    BuildContext context,
    String actionId,
    String activePanelId,
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
        _copyToClipboard(ref, activePanelId, ClipboardOperation.copy);
        return KeyEventResult.handled;
      case 'cutToClipboard':
        _copyToClipboard(ref, activePanelId, ClipboardOperation.cut);
        return KeyEventResult.handled;
      case 'pasteFromClipboard':
        _pasteFromClipboard(ref, activePanelId);
        return KeyEventResult.handled;
      case 'switchPanel':
        ref.read(focusProvider.notifier).switchPanel();
        return KeyEventResult.handled;
      case 'toggleHiddenFiles':
        ref.read(userSettingsProvider.notifier).toggleShowHiddenFiles();
        return KeyEventResult.handled;
      case 'deleteToTrash':
        panelController.deleteSelectedItems(permanent: false);
        return KeyEventResult.handled;
      case 'permanentDelete':
        _showDeleteConfirmation(context, ref, activePanelId, permanent: true);
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
          activePanelId,
          panelController,
          currentPanelState,
        );
        return KeyEventResult.handled;
      case 'rename':
        panelController.startRenaming();
        return KeyEventResult.handled;
      case 'createDirectory':
        _showCreateDialog(context, ref, activePanelId, isDirectory: true);
        return KeyEventResult.handled;
      case 'createFile':
        _showCreateDialog(context, ref, activePanelId, isDirectory: false);
        return KeyEventResult.handled;
      case 'openTerminal':
        final path = ref.read(panelStateProvider(activePanelId)).currentPath;
        if (path.isNotEmpty) {
          final useBuiltIn = ref.read(userSettingsProvider).useBuiltInTerminal;
          if (useBuiltIn) {
            final focusState = ref.read(focusProvider);
            final isLeftPanel = focusState.activePanel == ActivePanel.left;
            ref.read(overlayProvider.notifier).showTerminal(isLeftPanel, path);
          } else {
            _openTerminal(path);
          }
        }
        return KeyEventResult.handled;
      case 'openWith':
        _openWithApplication(context, ref);
        return KeyEventResult.handled;
      case 'openDefaultManager':
        final path = ref.read(panelStateProvider(activePanelId)).currentPath;
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
      case 'copyPath':
        _copyPathToClipboard(ref, activePanelId);
        return KeyEventResult.handled;
      case 'extractHere':
        final item = currentPanelState.items[currentPanelState.focusedIndex];
        if (item.path.toLowerCase().endsWith('.zip')) {
          panelController
              .extractArchive(item.path, currentPanelState.currentPath)
              .then((_) {
                panelController.refresh();
              });
        }
        return KeyEventResult.handled;
      case 'extractToOpposite':
        final item = currentPanelState.items[currentPanelState.focusedIndex];
        if (item.path.toLowerCase().endsWith('.zip')) {
          final oppositePanelId = activePanelId == 'left' ? 'right' : 'left';
          final destPath = ref
              .read(panelStateProvider(oppositePanelId))
              .currentPath;
          panelController.extractArchive(item.path, destPath).then((_) {
            ref.read(panelStateProvider(oppositePanelId).notifier).refresh();
          });
        }
        return KeyEventResult.handled;
      default:
        return null;
    }
  }

  void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    String activePanelId, {
    required bool permanent,
  }) {
    final panelState = ref.read(panelStateProvider(activePanelId));
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
              .read(panelStateProvider(activePanelId).notifier)
              .deleteSelectedItems(permanent: permanent);
        }
      });
    }
  }

  void _showCreateDialog(
    BuildContext context,
    WidgetRef ref,
    String activePanelId, {
    required bool isDirectory,
  }) {
    final panelState = ref.read(panelStateProvider(activePanelId));
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
        final controller = ref.read(panelStateProvider(activePanelId).notifier);
        if (isDirectory) {
          controller.createDirectory(name.toString());
        } else {
          controller.createFile(name.toString());
        }
      }
    });
  }

  void _showSaveWorkspaceDialog(BuildContext context, WidgetRef ref) {
    final leftState = ref.read(panelStateProvider('left'));
    final rightState = ref.read(panelStateProvider('right'));

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
          leftPanelPath: leftState.currentPath,
          rightPanelPath: rightState.currentPath,
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
      final itemName = paths.first.split('/').last;
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
