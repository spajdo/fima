import 'package:fima/domain/entity/app_theme.dart';
import 'package:fima/infrastructure/service/file_diff_service.dart';
import 'package:fima/presentation/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

Future<void> showFileDiffDialog(
  BuildContext context, {
  required String leftPath,
  required String rightPath,
}) {
  return showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (context) =>
        FileDiffDialog(leftPath: leftPath, rightPath: rightPath),
  );
}

class FileDiffDialog extends ConsumerStatefulWidget {
  final String leftPath;
  final String rightPath;

  const FileDiffDialog({
    super.key,
    required this.leftPath,
    required this.rightPath,
  });

  @override
  ConsumerState<FileDiffDialog> createState() => _FileDiffDialogState();
}

class _FileDiffDialogState extends ConsumerState<FileDiffDialog> {
  static const double _rowHeight = 22.0;

  late String _leftPath;
  late String _rightPath;
  bool _ignoreWhitespace = false;
  bool _onlyChanges = false;
  bool _loading = true;
  FileDiffResult? _result;
  int _activeHunkIndex = -1;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _leftPath = widget.leftPath;
    _rightPath = widget.rightPath;
    _runDiff();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _runDiff() async {
    setState(() {
      _loading = true;
      _activeHunkIndex = -1;
    });

    final result = await FileDiffService.compareFiles(
      leftPath: _leftPath,
      rightPath: _rightPath,
      ignoreWhitespace: _ignoreWhitespace,
    );

    if (!mounted) return;
    setState(() {
      _result = result;
      _loading = false;
      _activeHunkIndex = result.hunkStartRows.isNotEmpty ? 0 : -1;
    });
  }

  List<_IndexedDiffRow> _visibleRows(FileDiffResult result) {
    if (!_onlyChanges) {
      return [
        for (int i = 0; i < result.rows.length; i++)
          _IndexedDiffRow(originalIndex: i, row: result.rows[i]),
      ];
    }

    const int contextRadius = 2;
    final include = List<bool>.filled(result.rows.length, false);
    for (int i = 0; i < result.rows.length; i++) {
      if (result.rows[i].kind != DiffRowKind.equal) {
        final start = (i - contextRadius).clamp(0, result.rows.length - 1);
        final end = (i + contextRadius).clamp(0, result.rows.length - 1);
        for (int k = start; k <= end; k++) {
          include[k] = true;
        }
      }
    }

    final list = <_IndexedDiffRow>[];
    for (int i = 0; i < result.rows.length; i++) {
      if (include[i]) {
        list.add(_IndexedDiffRow(originalIndex: i, row: result.rows[i]));
      }
    }
    return list;
  }

  void _jumpToHunk(int delta) {
    final result = _result;
    if (result == null || result.hunkStartRows.isEmpty) return;

    final hunks = result.hunkStartRows;
    int nextIdx;
    if (_activeHunkIndex < 0) {
      nextIdx = 0;
    } else {
      nextIdx = (_activeHunkIndex + delta).clamp(0, hunks.length - 1);
    }

    setState(() {
      _activeHunkIndex = nextIdx;
    });

    final targetOriginalRow = hunks[nextIdx];
    final visible = _visibleRows(result);
    final visiblePos = visible.indexWhere(
      (entry) => entry.originalIndex == targetOriginalRow,
    );
    if (visiblePos == -1 || !_scrollController.hasClients) return;

    final maxOffset = _scrollController.position.maxScrollExtent;
    final desired = (visiblePos * _rowHeight - _rowHeight * 2).clamp(
      0.0,
      maxOffset,
    );
    _scrollController.animateTo(
      desired,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
    );
  }

  void _swapSides() {
    final oldLeft = _leftPath;
    _leftPath = _rightPath;
    _rightPath = oldLeft;
    _runDiff();
  }

