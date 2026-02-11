import 'package:fima/domain/entity/file_system_item.dart';
import 'package:fima/domain/entity/panel_state.dart';
import 'package:fima/presentation/providers/file_system_provider.dart';
import 'package:fima/presentation/providers/focus_provider.dart';
import 'package:fima/presentation/providers/settings_provider.dart';
import 'package:fima/presentation/widgets/panel/path_editor_dialog.dart';
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
  bool _previousShowHiddenFiles = false;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
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
    // Reload if initialPath changes
    if (oldWidget.initialPath != widget.initialPath &&
        widget.initialPath != null &&
        widget.initialPath!.isNotEmpty) {
      ref
          .read(panelStateProvider(widget.panelId).notifier)
          .loadPath(widget.initialPath!);
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
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 4),
              Icon(
                state.sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 12,
              ),
            ],
          ],
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
    final theme = Theme.of(context);
    final settings = ref.watch(userSettingsProvider);
    final fontSize = settings.fontSize;
    final itemHeight = fontSize + 16.0; // Dynamic height based on font size

    // Check if showHiddenFiles setting changed and refresh if needed
    if (_previousShowHiddenFiles != settings.showHiddenFiles) {
      _previousShowHiddenFiles = settings.showHiddenFiles;
      final currentPath = panelState.currentPath;
      if (currentPath.isNotEmpty) {
        controller.loadPath(currentPath);
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
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          color: theme.colorScheme.surface,
        ),
        child: Column(
          children: [
            // Header with current path
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: theme.colorScheme.surfaceContainerHighest,
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
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit, size: fontSize + 2),
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
              color: theme.colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  const SizedBox(width: 24), // Icon space
                  Expanded(
                    flex: 3,
                    child: _buildColumnHeader(
                      'Name',
                      SortColumn.name,
                      panelState,
                      () => controller.sort(SortColumn.name),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: _buildColumnHeader(
                      'Size',
                      SortColumn.size,
                      panelState,
                      () => controller.sort(SortColumn.size),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _buildColumnHeader(
                      'Modified',
                      SortColumn.modified,
                      panelState,
                      () => controller.sort(SortColumn.modified),
                    ),
                  ),
                ],
              ),
            ),
            // File list
            Expanded(
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
                  final textColor = isSelected ? Colors.red : null;

                  return GestureDetector(
                    onTap: () {
                      // Single click: Set focus to this panel and index
                      ref
                          .read(focusProvider.notifier)
                          .setActivePanel(
                            widget.panelId == 'left'
                                ? ActivePanel.left
                                : ActivePanel.right,
                          );
                      controller.setFocusedIndex(index);
                      // No selection update on simple click
                    },
                    onDoubleTap: () {
                      // Double click: Navigate or open
                      if (item.isDirectory || item.isParentDetails) {
                        controller.loadPath(item.path);
                      } else {
                        // Open file with default program
                        OpenFile.open(item.path);
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        // Background highlights focused item (Cursor)
                        color: isFocused && isActivePanel
                            ? theme.colorScheme.secondaryContainer
                            : isFocused
                            ? theme.colorScheme.surfaceContainerHigh
                            : theme.colorScheme.surface,
                        border: isFocused && isActivePanel
                            ? Border.all(
                                color: theme.colorScheme.primary,
                                width: 1,
                              )
                            : null,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: fontSize + 10,
                            child: _buildFileIcon(item, fontSize + 2),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              item.name,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: textColor,
                                fontSize: fontSize,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              item.isDirectory && !item.isParentDetails
                                  ? '<DIR>'
                                  : item.isParentDetails
                                  ? ''
                                  : _formatSize(item.size),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: textColor,
                                fontSize: fontSize,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              item.isParentDetails
                                  ? ''
                                  : _dateFormat.format(item.modified),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: textColor,
                                fontSize: fontSize,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
