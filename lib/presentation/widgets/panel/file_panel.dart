import 'dart:async';

import 'package:fima/domain/entity/app_theme.dart';
import 'package:fima/domain/entity/file_system_item.dart';
import 'package:fima/domain/entity/key_map_action.dart';
import 'package:fima/domain/entity/panel_state.dart';
import 'package:fima/domain/entity/remote_connection.dart';
import 'package:fima/infrastructure/service/keyboard_utils.dart';
import 'package:fima/presentation/providers/drag_state_provider.dart';
import 'package:fima/presentation/providers/file_system_provider.dart';
import 'package:fima/presentation/providers/focus_provider.dart';
import 'package:fima/presentation/providers/operation_status_provider.dart';
import 'package:fima/presentation/providers/overlay_provider.dart';
import 'package:fima/presentation/providers/panel_tabs_provider.dart';
import 'package:fima/presentation/providers/settings_provider.dart';
import 'package:fima/presentation/providers/theme_provider.dart';
import 'package:fima/presentation/widgets/panel/draggable_file_item.dart';
import 'package:fima/presentation/widgets/panel/drop_target_item.dart';
import 'package:fima/presentation/widgets/panel/panel_tab_bar.dart';
import 'package:fima/presentation/widgets/panel/rename_field.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_icon/file_icon.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

class FilePanel extends ConsumerStatefulWidget {
  final String panelId;
  final String? initialPath;

  const FilePanel({super.key, required this.panelId, this.initialPath});

  @override
  ConsumerState<FilePanel> createState() => _FilePanelState();
}

class _FilePanelState extends ConsumerState<FilePanel> {
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  final ScrollController _scrollController = ScrollController();
  // Explicit Flutter FocusNode for this panel. When the user taps to
  // activate this panel we call requestFocus() so that Flutter focus
  // leaves any other focused widget (e.g. the terminal's TerminalView)
  // and routes key events back to the KeyboardHandler ancestor.
  late final FocusNode _panelFocusNode;
  late final TextEditingController _pathController;
  late final FocusNode _pathFocusNode;
  String? _pathError;
  bool _isValidatingPath = false;
  bool _previousShowHiddenFiles = false;

  // Column width fractions (the third column gets the remainder).
  // Defaults approximate the old 3:1:2 flex ratio.
  double _nameWidthFraction = 0.50;
  double _sizeWidthFraction = 0.17;

  static const double _minColumnFraction = 0.10;
  static const double _splitterWidth = 8.0;
  static const double _splitterLineWidth = 1.0;

  final Map<String, double> _scrollOffsets = {};
  int? _lastTappedIndex;
  DateTime? _lastTapTime;
  static const _doubleTapDelay = Duration(milliseconds: 300);

  String get _activeTabId =>
      ref.read(panelTabsProvider(widget.panelId)).activeTabId;

