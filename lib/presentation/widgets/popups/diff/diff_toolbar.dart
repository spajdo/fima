import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'package:fima/domain/entity/app_theme.dart';
import 'package:fima/infrastructure/service/file_diff_service.dart';

/// Top toolbar of [FileDiffDialog] with summary counts, hunk navigation, and options.
class DiffToolbar extends StatelessWidget {
  final FileDiffResult? result;
  final int activeHunkIndex;
  final bool onlyChanges;
  final bool ignoreWhitespace;
  final bool loading;
  final FimaTheme fimaTheme;
  final ValueChanged<int> onJumpHunk;
  final VoidCallback onToggleOnlyChanges;
  final VoidCallback onToggleIgnoreWhitespace;
  final VoidCallback onSwapSides;
  final VoidCallback onClose;

  const DiffToolbar({
    super.key,
    required this.result,
    required this.activeHunkIndex,
    required this.onlyChanges,
    required this.ignoreWhitespace,
    required this.loading,
    required this.fimaTheme,
    required this.onJumpHunk,
    required this.onToggleOnlyChanges,
    required this.onToggleIgnoreWhitespace,
    required this.onSwapSides,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final hunks = result?.hunkStartRows ?? const <int>[];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: fimaTheme.surfaceColor,
        border: Border(bottom: BorderSide(color: fimaTheme.borderColor)),
      ),
      child: Row(
        children: [
          Icon(Icons.compare_outlined, size: 17, color: fimaTheme.accentColor),
          const SizedBox(width: 8),
          Text(
            'Compare Files',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: fimaTheme.textColor,
            ),
          ),
          const SizedBox(width: 12),
          if (result != null && result!.error == null)
            _DiffSummaryBadges(result: result!),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hunks.isNotEmpty) ...[
                      IconButton(
                        tooltip: 'Previous Difference',
                        onPressed: activeHunkIndex > 0
                            ? () => onJumpHunk(-1)
                            : null,
                        icon: const Icon(Icons.keyboard_arrow_up, size: 18),
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          '${activeHunkIndex + 1}/${hunks.length}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: fimaTheme.secondaryTextColor,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Next Difference',
                        onPressed: activeHunkIndex < hunks.length - 1
                            ? () => onJumpHunk(1)
                            : null,
                        icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                    ],
                    _DiffToggleChip(
                      label: 'Only Changes',
                      active: onlyChanges,
                      fimaTheme: fimaTheme,
                      onTap: onToggleOnlyChanges,
                    ),
                    const SizedBox(width: 6),
                    _DiffToggleChip(
                      label: 'Ignore Whitespace',
                      active: ignoreWhitespace,
                      fimaTheme: fimaTheme,
                      onTap: onToggleIgnoreWhitespace,
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Swap Sides',
                      onPressed: loading ? null : onSwapSides,
                      icon: Icon(
                        Icons.swap_horiz,
                        size: 18,
                        color: fimaTheme.secondaryTextColor,
                      ),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: Icon(
              Icons.close,
              size: 16,
              color: fimaTheme.secondaryTextColor,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            splashRadius: 16,
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

/// Displays the two compared file paths side-by-side above the diff rows.
class DiffPathBar extends StatelessWidget {
  final String leftPath;
  final String rightPath;
  final FimaTheme fimaTheme;

  const DiffPathBar({
    super.key,
    required this.leftPath,
    required this.rightPath,
    required this.fimaTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: fimaTheme.backgroundColor,
        border: Border(bottom: BorderSide(color: fimaTheme.borderColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Tooltip(
              message: leftPath,
              child: Text(
                '${p.basename(leftPath)}  ($leftPath)',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: fimaTheme.secondaryTextColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Container(
            width: 1,
            height: 14,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: fimaTheme.borderColor,
          ),
          Expanded(
            child: Tooltip(
              message: rightPath,
              child: Text(
                '${p.basename(rightPath)}  ($rightPath)',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: fimaTheme.secondaryTextColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiffSummaryBadges extends StatelessWidget {
  final FileDiffResult result;

  const _DiffSummaryBadges({required this.result});

  @override
  Widget build(BuildContext context) {
    if (result.isIdentical) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Identical',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.green,
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (result.addedCount > 0)
          _countChip('+${result.addedCount}', Colors.green),
        if (result.removedCount > 0) ...[
          const SizedBox(width: 4),
          _countChip('-${result.removedCount}', Colors.redAccent),
        ],
        if (result.modifiedCount > 0) ...[
          const SizedBox(width: 4),
          _countChip('~${result.modifiedCount}', Colors.orange),
        ],
      ],
    );
  }

  Widget _countChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _DiffToggleChip extends StatelessWidget {
  final String label;
  final bool active;
  final FimaTheme fimaTheme;
  final VoidCallback onTap;

  const _DiffToggleChip({
    required this.label,
    required this.active,
    required this.fimaTheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? fimaTheme.accentColor.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active ? fimaTheme.accentColor : fimaTheme.borderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            color: active ? fimaTheme.accentColor : fimaTheme.textColor,
          ),
        ),
      ),
    );
  }
}
