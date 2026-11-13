import 'package:file_icon/file_icon.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import 'package:fima/domain/entity/app_theme.dart';
import 'package:fima/domain/entity/file_system_item.dart';
import 'package:fima/domain/entity/panel_state.dart';
import 'package:fima/domain/utils/file_size_formatter.dart';
import 'package:fima/presentation/widgets/panel/draggable_file_item.dart';
import 'package:fima/presentation/widgets/panel/drop_target_item.dart';
import 'package:fima/presentation/widgets/panel/rename_field.dart';
import 'package:fima/presentation/widgets/panel/widgets/panel_column_header.dart';

/// Renders a single file or directory row inside a [FilePanel] list.
class PanelFileRow extends StatelessWidget {
  final FileSystemItem item;
  final PanelState panelState;
  final String panelId;
  final String tabId;
  final FimaTheme fimaTheme;
  final double fontSize;
  final bool isSelected;
  final bool isFocused;
  final bool isActivePanel;
  final bool isDropTarget;
  final double nameWidthFraction;
  final double sizeWidthFraction;
  final double splitterWidth;
  final DateFormat dateFormat;
  final VoidCallback onTapDown;
  final ValueChanged<Offset> onSecondaryTap;
  final ValueChanged<String> onRenameSubmitted;
  final VoidCallback onRenameCancelled;
  final Future<void> Function(PerformDropEvent, String) onDrop;

  const PanelFileRow({
    super.key,
    required this.item,
    required this.panelState,
    required this.panelId,
    required this.tabId,
    required this.fimaTheme,
    required this.fontSize,
    required this.isSelected,
    required this.isFocused,
    required this.isActivePanel,
    required this.isDropTarget,
    required this.nameWidthFraction,
    required this.sizeWidthFraction,
    required this.splitterWidth,
    required this.dateFormat,
    required this.onTapDown,
    required this.onSecondaryTap,
    required this.onRenameSubmitted,
    required this.onRenameCancelled,
    required this.onDrop,
  });

  Widget _buildFileIcon(double size) {
    if (item.isParentDetails) {
      return FaIcon(FontAwesomeIcons.turnUp, size: size);
    }
    if (item.isDirectory) {
      return FaIcon(FontAwesomeIcons.folder, size: size, color: Colors.amber);
    }
    return FileIcon(item.name, size: size);
  }

  String _formatSizeCell() {
    if (item.isParentDetails) return '';
    if (!item.isDirectory) return FileSizeFormatter.format(item.size);
    if (panelState.calculatingDirectories.contains(item.path)) return '...';
    final computedSize = panelState.directorySizes[item.path];
    if (computedSize != null) return FileSizeFormatter.format(computedSize);
    return '<DIR>';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = isSelected ? Colors.red : fimaTheme.textColor;

    Widget rowContent = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => onTapDown(),
      onSecondaryTapUp: (details) => onSecondaryTap(details.globalPosition),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? fimaTheme.selectedItemColor
              : isFocused && isActivePanel
              ? fimaTheme.focusedItemColor
              : fimaTheme.backgroundColor,
          border: isDropTarget
              ? Border.all(color: fimaTheme.accentColor, width: 2)
              : isFocused && isActivePanel
              ? Border.all(color: fimaTheme.accentColor, width: 1)
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final widths = PanelColumnWidths.compute(
              maxWidth: constraints.maxWidth,
              fontSize: fontSize,
              splitterWidth: splitterWidth,
              nameWidthFraction: nameWidthFraction,
              sizeWidthFraction: sizeWidthFraction,
            );
            final textStyle = theme.textTheme.bodySmall?.copyWith(
              color: textColor,
              fontSize: fontSize,
            );

            return Row(
              children: [
                SizedBox(
                  width: widths.iconWidth,
                  child: _buildFileIcon(fontSize + 2),
                ),
                Expanded(
                  child: item.path == panelState.editingPath
                      ? RenameField(
                          initialValue: item.name,
                          style: textStyle,
                          onSubmitted: onRenameSubmitted,
                          onCancel: onRenameCancelled,
                        )
                      : Text(
                          item.name,
                          style: textStyle,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
                SizedBox(width: splitterWidth),
                SizedBox(
                  width: widths.sizeWidth,
                  child: Text(
                    _formatSizeCell(),
                    style: textStyle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: splitterWidth),
                SizedBox(
                  width: widths.modifiedWidth,
                  child: Text(
                    item.isParentDetails
                        ? ''
                        : dateFormat.format(item.modified),
                    style: textStyle,
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
      rowContent = DropTargetFolder(
        folderPath: item.path,
        onDrop: onDrop,
        child: rowContent,
      );
    }

    return DraggableFileItem(
      item: item,
      panelState: panelState,
      panelId: panelId,
      tabId: tabId,
      child: rowContent,
    );
  }
}
