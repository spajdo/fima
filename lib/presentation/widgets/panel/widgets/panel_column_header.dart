import 'package:flutter/material.dart';

import 'package:fima/domain/entity/app_theme.dart';
import 'package:fima/domain/entity/panel_state.dart';

/// Shared column geometry computed identically for panel headers and rows.
class PanelColumnWidths {
  final double iconWidth;
  final double availableWidth;
  final double sizeWidth;
  final double modifiedWidth;

  const PanelColumnWidths({
    required this.iconWidth,
    required this.availableWidth,
    required this.sizeWidth,
    required this.modifiedWidth,
  });

  factory PanelColumnWidths.compute({
    required double maxWidth,
    required double fontSize,
    required double splitterWidth,
    required double nameWidthFraction,
    required double sizeWidthFraction,
  }) {
    final iconWidth = fontSize + 10;
    final availableWidth = maxWidth - iconWidth - splitterWidth * 2;
    return PanelColumnWidths(
      iconWidth: iconWidth,
      availableWidth: availableWidth,
      sizeWidth: availableWidth * sizeWidthFraction,
      modifiedWidth:
          availableWidth * (1.0 - nameWidthFraction - sizeWidthFraction),
    );
  }
}

/// Sortable column header bar with interactive resize splitters.
class PanelColumnHeader extends StatelessWidget {
  final PanelState panelState;
  final FimaTheme fimaTheme;
  final double fontSize;
  final double nameWidthFraction;
  final double sizeWidthFraction;
  final double splitterWidth;
  final double splitterLineWidth;
  final ValueChanged<SortColumn> onSort;
  final void Function(double delta, double totalWidth) onResizeName;
  final void Function(double delta, double totalWidth) onResizeSize;

  const PanelColumnHeader({
    super.key,
    required this.panelState,
    required this.fimaTheme,
    required this.fontSize,
    required this.nameWidthFraction,
    required this.sizeWidthFraction,
    required this.splitterWidth,
    required this.splitterLineWidth,
    required this.onSort,
    required this.onResizeName,
    required this.onResizeSize,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: fimaTheme.surfaceColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final widths = PanelColumnWidths.compute(
            maxWidth: constraints.maxWidth,
            fontSize: fontSize,
            splitterWidth: splitterWidth,
            nameWidthFraction: nameWidthFraction,
            sizeWidthFraction: sizeWidthFraction,
          );

          return Row(
            children: [
              SizedBox(width: widths.iconWidth),
              Expanded(
                child: _ColumnHeaderButton(
                  title: 'Name',
                  column: SortColumn.name,
                  panelState: panelState,
                  fimaTheme: fimaTheme,
                  theme: theme,
                  onTap: () => onSort(SortColumn.name),
                ),
              ),
              _ColumnSplitter(
                fimaTheme: fimaTheme,
                height: 32,
                width: splitterWidth,
                lineWidth: splitterLineWidth,
                totalWidth: widths.availableWidth,
                onDrag: onResizeName,
              ),
              SizedBox(
                width: widths.sizeWidth,
                child: _ColumnHeaderButton(
                  title: 'Size',
                  column: SortColumn.size,
                  panelState: panelState,
                  fimaTheme: fimaTheme,
                  theme: theme,
                  onTap: () => onSort(SortColumn.size),
                ),
              ),
              _ColumnSplitter(
                fimaTheme: fimaTheme,
                height: 32,
                width: splitterWidth,
                lineWidth: splitterLineWidth,
                totalWidth: widths.availableWidth,
                onDrag: onResizeSize,
              ),
              SizedBox(
                width: widths.modifiedWidth,
                child: _ColumnHeaderButton(
                  title: 'Modified',
                  column: SortColumn.modified,
                  panelState: panelState,
                  fimaTheme: fimaTheme,
                  theme: theme,
                  onTap: () => onSort(SortColumn.modified),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ColumnHeaderButton extends StatelessWidget {
  final String title;
  final SortColumn column;
  final PanelState panelState;
  final FimaTheme fimaTheme;
  final ThemeData theme;
  final VoidCallback onTap;

  const _ColumnHeaderButton({
    required this.title,
    required this.column,
    required this.panelState,
    required this.fimaTheme,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = panelState.sortColumn == column;

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
                panelState.sortAscending
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
                size: 12,
                color: fimaTheme.textColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ColumnSplitter extends StatelessWidget {
  final FimaTheme fimaTheme;
  final double height;
  final double width;
  final double lineWidth;
  final double totalWidth;
  final void Function(double delta, double totalWidth) onDrag;

  const _ColumnSplitter({
    required this.fimaTheme,
    required this.height,
    required this.width,
    required this.lineWidth,
    required this.totalWidth,
    required this.onDrag,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) =>
            onDrag(details.delta.dx, totalWidth),
        child: SizedBox(
          width: width,
          height: height,
          child: Center(
            child: Container(
              width: lineWidth,
              height: height,
              color: fimaTheme.borderColor,
            ),
          ),
        ),
      ),
    );
  }
}
