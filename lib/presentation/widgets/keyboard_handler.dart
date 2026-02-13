import 'dart:io';

import 'package:fima/domain/entity/workspace.dart';
import 'package:fima/infrastructure/service/linux_application_service.dart';
import 'package:fima/presentation/providers/file_system_provider.dart';
import 'package:fima/presentation/providers/focus_provider.dart';
import 'package:fima/presentation/providers/operation_status_provider.dart';
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
        if (event.logicalKey == LogicalKeyboardKey.backspace) {
          panelController.navigateToParent();
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
}
