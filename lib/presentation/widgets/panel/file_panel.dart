import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import 'package:fima/domain/entity/file_system_item.dart';
import 'package:fima/presentation/providers/drag_state_provider.dart';
import 'package:fima/presentation/providers/file_system_provider.dart';
import 'package:fima/presentation/providers/focus_provider.dart';
import 'package:fima/presentation/providers/panel_tabs_provider.dart';
import 'package:fima/presentation/providers/settings_provider.dart';
import 'package:fima/presentation/providers/theme_provider.dart';
import 'package:fima/presentation/widgets/panel/drop_target_item.dart';
import 'package:fima/presentation/widgets/panel/file_context_menu.dart';
import 'package:fima/presentation/widgets/panel/panel_tab_bar.dart';
import 'package:fima/presentation/widgets/panel/widgets/panel_column_header.dart';
import 'package:fima/presentation/widgets/panel/widgets/panel_drop_handler.dart';
import 'package:fima/presentation/widgets/panel/widgets/panel_file_row.dart';
import 'package:fima/presentation/widgets/panel/widgets/panel_footer_bars.dart';
import 'package:fima/presentation/widgets/panel/widgets/panel_path_bar.dart';

/// Displays one file-manager panel with tabs, path bar, sortable table, and footer.
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

  late final FocusNode _panelFocusNode;

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

  ActivePanel get _activePanelEnum =>
      widget.panelId == 'left' ? ActivePanel.left : ActivePanel.right;

  @override
  void initState() {
    super.initState();
    _panelFocusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(panelTabsProvider(widget.panelId).notifier)
          .ensureActiveTabLoaded();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _panelFocusNode.dispose();
    super.dispose();
  }

  void _activateThisPanel() {
    _panelFocusNode.requestFocus();
    ref.read(focusProvider.notifier).setActivePanel(_activePanelEnum);
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

    _activateThisPanel();

    if (isCtrlOrCmd) {
      controller.toggleSelection(item.path);
      controller.setFocusedIndex(index);
      _lastTappedIndex = index;
    } else if (isShift) {
      final anchor = _lastTappedIndex ?? currentFocusedIndex;
      controller.selectRange(anchor, index);
      controller.setFocusedIndex(index);
    } else {
      controller.setFocusedIndex(index);
      _lastTappedIndex = index;
    }

    _lastTapTime = now;
  }

  Future<void> _handleItemContextMenu(
    Offset globalPosition,
    int index,
    FileSystemItem item,
    String tabId,
    PanelController controller,
  ) async {
    _activateThisPanel();

    final currentState = ref.read(panelStateProvider(tabId));
    if (!item.isParentDetails) {
      if (!currentState.selectedItems.contains(item.path) &&
          currentState.selectedItems.isNotEmpty) {
        controller.deselectAll();
      }
      controller.setFocusedIndex(index);
    }

    final updatedState = ref.read(panelStateProvider(tabId));
    await FileContextMenu.show(
      context: context,
      ref: ref,
      globalPosition: globalPosition,
      panelId: widget.panelId,
      tabId: tabId,
      panelState: updatedState,
      controller: controller,
      clickedItem: item,
    );
  }

  Future<void> _handleBackgroundContextMenu(
    Offset globalPosition,
    String tabId,
    PanelController controller,
  ) async {
    _activateThisPanel();

    final updatedState = ref.read(panelStateProvider(tabId));
    if (updatedState.currentPath.isEmpty) return;

    await FileContextMenu.show(
      context: context,
      ref: ref,
      globalPosition: globalPosition,
      panelId: widget.panelId,
      tabId: tabId,
      panelState: updatedState,
      controller: controller,
      clickedItem: null,
    );
  }

  void _scrollToIndex(int index, int itemCount, double itemHeight) {
    if (!_scrollController.hasClients || index < 0 || index >= itemCount) {
      return;
    }

    final viewportHeight = _scrollController.position.viewportDimension;
    final scrollOffset = _scrollController.offset;
    final itemTop = index * itemHeight;
    final itemBottom = itemTop + itemHeight;
    final buffer = itemHeight;

    if (itemBottom > scrollOffset + viewportHeight - buffer) {
      _scrollController.jumpTo(itemBottom - viewportHeight + buffer);
    } else if (itemTop < scrollOffset + buffer) {
      final targetOffset = itemTop - buffer;
      _scrollController.jumpTo(targetOffset < 0 ? 0 : targetOffset);
    }
  }

  Future<void> _handleDrop(PerformDropEvent event, String targetPath) {
    return PanelDropHandler.handleDrop(
      ref: ref,
      panelId: widget.panelId,
      destinationTabId: _activeTabId,
      event: event,
      targetPath: targetPath,
    );
  }

  void _registerListeners(String activeTabId, double itemHeight) {
    ref.listen<List<dynamic>>(
      panelTabsProvider(widget.panelId).select((s) => s.tabs),
      (_, nextTabs) {
        _scrollOffsets.removeWhere((id, _) => !nextTabs.any((t) => t.id == id));
      },
    );

    ref.listen<bool>(userSettingsProvider.select((s) => s.showHiddenFiles), (
      previous,
      next,
    ) {
      if (previous == null || previous == next) return;
      final currentTabId = _activeTabId;
      final currentPanelState = ref.read(panelStateProvider(currentTabId));
      if (currentPanelState.currentPath.isNotEmpty) {
        ref
            .read(panelStateProvider(currentTabId).notifier)
            .loadPath(
              currentPanelState.currentPath,
              preserveSelection: true,
              preserveFocusedIndex: true,
              recordVisit: false,
            );
      }
    });

    ref.listen(panelTabsProvider(widget.panelId).select((s) => s.activeTabId), (
      previousTabId,
      nextTabId,
    ) {
      if (previousTabId == null || previousTabId == nextTabId) return;
      if (_scrollController.hasClients) {
        _scrollOffsets[previousTabId] = _scrollController.offset;
      }
      final prevState = ref.read(panelStateProvider(previousTabId));
      if (prevState.isEditingPath) {
        ref.read(panelStateProvider(previousTabId).notifier).stopEditingPath();
      }

      final targetOffset = _scrollOffsets[nextTabId] ?? 0.0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        final maxExtent = _scrollController.position.maxScrollExtent;
        _scrollController.jumpTo(targetOffset.clamp(0.0, maxExtent));
      });
    });

    ref.listen(panelStateProvider(activeTabId), (previous, next) {
      if (previous?.focusedIndex != next.focusedIndex) {
        _scrollToIndex(next.focusedIndex, next.items.length, itemHeight);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabsState = ref.watch(panelTabsProvider(widget.panelId));
    final activeTabId = tabsState.activeTabId;
    final panelState = ref.watch(panelStateProvider(activeTabId));
    final controller = ref.read(panelStateProvider(activeTabId).notifier);
    final fimaTheme = ref.watch(themeProvider);
    final settings = ref.watch(userSettingsProvider);
    final focusState = ref.watch(focusProvider);
    final dragState = ref.watch(dragStateProvider);
    final isActivePanel = focusState.activePanel == _activePanelEnum;
    final fontSize = settings.fontSize;
    final itemHeight = fontSize + 16.0;

    _registerListeners(activeTabId, itemHeight);

    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent &&
            (HardwareKeyboard.instance.isControlPressed ||
                HardwareKeyboard.instance.isMetaPressed)) {
          final settingsController = ref.read(userSettingsProvider.notifier);
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
          onTap: _activateThisPanel,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: fimaTheme.borderColor),
              color: fimaTheme.backgroundColor,
            ),
            child: Column(
              children: [
                PanelTabBar(
                  tabs: tabsState.tabs,
                  activeTabIndex: tabsState.activeTabIndex,
                  fimaTheme: fimaTheme,
                  fontSize: fontSize,
                  remoteConnections: settings.remoteConnections,
                  onSelectTab: (index) {
                    _activateThisPanel();
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
                if (panelState.currentPath.startsWith('ssh://'))
                  PanelSshHeader(
                    tabId: activeTabId,
                    panelState: panelState,
                    fimaTheme: fimaTheme,
                  )
                else
                  PanelPathBar(
                    panelId: widget.panelId,
                    tabId: activeTabId,
                    panelState: panelState,
                    fimaTheme: fimaTheme,
                    fontSize: fontSize,
                    onActivatePanel: _activateThisPanel,
                    onRestorePanelFocus: _panelFocusNode.requestFocus,
                  ),
                PanelColumnHeader(
                  panelState: panelState,
                  fimaTheme: fimaTheme,
                  fontSize: fontSize,
                  nameWidthFraction: _nameWidthFraction,
                  sizeWidthFraction: _sizeWidthFraction,
                  splitterWidth: _splitterWidth,
                  splitterLineWidth: _splitterLineWidth,
                  onSort: controller.sort,
                  onResizeName: (delta, total) {
                    setState(() {
                      _nameWidthFraction = (_nameWidthFraction + delta / total)
                          .clamp(
                            _minColumnFraction,
                            1.0 - _sizeWidthFraction - _minColumnFraction,
                          );
                    });
                  },
                  onResizeSize: (delta, total) {
                    setState(() {
                      _sizeWidthFraction = (_sizeWidthFraction + delta / total)
                          .clamp(
                            _minColumnFraction,
                            1.0 - _nameWidthFraction - _minColumnFraction,
                          );
                    });
                  },
                ),
                Expanded(
                  child: DropTargetPanel(
                    panelId: widget.panelId,
                    currentPath: panelState.currentPath,
                    onDrop: _handleDrop,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _activateThisPanel,
                      onSecondaryTapUp: (details) {
                        _handleBackgroundContextMenu(
                          details.globalPosition,
                          activeTabId,
                          controller,
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
                          final isDropTarget =
                              item.isDirectory &&
                              !item.isParentDetails &&
                              dragState.hoveredDropTargetPath == item.path;

                          return PanelFileRow(
                            item: item,
                            panelState: panelState,
                            panelId: widget.panelId,
                            tabId: activeTabId,
                            fimaTheme: fimaTheme,
                            fontSize: fontSize,
                            isSelected: isSelected,
                            isFocused: isFocused,
                            isActivePanel: isActivePanel,
                            isDropTarget: isDropTarget,
                            nameWidthFraction: _nameWidthFraction,
                            sizeWidthFraction: _sizeWidthFraction,
                            splitterWidth: _splitterWidth,
                            dateFormat: _dateFormat,
                            onTapDown: () => _handleTapDown(
                              index,
                              item,
                              controller,
                              panelState.focusedIndex,
                            ),
                            onSecondaryTap: (pos) => _handleItemContextMenu(
                              pos,
                              index,
                              item,
                              activeTabId,
                              controller,
                            ),
                            onRenameSubmitted: controller.renameItem,
                            onRenameCancelled: controller.cancelRenaming,
                            onDrop: _handleDrop,
                          );
                        },
                      ),
                    ),
                  ),
                ),
                if (panelState.quickFilterText.isNotEmpty)
                  PanelQuickFilterBar(
                    filterText: panelState.quickFilterText,
                    fimaTheme: fimaTheme,
                    fontSize: fontSize,
                  ),
                if (panelState.operationProgress != null)
                  PanelOperationProgressBar(
                    progress: panelState.operationProgress!,
                    fimaTheme: fimaTheme,
                    fontSize: fontSize,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