  @override
  Widget build(BuildContext context) {
    final fimaTheme = ref.watch(themeProvider);

    final result = _result;
    final visibleRows = result != null && result.error == null
        ? _visibleRows(result)
        : const <_IndexedDiffRow>[];
    final hunks = result?.hunkStartRows ?? const <int>[];
    final activeHunkRow =
        (_activeHunkIndex >= 0 && _activeHunkIndex < hunks.length)
        ? hunks[_activeHunkIndex]
        : -1;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: fimaTheme.backgroundColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: fimaTheme.surfaceColor,
                  border: Border(
                    bottom: BorderSide(color: fimaTheme.borderColor),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.compare_outlined,
                      size: 17,
                      color: fimaTheme.accentColor,
                    ),
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
                    if (result != null && result.error == null)
                      _buildSummaryBadges(result, fimaTheme),
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
                                  onPressed: _activeHunkIndex > 0
                                      ? () => _jumpToHunk(-1)
                                      : null,
                                  icon: const Icon(
                                    Icons.keyboard_arrow_up,
                                    size: 18,
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Text(
                                    '${_activeHunkIndex + 1}/${hunks.length}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: fimaTheme.secondaryTextColor,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Next Difference',
                                  onPressed: _activeHunkIndex < hunks.length - 1
                                      ? () => _jumpToHunk(1)
                                      : null,
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 18,
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 8),
                              ],
                              _buildToggleChip(
                                label: 'Only Changes',
                                active: _onlyChanges,
                                fimaTheme: fimaTheme,
                                onTap: () => setState(
                                  () => _onlyChanges = !_onlyChanges,
                                ),
                              ),
                              const SizedBox(width: 6),
                              _buildToggleChip(
                                label: 'Ignore Whitespace',
                                active: _ignoreWhitespace,
                                fimaTheme: fimaTheme,
                                onTap: () {
                                  _ignoreWhitespace = !_ignoreWhitespace;
                                  _runDiff();
                                },
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                tooltip: 'Swap Sides',
                                onPressed: _loading ? null : _swapSides,
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
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Path comparison bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: fimaTheme.backgroundColor,
                  border: Border(
                    bottom: BorderSide(color: fimaTheme.borderColor),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Tooltip(
                        message: _leftPath,
                        child: Text(
                          '${p.basename(_leftPath)}  ($_leftPath)',
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
                        message: _rightPath,
                        child: Text(
                          '${p.basename(_rightPath)}  ($_rightPath)',
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
              ),

              // Content
              Expanded(
                child: _loading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: fimaTheme.accentColor,
                        ),
                      )
                    : (result?.error != null)
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 32,
                                color: Colors.redAccent,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                result!.error!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: fimaTheme.textColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : (result != null && result.isIdentical && _onlyChanges)
                    ? Center(
                        child: Text(
                          'Files are identical.',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: fimaTheme.secondaryTextColor,
                          ),
                        ),
                      )
                    : Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        child: ListView.builder(
                          controller: _scrollController,
                          itemExtent: _rowHeight,
                          itemCount: visibleRows.length,
                          itemBuilder: (context, index) {
                            final item = visibleRows[index];
                            final isHunkStart =
                                item.originalIndex == activeHunkRow;
                            return _DiffRowTile(
                              row: item.row,
                              isHunkHighlight: isHunkStart,
                              fimaTheme: fimaTheme,
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryBadges(FileDiffResult result, FimaTheme fimaTheme) {
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

  Widget _buildToggleChip({
    required String label,
    required bool active,
    required FimaTheme fimaTheme,
    required VoidCallback onTap,
  }) {
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

class _IndexedDiffRow {
  final int originalIndex;
  final DiffRow row;

  const _IndexedDiffRow({required this.originalIndex, required this.row});
}

class _DiffRowTile extends StatelessWidget {
  final DiffRow row;
  final bool isHunkHighlight;
  final FimaTheme fimaTheme;

  const _DiffRowTile({
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
    Color markerColor = fimaTheme.secondaryTextColor;

    switch (row.kind) {
      case DiffRowKind.equal:
        break;
      case DiffRowKind.deleted:
        leftBg = Colors.redAccent.withValues(alpha: 0.14);
        rightBg = fimaTheme.surfaceColor.withValues(alpha: 0.55);
        leftMarker = '-';
        markerColor = Colors.redAccent;
        break;
      case DiffRowKind.inserted:
        leftBg = fimaTheme.surfaceColor.withValues(alpha: 0.55);
        rightBg = Colors.green.withValues(alpha: 0.14);
        rightMarker = '+';
        markerColor = Colors.green;
        break;
      case DiffRowKind.modified:
        leftBg = Colors.redAccent.withValues(alpha: 0.12);
        rightBg = Colors.green.withValues(alpha: 0.12);
        leftMarker = '~';
        rightMarker = '~';
        markerColor = Colors.orange;
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
            child: _buildHalfCell(
              lineNumber: row.leftLineNumber,
              marker: leftMarker,
              text: row.leftText,
              bgColor: leftBg,
              markerColor: row.kind == DiffRowKind.modified
                  ? Colors.redAccent
                  : markerColor,
            ),
          ),
          Container(width: 1, color: fimaTheme.borderColor),
          Expanded(
            child: _buildHalfCell(
              lineNumber: row.rightLineNumber,
              marker: rightMarker,
              text: row.rightText,
              bgColor: rightBg,
              markerColor: row.kind == DiffRowKind.modified
                  ? Colors.green
                  : markerColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHalfCell({
    required int? lineNumber,
    required String marker,
    required String? text,
    required Color? bgColor,
    required Color markerColor,
  }) {
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
