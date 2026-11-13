import 'package:flutter/material.dart';

import 'package:fima/domain/entity/app_theme.dart';
import 'package:fima/domain/entity/panel_operation_progress.dart';

/// Displays active quick-filter text at the bottom of a file panel.
class PanelQuickFilterBar extends StatelessWidget {
  final String filterText;
  final FimaTheme fimaTheme;
  final double fontSize;

  const PanelQuickFilterBar({
    super.key,
    required this.filterText,
    required this.fimaTheme,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: fimaTheme.surfaceColor,
        border: Border(top: BorderSide(color: fimaTheme.borderColor)),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: fontSize + 2, color: fimaTheme.accentColor),
          const SizedBox(width: 6),
          Text(
            filterText,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: fontSize,
              color: fimaTheme.textColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Displays active file operation progress at the bottom of a file panel.
class PanelOperationProgressBar extends StatelessWidget {
  final PanelOperationProgress progress;
  final FimaTheme fimaTheme;
  final double fontSize;

  const PanelOperationProgressBar({
    super.key,
    required this.progress,
    required this.fimaTheme,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: fimaTheme.surfaceColor,
        border: Border(top: BorderSide(color: fimaTheme.borderColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${progress.operationName}: ${progress.currentItem}',
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
                  value: progress.progress,
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
    );
  }
}
