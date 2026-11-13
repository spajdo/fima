import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fima/domain/entity/app_theme.dart';
import 'package:fima/infrastructure/service/file_diff_service.dart';
import 'package:fima/presentation/providers/theme_provider.dart';
import 'package:fima/presentation/widgets/popups/diff/diff_row_tile.dart';
import 'package:fima/presentation/widgets/popups/diff/diff_toolbar.dart';

/// Opens a full-screen side-by-side comparison dialog for two files.
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

  List<IndexedDiffRow> _visibleRows(FileDiffResult result) {
    if (!_onlyChanges) {
      return [
        for (int i = 0; i < result.rows.length; i++)
          IndexedDiffRow(originalIndex: i, row: result.rows[i]),
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

    return [
      for (int i = 0; i < result.rows.length; i++)
        if (include[i]) IndexedDiffRow(originalIndex: i, row: result.rows[i]),
    ];
  }

  void _jumpToHunk(int delta) {
    final result = _result;
    if (result == null || result.hunkStartRows.isEmpty) return;

    final hunks = result.hunkStartRows;
    final nextIdx = _activeHunkIndex < 0
        ? 0
        : (_activeHunkIndex + delta).clamp(0, hunks.length - 1);

    setState(() => _activeHunkIndex = nextIdx);

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

  Widget _buildContent(
    FimaTheme fimaTheme,
    FileDiffResult? result,
    List<IndexedDiffRow> visibleRows,
    int activeHunkRow,
  ) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: fimaTheme.accentColor),
      );
    }

    if (result?.error != null) {
      return Center(
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
                style: TextStyle(fontSize: 13, color: fimaTheme.textColor),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (result != null && result.isIdentical && _onlyChanges) {
      return Center(
        child: Text(
          'Files are identical.',
          style: TextStyle(fontSize: 13.5, color: fimaTheme.secondaryTextColor),
        ),
      );
    }

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: ListView.builder(
        controller: _scrollController,
        itemExtent: _rowHeight,
        itemCount: visibleRows.length,
        itemBuilder: (_, index) {
          final item = visibleRows[index];
          return DiffRowTile(
            row: item.row,
            isHunkHighlight: item.originalIndex == activeHunkRow,
            fimaTheme: fimaTheme,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fimaTheme = ref.watch(themeProvider);
    final result = _result;
    final visibleRows = result != null && result.error == null
        ? _visibleRows(result)
        : const <IndexedDiffRow>[];
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
              DiffToolbar(
                result: result,
                activeHunkIndex: _activeHunkIndex,
                onlyChanges: _onlyChanges,
                ignoreWhitespace: _ignoreWhitespace,
                loading: _loading,
                fimaTheme: fimaTheme,
                onJumpHunk: _jumpToHunk,
                onToggleOnlyChanges: () =>
                    setState(() => _onlyChanges = !_onlyChanges),
                onToggleIgnoreWhitespace: () {
                  _ignoreWhitespace = !_ignoreWhitespace;
                  _runDiff();
                },
                onSwapSides: _swapSides,
                onClose: () => Navigator.of(context).pop(),
              ),
              DiffPathBar(
                leftPath: _leftPath,
                rightPath: _rightPath,
                fimaTheme: fimaTheme,
              ),
              Expanded(
                child: _buildContent(
                  fimaTheme,
                  result,
                  visibleRows,
                  activeHunkRow,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
