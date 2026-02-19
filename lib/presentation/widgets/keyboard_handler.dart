import 'dart:io';

import 'package:fima/domain/entity/file_operation.dart';
import 'package:fima/domain/entity/workspace.dart';
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
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class KeyboardHandler extends ConsumerWidget {
  final Widget child;

  const KeyboardHandler({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyUpEvent) {
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
        if (overlayState.isActive &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          ref.read(overlayProvider.notifier).close();
          return KeyEventResult.handled;
        }

        // Navigation keys
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          panelController.moveSelectionUp();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          panelController.moveSelectionDown();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.home) {
          panelController.moveToFirst();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.end) {
          panelController.moveToLast();
          return KeyEventResult.handled;
        }

        // Directory navigation
        if (event.logicalKey == LogicalKeyboardKey.enter) {
          panelController.enterFocusedItem();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.backspace &&
            HardwareKeyboard.instance.isControlPressed) {
          if (currentPanelState.quickFilterText.isNotEmpty) {
            panelController.clearQuickFilter();
            return KeyEventResult.handled;
          }
        }
        if (event.logicalKey == LogicalKeyboardKey.backspace &&
            !HardwareKeyboard.instance.isShiftPressed) {
          final filterText = currentPanelState.quickFilterText;
          if (filterText.isNotEmpty) {
            final newText = filterText.substring(0, filterText.length - 1);
            if (newText.isEmpty) {
              panelController.clearQuickFilter();
            } else {
              panelController.setQuickFilter(newText);
            }
          } else {
            panelController.navigateToParent();
          }
          return KeyEventResult.handled;
        }

        // Selection
        if (event.logicalKey == LogicalKeyboardKey.space) {
          panelController.toggleSelectionAtFocus();
          return KeyEventResult.handled;
        }

        // Ctrl+A - Select all
        if (event.logicalKey == LogicalKeyboardKey.keyA &&
            (HardwareKeyboard.instance.isControlPressed ||
                HardwareKeyboard.instance.isMetaPressed)) {
          panelController.selectAll();
          return KeyEventResult.handled;
        }

        // Ctrl+D - Deselect all
        if (event.logicalKey == LogicalKeyboardKey.keyD &&
            (HardwareKeyboard.instance.isControlPressed ||
                HardwareKeyboard.instance.isMetaPressed)) {
          panelController.deselectAll();
          return KeyEventResult.handled;
        }

        // Ctrl+C - Copy to system clipboard
        if (event.logicalKey == LogicalKeyboardKey.keyC &&
            (HardwareKeyboard.instance.isControlPressed ||
                HardwareKeyboard.instance.isMetaPressed) &&
            !HardwareKeyboard.instance.isShiftPressed) {
          _copyToClipboard(ref, activePanelId, ClipboardOperation.copy);
          return KeyEventResult.handled;
        }

        // Ctrl+X - Cut to system clipboard
        if (event.logicalKey == LogicalKeyboardKey.keyX &&
            (HardwareKeyboard.instance.isControlPressed ||
                HardwareKeyboard.instance.isMetaPressed)) {
          _copyToClipboard(ref, activePanelId, ClipboardOperation.cut);
          return KeyEventResult.handled;
        }

        // Ctrl+V - Paste from system clipboard
        if (event.logicalKey == LogicalKeyboardKey.keyV &&
            (HardwareKeyboard.instance.isControlPressed ||
                HardwareKeyboard.instance.isMetaPressed)) {
          _pasteFromClipboard(ref, activePanelId);
          return KeyEventResult.handled;
        }

        // Tab - Switch panel
        if (event.logicalKey == LogicalKeyboardKey.tab) {
          focusController.switchPanel();
          return KeyEventResult.handled;
        }

        if (event.logicalKey == LogicalKeyboardKey.keyH &&
            (HardwareKeyboard.instance.isControlPressed ||
                HardwareKeyboard.instance.isMetaPressed)) {
          ref.read(userSettingsProvider.notifier).toggleShowHiddenFiles();
          return KeyEventResult.handled;
        }

        // Delete
        if (event.logicalKey == LogicalKeyboardKey.delete) {
          final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
          final panelState = ref.read(panelStateProvider(activePanelId));

          if (isShiftPressed) {
            // Permanent delete - show dialog
            // We need count of items to be deleted.
            // If selection is empty, it's 1 (focused item), unless focused item is .. or empty
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
                  panelController.deleteSelectedItems(permanent: true);
                }
              });
            }
          } else {
            // Move to trash - no confirmation
            panelController.deleteSelectedItems(permanent: false);
          }
          return KeyEventResult.handled;
        }

        // F5 - Copy
        if (event.logicalKey == LogicalKeyboardKey.f5) {
          ref.read(operationStatusProvider.notifier).startCopy();
          return KeyEventResult.handled;
        }

        // F6 - Move
        if (event.logicalKey == LogicalKeyboardKey.f6) {
          ref.read(operationStatusProvider.notifier).startMove();
          return KeyEventResult.handled;
        }
        // F2 - Rename
        if (event.logicalKey == LogicalKeyboardKey.f2) {
          ref.read(panelStateProvider(activePanelId).notifier).startRenaming();
          return KeyEventResult.handled;
        }

        // F7 - Create Directory
        if (event.logicalKey == LogicalKeyboardKey.f7) {
          final panelState = ref.read(panelStateProvider(activePanelId));
          // If panel not ready or path empty, ignore
          if (panelState.currentPath.isEmpty) return KeyEventResult.ignored;

          showDialog(
            context: context,
            barrierColor: Colors.transparent,
            builder: (context) => const TextInputDialog(
              title: 'Create Directory',
              label: 'Directory Name',
              okButtonLabel: 'Create',
            ),
          ).then((name) {
            if (name != null && name.toString().isNotEmpty) {
              panelController.createDirectory(name.toString());
            }
          });
          return KeyEventResult.handled;
        }

        // F8 - Create File
        if (event.logicalKey == LogicalKeyboardKey.f8) {
          final panelState = ref.read(panelStateProvider(activePanelId));
          if (panelState.currentPath.isEmpty) return KeyEventResult.ignored;

          showDialog(
            context: context,
            barrierColor: Colors.transparent,
            builder: (context) => const TextInputDialog(
              title: 'Create File',
              label: 'File Name',
              okButtonLabel: 'Create',
            ),
          ).then((name) {
            if (name != null && name.toString().isNotEmpty) {
              panelController.createFile(name.toString());
            }
          });
          return KeyEventResult.handled;
        }

        // F9 - Open Terminal
        if (event.logicalKey == LogicalKeyboardKey.f9) {
          final path = ref.read(panelStateProvider(activePanelId)).currentPath;
          if (path.isNotEmpty) {
            _openTerminal(path);
          }
          return KeyEventResult.handled;
        }

        // F4 - Open with...
        if (event.logicalKey == LogicalKeyboardKey.f4) {
          _openWithApplication(context, ref);
          return KeyEventResult.handled;
        }

        // F10 - Open Default File Manager
        if (event.logicalKey == LogicalKeyboardKey.f10) {
          final path = ref.read(panelStateProvider(activePanelId)).currentPath;
          if (path.isNotEmpty) {
            _openFileManager(path);
          }
          return KeyEventResult.handled;
        }

        // Ctrl+Shift+S - Save as Workspace
        if (event.logicalKey == LogicalKeyboardKey.keyS &&
            (HardwareKeyboard.instance.isControlPressed ||
                HardwareKeyboard.instance.isMetaPressed) &&
            HardwareKeyboard.instance.isShiftPressed) {
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
          return KeyEventResult.handled;
        }

        // Ctrl+Alt+S - Settings
        if (event.logicalKey == LogicalKeyboardKey.keyS &&
            HardwareKeyboard.instance.isControlPressed &&
            HardwareKeyboard.instance.isAltPressed) {
          final focusState = ref.read(focusProvider);
          final isLeftPanel = focusState.activePanel == ActivePanel.left;
          ref.read(overlayProvider.notifier).showSettings(isLeftPanel);
          return KeyEventResult.handled;
        }

        // Omni Dialog (Ctrl + P or Ctrl + Shift + P)
        if (event.logicalKey == LogicalKeyboardKey.keyP &&
            (HardwareKeyboard.instance.isControlPressed ||
                HardwareKeyboard.instance.isMetaPressed)) {
          final isShift = HardwareKeyboard.instance.isShiftPressed;

          showDialog(
            context: context,
            barrierColor: Colors.transparent,
            builder: (context) => OmniDialog(initialText: isShift ? '>' : ''),
          );

          return KeyEventResult.handled;
        }

        // Workspace Dialog (Ctrl + W)
        if (event.logicalKey == LogicalKeyboardKey.keyW &&
            (HardwareKeyboard.instance.isControlPressed ||
                HardwareKeyboard.instance.isMetaPressed)) {
          showDialog(
            context: context,
            barrierColor: Colors.transparent,
            builder: (context) => const OmniDialog(initialText: 'w '),
          );

          return KeyEventResult.handled;
        }

        // Escape - close QuickFilter if active
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          if (currentPanelState.quickFilterText.isNotEmpty) {
            panelController.clearQuickFilter();
            return KeyEventResult.handled;
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
      child: child,
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

      ref
          .read(panelStateProvider(sourcePanelId).notifier)
          .loadPath(sourcePath!);
      ref.read(panelStateProvider(activePanelId).notifier).loadPath(destPath);
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
}
