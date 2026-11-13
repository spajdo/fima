import 'package:flutter/material.dart';

import 'package:fima/domain/entity/app_theme.dart';
import 'package:fima/infrastructure/service/file_diff_service.dart';

/// Pairs a rendered diff row with its index in the unfiltered diff result.
class IndexedDiffRow {
  final int originalIndex;
  final DiffRow row;

  const IndexedDiffRow({required this.originalIndex, required this.row});
}

/// Side-by-side line comparison row inside [FileDiffDialog].
class DiffRowTile extends StatelessWidget {
  final DiffRow row;
  final bool isHunkHighlight;
  final FimaTheme fimaTheme;

  const DiffRowTile({
    super.key,
    required this.row,
    required this.isHunkHighlight,
    required this.fimaTheme,
  });

  @override
  Widget build(BuildContext context) {
    Color? leftBg;
    Color? rightBg;
    String leftMarker = ' ';
    String rightMarker = ' ';
    Color leftMarkerColor = fimaTheme.secondaryTextColor;
    Color rightMarkerColor = fimaTheme.secondaryTextColor;

    switch (row.kind) {
      case DiffRowKind.equal:
        break;
      case DiffRowKind.deleted:
        leftBg = Colors.redAccent.withValues(alpha: 0.14);
        rightBg = fimaTheme.surfaceColor.withValues(alpha: 0.55);
        leftMarker = '-';
        leftMarkerColor = Colors.redAccent;
        break;
      case DiffRowKind.inserted:
        leftBg = fimaTheme.surfaceColor.withValues(alpha: 0.55);
        rightBg = Colors.green.withValues(alpha: 0.14);
        rightMarker = '+';
        rightMarkerColor = Colors.green;
        break;
      case DiffRowKind.modified:
        leftBg = Colors.redAccent.withValues(alpha: 0.12);
        rightBg = Colors.green.withValues(alpha: 0.12);
        leftMarker = '~';
        rightMarker = '~';
        leftMarkerColor = Colors.redAccent;
        rightMarkerColor = Colors.green;
        break;
    }

    return Container(
      decoration: isHunkHighlight
          ? BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: fimaTheme.accentColor.withValues(alpha: 0.7),
                  width: 1,
                ),
              ),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _DiffHalfCell(
              lineNumber: row.leftLineNumber,
              marker: leftMarker,
              text: row.leftText,
              bgColor: leftBg,
              markerColor: leftMarkerColor,
              fimaTheme: fimaTheme,
            ),
          ),
          Container(width: 1, color: fimaTheme.borderColor),
          Expanded(
            child: _DiffHalfCell(
              lineNumber: row.rightLineNumber,
              marker: rightMarker,
              text: row.rightText,
              bgColor: rightBg,
              markerColor: rightMarkerColor,
              fimaTheme: fimaTheme,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiffHalfCell extends StatelessWidget {
  final int? lineNumber;
  final String marker;
  final String? text;
  final Color? bgColor;
  final Color markerColor;
  final FimaTheme fimaTheme;

  const _DiffHalfCell({
    required this.lineNumber,
    required this.marker,
    required this.text,
    required this.bgColor,
    required this.markerColor,
    required this.fimaTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            child: Text(
              lineNumber != null ? '$lineNumber' : '',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: fimaTheme.secondaryTextColor.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 12,
            child: Text(
              marker,
              style: TextStyle(
                fontSize: 11.5,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
                color: markerColor,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: fimaTheme.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
