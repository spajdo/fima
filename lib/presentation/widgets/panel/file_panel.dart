import 'package:fima/domain/entity/app_theme.dart';
import 'package:fima/domain/entity/file_system_item.dart';
import 'package:fima/domain/entity/panel_state.dart';
import 'package:fima/presentation/providers/file_system_provider.dart';
import 'package:fima/presentation/providers/focus_provider.dart';
import 'package:fima/presentation/providers/settings_provider.dart';
import 'package:fima/presentation/providers/theme_provider.dart';
import 'package:fima/presentation/widgets/panel/path_editor_dialog.dart';
import 'package:fima/presentation/widgets/panel/rename_field.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_icon/file_icon.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';

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
  bool _previousShowHiddenFiles = false;

  // Column width fractions (the third column gets the remainder).
  // Defaults approximate the old 3:1:2 flex ratio.
  double _nameWidthFraction = 0.50;
  double _sizeWidthFraction = 0.17;

  static const double _minColumnFraction = 0.10;
  static const double _splitterWidth = 8.0;
  static const double _splitterLineWidth = 1.0;

  int? _lastTappedIndex;
  DateTime? _lastTapTime;
  static const _doubleTapDelay = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _panelFocusNode = FocusNode();
    // Initialize the panel with provided path or default (home)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Only initialize if initialPath is provided and not empty
      final pathToInit =
          (widget.initialPath != null && widget.initialPath!.isNotEmpty)
          ? widget.initialPath
          : null;
      ref.read(panelStateProvider(widget.panelId).notifier).init(pathToInit);

      // Store initial showHiddenFiles value
      _previousShowHiddenFiles = ref.read(userSettingsProvider).showHiddenFiles;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _panelFocusNode.dispose();
    super.dispose();
  }

  void _handleTapDown(
    int index,
    FileSystemItem item,
    PanelController controller,
  ) {
    final now = DateTime.now();

    if (_lastTappedIndex == index &&
        _lastTapTime != null &&
        now.difference(_lastTapTime!) < _doubleTapDelay) {
      if (item.isDirectory || item.isParentDetails) {
        if (item.isParentDetails) {
          controller.navigateToParent();
        } else {
          controller.loadPath(item.path, addToVisited: true);
        }
      } else {
        OpenFile.open(item.path);
      }
      _lastTappedIndex = null;
      _lastTapTime = null;
    } else {
      _panelFocusNode.requestFocus(); // take Flutter focus from terminal
      ref
          .read(focusProvider.notifier)
          .setActivePanel(
            widget.panelId == 'left' ? ActivePanel.left : ActivePanel.right,
          );
      controller.setFocusedIndex(index);
      _lastTappedIndex = index;
      _lastTapTime = now;
    }
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
    // Reload if initialPath changes and we're not already at this path
    if (oldWidget.initialPath != widget.initialPath &&
        widget.initialPath != null &&
        widget.initialPath!.isNotEmpty) {
      final currentState = ref.read(panelStateProvider(widget.panelId));
      if (currentState.currentPath != widget.initialPath) {
        ref
            .read(panelStateProvider(widget.panelId).notifier)
            .loadPath(widget.initialPath!, addToVisited: false);
      }
    }
  }

  String _formatSize(int bytes) {
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

  void _showPathEditor(BuildContext context, String currentPath) {
    final controller = ref.read(panelStateProvider(widget.panelId).notifier);

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => PathEditorDialog(
        currentPath: currentPath,
        onPathChanged: (newPath) {
          controller.loadPath(newPath);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final panelState = ref.watch(panelStateProvider(widget.panelId));
    final controller = ref.read(panelStateProvider(widget.panelId).notifier);
    final fimaTheme = ref.watch(themeProvider);
    final theme = Theme.of(context);
    final settings = ref.watch(userSettingsProvider);
    final fontSize = settings.fontSize;
    final itemHeight = fontSize + 16.0;

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

    ref.listen(panelStateProvider(widget.panelId), (previous, next) {
      if (previous?.focusedIndex != next.focusedIndex) {
        _scrollToIndex(next.focusedIndex, next.items.length, itemHeight);
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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _panelFocusNode.requestFocus(); // take Flutter focus from terminal
          ref
              .read(focusProvider.notifier)
              .setActivePanel(
                widget.panelId == 'left' ? ActivePanel.left : ActivePanel.right,
              );
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: fimaTheme.borderColor),
            color: fimaTheme.backgroundColor,
          ),
          child: Column(
            children: [
              // Header with current path
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: fimaTheme.surfaceColor,
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () =>
                            _showPathEditor(context, panelState.currentPath),
                        child: Text(
                          panelState.currentPath.isEmpty
                              ? '...'
                              : panelState.currentPath,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: fontSize,
                            color: fimaTheme.textColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.edit,
                        size: fontSize + 2,
                        color: fimaTheme.textColor,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Edit path',
                      onPressed: () =>
                          _showPathEditor(context, panelState.currentPath),
                    ),
                  ],
                ),
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

                      // Text color is red if selected (Marked), otherwise default
                      final textColor = isSelected
                          ? Colors.red
                          : fimaTheme.textColor;

                      return GestureDetector(
                        onTapDown: (_) {
                          _handleTapDown(index, item, controller);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? fimaTheme.selectedItemColor
                                : isFocused && isActivePanel
                                ? fimaTheme.focusedItemColor
                                : fimaTheme.backgroundColor,
                            border: isFocused && isActivePanel
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
                                    child: _buildFileIcon(item, fontSize + 2),
                                  ),
                                  Expanded(
                                    child: item.path == panelState.editingPath
                                        ? RenameField(
                                            initialValue: item.name,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: textColor,
                                                  fontSize: fontSize,
                                                ),
                                            onSubmitted: (newName) {
                                              controller.renameItem(newName);
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
                                      item.isDirectory && !item.isParentDetails
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
                                          : _dateFormat.format(item.modified),
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
                    },
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
    );
  }
}