  @override
  void initState() {
    super.initState();
    _panelFocusNode = FocusNode();
    _pathController = TextEditingController();
    _pathFocusNode = FocusNode(onKeyEvent: _handlePathKeyEvent);
    _pathFocusNode.addListener(_onPathFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(panelTabsProvider(widget.panelId).notifier)
          .ensureActiveTabLoaded();
      _previousShowHiddenFiles = ref.read(userSettingsProvider).showHiddenFiles;
    });
  }

  @override
  void dispose() {
    _pathFocusNode.removeListener(_onPathFocusChanged);
    _pathFocusNode.dispose();
    _pathController.dispose();
    _scrollController.dispose();
    _panelFocusNode.dispose();
    super.dispose();
  }

  void _handleTapDown(
    int index,
    FileSystemItem item,
    PanelController controller,
    int currentFocusedIndex,
  ) {
    final now = DateTime.now();
    final kb = HardwareKeyboard.instance;
    final isCtrlOrCmd = kb.isControlPressed || kb.isMetaPressed;
    final isShift = kb.isShiftPressed;

    // Double-tap → enter the item (navigate / open)
    if (_lastTappedIndex == index &&
        _lastTapTime != null &&
        now.difference(_lastTapTime!) < _doubleTapDelay &&
        !isCtrlOrCmd &&
        !isShift) {
      controller.enterFocusedItem();
      _lastTappedIndex = null;
      _lastTapTime = null;
      return;
    }

    // Take Flutter focus back from the terminal / other widgets
    _panelFocusNode.requestFocus();
    ref
        .read(focusProvider.notifier)
        .setActivePanel(
          widget.panelId == 'left' ? ActivePanel.left : ActivePanel.right,
        );

    if (isCtrlOrCmd) {
      // Ctrl/Cmd + click: toggle this item's selection, keep all others
      controller.toggleSelection(item.path);
      controller.setFocusedIndex(index);
      _lastTappedIndex = index; // new anchor for future shift-clicks
    } else if (isShift) {
      // Shift + click: select range from the current focused index to clicked item
      final anchor = _lastTappedIndex ?? currentFocusedIndex;
      controller.selectRange(anchor, index);
      controller.setFocusedIndex(index);
      // Keep _lastTappedIndex unchanged so repeated Shift+clicks extend from same anchor
    } else {
      // Plain click: only move focus, do not change selection
      controller.setFocusedIndex(index);
      _lastTappedIndex = index; // reset anchor
    }

    _lastTapTime = now;
  }

  void _scrollToIndex(int index, int itemCount, double itemHeight) {
    if (!_scrollController.hasClients || index < 0 || index >= itemCount) {
      return;
    }

    final double viewportHeight = _scrollController.position.viewportDimension;
    final double scrollOffset = _scrollController.offset;
    final double itemTop = index * itemHeight;
    final double itemBottom = itemTop + itemHeight;

    // Buffer for "penultimate" behavior (1 item buffer)
    final double buffer = itemHeight;

    // Scroll down if item is below viewport (minus buffer)
    if (itemBottom > scrollOffset + viewportHeight - buffer) {
      final double targetOffset = itemBottom - viewportHeight + buffer;
      _scrollController.jumpTo(targetOffset);
    }
    // Scroll up if item is above viewport (plus buffer)
    else if (itemTop < scrollOffset + buffer) {
      final double targetOffset = itemTop - buffer;
      // Clamp to 0 to avoid negative scroll
      _scrollController.jumpTo(targetOffset < 0 ? 0 : targetOffset);
    }
  }

  @override
  void didUpdateWidget(FilePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  String _formatSize(int bytes) {
    if (bytes < 0) return 'N/A';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Widget _buildColumnHeader(
    String title,
    SortColumn column,
    PanelState state,
    FimaTheme fimaTheme,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    final isActive = state.sortColumn == column;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: fimaTheme.textColor,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 4),
              Icon(
                state.sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 12,
                color: fimaTheme.textColor,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSplitter({
    required FimaTheme fimaTheme,
    required double height,
    required void Function(double delta, double totalWidth) onDrag,
    required double totalWidth,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) {
          onDrag(details.delta.dx, totalWidth);
        },
        child: SizedBox(
          width: _splitterWidth,
          height: height,
          child: Center(
            child: Container(
              width: _splitterLineWidth,
              height: height,
              color: fimaTheme.borderColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileIcon(FileSystemItem item, double size) {
    if (item.isParentDetails) {
      return FaIcon(FontAwesomeIcons.turnUp, size: size);
    }
    if (item.isDirectory) {
      return FaIcon(FontAwesomeIcons.folder, size: size, color: Colors.amber);
    }
    return FileIcon(item.name, size: size);
  }

  Future<void> _handleDrop(PerformDropEvent event, String targetPath) async {
    final dragState = ref.read(dragStateProvider);

    if (dragState.sourcePanelId != null) {
      // Internal drag: move dragged paths into targetPath.
      final paths = dragState.draggedPaths;
      if (paths.isEmpty) return;

      // Skip if every item already lives directly inside the target folder.
      final allSameParent = paths.every(
        (path) => p.dirname(path) == targetPath,
      );
      if (allSameParent) return;

      // Skip if any dragged path IS the target folder.
      if (paths.any((path) => path == targetPath)) return;

      final sourcePanelId = dragState.sourcePanelId!;
      final sourceTabId = dragState.sourceTabId;
      final destTabId = _activeTabId;
      ref.read(dragStateProvider.notifier).endDrag();

      await ref
          .read(operationStatusProvider.notifier)
          .startDropOperation(
            sourcePaths: paths,
            sourcePanelId: sourcePanelId,
            sourceTabId: sourceTabId,
            destinationPanelId: widget.panelId,
            destinationTabId: destTabId,
            destinationPath: targetPath,
            isCopy: false,
          );
    } else {
      // External drag: copy each file into targetPath.
      final destTabId = _activeTabId;
      final repository = ref.read(fileSystemRepositoryProvider);
      for (final dropItem in event.session.items) {
        final reader = dropItem.dataReader;
        if (reader == null) continue;
        if (reader.canProvide(Formats.fileUri)) {
          final completer = Completer<Uri?>();
          reader.getValue<Uri>(
            Formats.fileUri,
            (value) => completer.complete(value),
          );
          final uri = await completer.future;
          if (uri != null) {
            final sourcePath = uri.toFilePath();
            final dest = p.join(targetPath, p.basename(sourcePath));
            try {
              await repository.copyItem(sourcePath, dest);
            } catch (e) {
              debugPrint('Error copying dropped file $sourcePath: $e');
            }
          }
        }
      }
      // Refresh the tab that received the drop.
      if (ref
          .read(panelTabsProvider(widget.panelId).notifier)
          .hasTab(destTabId)) {
        await ref
            .read(panelStateProvider(destTabId).notifier)
            .loadPath(
              targetPath,
              addToVisited: false,
              preserveFocusedIndex: true,
            );
      }
    }
  }

  void _onPathFocusChanged() {
    if (!_pathFocusNode.hasFocus) {
      final panelState = ref.read(panelStateProvider(_activeTabId));
      if (panelState.isEditingPath) {
        _cancelPathEditing(restoreFocus: false);
      }
    }
  }

  void _activatePathEditor(String currentPath) {
    _pathController.text = currentPath;
    if (_pathError != null) {
      setState(() {
        _pathError = null;
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ref.read(panelStateProvider(_activeTabId)).isEditingPath) return;
      _pathFocusNode.requestFocus();
      _selectAllPathText();
    });
  }

  void _selectAllPathText() {
    _pathController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _pathController.text.length,
    );
  }

  KeyEventResult _handlePathKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _cancelPathEditing(restoreFocus: true);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        _submitPath();
        return KeyEventResult.handled;
      }
      final currentShortcut = KeyboardUtils.buildShortcutString(event);
      if (currentShortcut.isNotEmpty) {
        final editPathShortcut = ref
            .read(userSettingsProvider.notifier)
            .getEffectiveShortcut('editPath');
        if (editPathShortcut != null &&
            KeyMapActionDefs.shortcutsMatch(
              editPathShortcut,
              currentShortcut,
            )) {
          _selectAllPathText();
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  Future<void> _submitPath() async {
    if (_isValidatingPath) return;
    _isValidatingPath = true;

    final tabId = _activeTabId;
    final input = _pathController.text;
    final controller = ref.read(panelStateProvider(tabId).notifier);
    final error = await controller.navigateToPath(input);

    if (!mounted) return;
    _isValidatingPath = false;

    if (error == null) {
      if (_pathError != null) {
        setState(() {
          _pathError = null;
        });
      }
      _panelFocusNode.requestFocus();
    } else {
      setState(() {
        _pathError = error;
      });
      ref.read(overlayProvider.notifier).showToast(error, isError: true);
      if (ref.read(panelStateProvider(tabId)).isEditingPath &&
          !_pathFocusNode.hasFocus) {
        _pathFocusNode.requestFocus();
      }
    }
  }

  void _cancelPathEditing({required bool restoreFocus}) {
    final tabId = _activeTabId;
    final controller = ref.read(panelStateProvider(tabId).notifier);
    final panelState = ref.read(panelStateProvider(tabId));
    if (!panelState.isEditingPath) return;

    _pathController.text = panelState.currentPath;
    if (_pathError != null) {
      setState(() {
        _pathError = null;
      });
    }
    controller.stopEditingPath();

    if (restoreFocus) {
      _panelFocusNode.requestFocus();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
        final leftTabId = ref.read(panelTabsProvider('left')).activeTabId;
        final rightTabId = ref.read(panelTabsProvider('right')).activeTabId;
        final leftEditing = ref
            .read(panelStateProvider(leftTabId))
            .isEditingPath;
        final rightEditing = ref
            .read(panelStateProvider(rightTabId))
            .isEditingPath;
        if (leftEditing || rightEditing) return;

        final currentFocus = FocusManager.instance.primaryFocus;
        if (currentFocus == null ||
            currentFocus is FocusScopeNode ||
            currentFocus == _pathFocusNode) {
          ref.read(keyboardHandlerFocusNodeProvider).requestFocus();
        }
      });
    }
  }

  Widget _buildLocalPathHeader(
    PanelState panelState,
    PanelController controller,
    FimaTheme fimaTheme,
    ThemeData theme,
    double fontSize,
  ) {
    final textStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: fontSize,
      color: fimaTheme.textColor,
    );
    final borderColor = _pathError != null
        ? Colors.redAccent
        : panelState.isEditingPath
        ? fimaTheme.accentColor
        : fimaTheme.borderColor;

    return Container(
      constraints: BoxConstraints(minHeight: fontSize + 16),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: panelState.isEditingPath
            ? fimaTheme.backgroundColor
            : fimaTheme.surfaceColor,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: panelState.isEditingPath
          ? TextField(
              controller: _pathController,
              focusNode: _pathFocusNode,
              cursorWidth: 1.0,
              maxLines: 1,
              style: textStyle,
              decoration: const InputDecoration(
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                isDense: true,
              ),
              onChanged: (_) {
                if (_pathError != null) {
                  setState(() {
                    _pathError = null;
                  });
                }
              },
              onEditingComplete: () {},
              onTapOutside: (_) => _cancelPathEditing(restoreFocus: false),
            )
          : MouseRegion(
              cursor: SystemMouseCursors.text,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  ref
                      .read(focusProvider.notifier)
                      .setActivePanel(
                        widget.panelId == 'left'
                            ? ActivePanel.left
                            : ActivePanel.right,
                      );
                  controller.startEditingPath();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Text(
                    panelState.currentPath.isEmpty
                        ? '...'
                        : panelState.currentPath,
                    style: textStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
    );
  }

  /// Shows confirmation for disconnecting SSH and then disconnects.
  Future<void> _confirmDisconnect() async {
    final controller = ref.read(panelStateProvider(_activeTabId).notifier);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect from server?'),
        content: const Text('The remote connection will be closed.'),
        actions: [
          FilledButton(
            autofocus: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await controller.disconnectSsh();
    }
  }

  /// Builds the SSH connection header bar shown in place of the local path header.
  Widget _buildSshHeader(
    PanelState panelState,
    FimaTheme fimaTheme,
    ThemeData theme,
    double fontSize,
  ) {
    final connId = RemoteConnection.connectionIdFromSshUrl(
      panelState.currentPath,
    );
    final settings = ref.read(userSettingsProvider);
    final connection = settings.remoteConnections
        .cast<RemoteConnection?>()
        .firstWhere((c) => c?.id == connId, orElse: () => null);
    final connectionName = connection?.name ?? connId;
    final remotePath = RemoteConnection.remotePathFromSshUrl(
      panelState.currentPath,
    );

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: fimaTheme.surfaceColor,
        border: Border(bottom: BorderSide(color: fimaTheme.borderColor)),
      ),
      child: Row(
        children: [
          Icon(Icons.dns, size: 14, color: fimaTheme.accentColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$connectionName — $remotePath',
              style: theme.textTheme.bodySmall?.copyWith(
                color: fimaTheme.textColor,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            onTap: _confirmDisconnect,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close, size: 14, color: fimaTheme.textColor),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabsState = ref.watch(panelTabsProvider(widget.panelId));
    final activeTabId = tabsState.activeTabId;
    final panelState = ref.watch(panelStateProvider(activeTabId));
    final controller = ref.read(panelStateProvider(activeTabId).notifier);
    final fimaTheme = ref.watch(themeProvider);
    final theme = Theme.of(context);
    final settings = ref.watch(userSettingsProvider);
    final fontSize = settings.fontSize;
    final itemHeight = fontSize + 16.0;

    // Prune scroll offsets for closed tabs
    _scrollOffsets.removeWhere(
      (id, _) => !tabsState.tabs.any((t) => t.id == id),
    );

    // Check if showHiddenFiles setting changed and refresh if needed
    if (_previousShowHiddenFiles != settings.showHiddenFiles) {
      _previousShowHiddenFiles = settings.showHiddenFiles;
      final currentPath = panelState.currentPath;
      if (currentPath.isNotEmpty) {
        controller.loadPath(
          currentPath,
          preserveSelection: true,
          preserveFocusedIndex: true,
        );
      }
    }

    ref.listen(panelTabsProvider(widget.panelId).select((s) => s.activeTabId), (
      previousTabId,
      nextTabId,
    ) {
      if (previousTabId != null && previousTabId != nextTabId) {
        if (_scrollController.hasClients) {
          _scrollOffsets[previousTabId] = _scrollController.offset;
        }
        if (_pathError != null) {
          setState(() {
            _pathError = null;
          });
        }
        final prevState = ref.read(panelStateProvider(previousTabId));
        if (prevState.isEditingPath) {
          ref
              .read(panelStateProvider(previousTabId).notifier)
              .stopEditingPath();
        }

        final targetOffset = _scrollOffsets[nextTabId] ?? 0.0;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scrollController.hasClients) return;
          final maxExtent = _scrollController.position.maxScrollExtent;
          _scrollController.jumpTo(targetOffset.clamp(0.0, maxExtent));
        });
      }
    });

    ref.listen(panelStateProvider(activeTabId), (previous, next) {
      if (previous?.focusedIndex != next.focusedIndex) {
        _scrollToIndex(next.focusedIndex, next.items.length, itemHeight);
      }
      if (previous?.isEditingPath != true && next.isEditingPath) {
        _activatePathEditor(next.currentPath);
      }
    });

    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent &&
            (HardwareKeyboard.instance.isControlPressed ||
                HardwareKeyboard.instance.isMetaPressed)) {
          final settingsController = ref.read(userSettingsProvider.notifier);
          // Scroll up (negative delta) -> Increase font size
          // Scroll down (positive delta) -> Decrease font size
          if (event.scrollDelta.dy < 0) {
            settingsController.setFontSize(fontSize + 1);
          } else if (event.scrollDelta.dy > 0) {
            settingsController.setFontSize(fontSize - 1);
          }
        }
      },
      child: Focus(
        focusNode: _panelFocusNode,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _panelFocusNode.requestFocus(); // take Flutter focus from terminal
            ref
                .read(focusProvider.notifier)
                .setActivePanel(
                  widget.panelId == 'left'
                      ? ActivePanel.left
                      : ActivePanel.right,
                );
          },
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: fimaTheme.borderColor),
              color: fimaTheme.backgroundColor,
            ),
            child: Column(
              children: [
                // Tab bar (shown when 2+ tabs exist in this panel)
                PanelTabBar(
                  tabs: tabsState.tabs,
                  activeTabIndex: tabsState.activeTabIndex,
                  fimaTheme: fimaTheme,
                  fontSize: fontSize,
                  remoteConnections: settings.remoteConnections,
                  onSelectTab: (index) {
                    _panelFocusNode.requestFocus();
                    ref
                        .read(focusProvider.notifier)
                        .setActivePanel(
                          widget.panelId == 'left'
                              ? ActivePanel.left
                              : ActivePanel.right,
                        );
                    ref
                        .read(panelTabsProvider(widget.panelId).notifier)
                        .selectTab(index);
                  },
                  onCloseTab: (tabId) {
                    ref
                        .read(panelTabsProvider(widget.panelId).notifier)
                        .closeTab(tabId);
                  },
                ),
                // SSH header (shown only for SSH paths)
                if (panelState.currentPath.startsWith('ssh://'))
                  _buildSshHeader(panelState, fimaTheme, theme, fontSize),
                // Local path header
                if (!panelState.currentPath.startsWith('ssh://'))
                  _buildLocalPathHeader(
                    panelState,
                    controller,
                    fimaTheme,
                    theme,
                    fontSize,
                  ),
                // Column headers
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  color: fimaTheme.surfaceColor,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final iconWidth = fontSize + 10;
                      final availableWidth =
                          constraints.maxWidth - iconWidth - _splitterWidth * 2;
                      final sizeWidth = availableWidth * _sizeWidthFraction;
                      final modifiedWidth =
                          availableWidth *
                          (1.0 - _nameWidthFraction - _sizeWidthFraction);

                      return Row(
                        children: [
                          SizedBox(width: iconWidth), // Icon space
                          Expanded(
                            child: _buildColumnHeader(
                              'Name',
                              SortColumn.name,
                              panelState,
                              fimaTheme,
                              () => controller.sort(SortColumn.name),
                            ),
                          ),
                          _buildSplitter(
                            fimaTheme: fimaTheme,
                            height: 32,
                            totalWidth: availableWidth,
                            onDrag: (delta, total) {
                              setState(() {
                                final deltaFraction = delta / total;
                                final newName =
                                    (_nameWidthFraction + deltaFraction).clamp(
                                      _minColumnFraction,
                                      1.0 -
                                          _sizeWidthFraction -
                                          _minColumnFraction,
                                    );
                                _nameWidthFraction = newName;
                              });
                            },
                          ),
                          SizedBox(
                            width: sizeWidth,
                            child: _buildColumnHeader(
                              'Size',
                              SortColumn.size,
                              panelState,
                              fimaTheme,
                              () => controller.sort(SortColumn.size),
                            ),
                          ),
                          _buildSplitter(
                            fimaTheme: fimaTheme,
                            height: 32,
                            totalWidth: availableWidth,
                            onDrag: (delta, total) {
                              setState(() {
                                final deltaFraction = delta / total;
                                final newSize =
                                    (_sizeWidthFraction + deltaFraction).clamp(
                                      _minColumnFraction,
                                      1.0 -
                                          _nameWidthFraction -
                                          _minColumnFraction,
                                    );
                                _sizeWidthFraction = newSize;
                              });
                            },
                          ),
                          SizedBox(
                            width: modifiedWidth,
                            child: _buildColumnHeader(
                              'Modified',
                              SortColumn.modified,
                              panelState,
                              fimaTheme,
                              () => controller.sort(SortColumn.modified),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                // File list
                Expanded(
                  child: DropTargetPanel(
                    panelId: widget.panelId,
                    currentPath: panelState.currentPath,
                    onDrop: _handleDrop,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _panelFocusNode
                            .requestFocus(); // take Flutter focus from terminal
                        ref
                            .read(focusProvider.notifier)
                            .setActivePanel(
                              widget.panelId == 'left'
                                  ? ActivePanel.left
                                  : ActivePanel.right,
                            );
                      },
                      child: ListView.builder(
                        controller: _scrollController,
                        itemExtent: itemHeight,
                        itemCount: panelState.items.length,
                        itemBuilder: (context, index) {
                          final item = panelState.items[index];
                          final isSelected = panelState.selectedItems.contains(
                            item.path,
                          );
                          final isFocused = panelState.focusedIndex == index;
                          final focusState = ref.watch(focusProvider);
                          final isActivePanel =
                              (widget.panelId == 'left' &&
                                  focusState.activePanel == ActivePanel.left) ||
                              (widget.panelId == 'right' &&
                                  focusState.activePanel == ActivePanel.right);
                          final dragState = ref.watch(dragStateProvider);
                          final isDropTarget =
                              item.isDirectory &&
                              !item.isParentDetails &&
                              dragState.hoveredDropTargetPath == item.path;

                          // Text color is red if selected (Marked), otherwise default
                          final textColor = isSelected
                              ? Colors.red
                              : fimaTheme.textColor;

                          Widget itemRow = GestureDetector(
                            onTapDown: (_) {
                              _handleTapDown(
                                index,
                                item,
                                controller,
                                panelState.focusedIndex,
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? fimaTheme.selectedItemColor
                                    : isFocused && isActivePanel
                                    ? fimaTheme.focusedItemColor
                                    : fimaTheme.backgroundColor,
                                border: isDropTarget
                                    ? Border.all(
                                        color: fimaTheme.accentColor,
                                        width: 2,
                                      )
                                    : isFocused && isActivePanel
                                    ? Border.all(
                                        color: fimaTheme.accentColor,
                                        width: 1,
                                      )
                                    : null,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final iconWidth = fontSize + 10;
                                  final availableWidth =
                                      constraints.maxWidth -
                                      iconWidth -
                                      _splitterWidth * 2;
                                  final sizeWidth =
                                      availableWidth * _sizeWidthFraction;
                                  final modifiedWidth =
                                      availableWidth *
                                      (1.0 -
                                          _nameWidthFraction -
                                          _sizeWidthFraction);

                                  return Row(
                                    children: [
                                      SizedBox(
                                        width: iconWidth,
                                        child: _buildFileIcon(
                                          item,
                                          fontSize + 2,
                                        ),
                                      ),
                                      Expanded(
                                        child:
                                            item.path == panelState.editingPath
                                            ? RenameField(
                                                initialValue: item.name,
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: textColor,
                                                      fontSize: fontSize,
                                                    ),
                                                onSubmitted: (newName) {
                                                  controller.renameItem(
                                                    newName,
                                                  );
                                                },
                                                onCancel: () {
                                                  controller.cancelRenaming();
                                                },
                                              )
                                            : Text(
                                                item.name,
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: textColor,
                                                      fontSize: fontSize,
                                                    ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                      ),
                                      SizedBox(width: _splitterWidth),
                                      SizedBox(
                                        width: sizeWidth,
                                        child: Text(
                                          item.isDirectory &&
                                                  !item.isParentDetails
                                              ? '<DIR>'
                                              : item.isParentDetails
                                              ? ''
                                              : _formatSize(item.size),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: textColor,
                                                fontSize: fontSize,
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      SizedBox(width: _splitterWidth),
                                      SizedBox(
                                        width: modifiedWidth,
                                        child: Text(
                                          item.isParentDetails
                                              ? ''
                                              : _dateFormat.format(
                                                  item.modified,
                                                ),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: textColor,
                                                fontSize: fontSize,
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          );

                          if (item.isDirectory && !item.isParentDetails) {
                            itemRow = DropTargetFolder(
                              folderPath: item.path,
                              onDrop: _handleDrop,
                              child: itemRow,
                            );
                          }
                          return DraggableFileItem(
                            item: item,
                            panelState: panelState,
                            panelId: widget.panelId,
                            tabId: activeTabId,
                            child: itemRow,
                          );
                        },
                      ),
                    ),
                  ),
                ),
                // QuickFilter input box
                if (panelState.quickFilterText.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: fimaTheme.surfaceColor,
                      border: Border(
                        top: BorderSide(color: fimaTheme.borderColor),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search,
                          size: fontSize + 2,
                          color: fimaTheme.accentColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          panelState.quickFilterText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: fontSize,
                            color: fimaTheme.textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                // Operation Progress Bar
                if (panelState.operationProgress != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: fimaTheme.surfaceColor,
                      border: Border(
                        top: BorderSide(color: fimaTheme.borderColor),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${panelState.operationProgress!.operationName}: ${panelState.operationProgress!.currentItem}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: fontSize - 1,
                            color: fimaTheme.textColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: LinearProgressIndicator(
                                value: panelState.operationProgress!.progress,
                                minHeight: 2,
                                backgroundColor: fimaTheme.surfaceColor,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  fimaTheme.accentColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
