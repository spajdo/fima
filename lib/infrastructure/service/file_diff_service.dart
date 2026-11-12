import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

enum DiffRowKind { equal, deleted, inserted, modified }

class DiffRow {
  final DiffRowKind kind;
  final int? leftLineNumber;
  final int? rightLineNumber;
  final String? leftText;
  final String? rightText;

  const DiffRow({
    required this.kind,
    this.leftLineNumber,
    this.rightLineNumber,
    this.leftText,
    this.rightText,
  });
}

class FileDiffResult {
  final String leftPath;
  final String rightPath;
  final List<DiffRow> rows;
  final List<int> hunkStartRows;
  final int addedCount;
  final int removedCount;
  final int modifiedCount;
  final String? error;

  const FileDiffResult({
    required this.leftPath,
    required this.rightPath,
    this.rows = const [],
    this.hunkStartRows = const [],
    this.addedCount = 0,
    this.removedCount = 0,
    this.modifiedCount = 0,
    this.error,
  });

  bool get isIdentical =>
      error == null &&
      addedCount == 0 &&
      removedCount == 0 &&
      modifiedCount == 0;
}

class FileDiffService {
  static const int maxDiffFileBytes = 2 * 1024 * 1024;

  static Future<FileDiffResult> compareFiles({
    required String leftPath,
    required String rightPath,
    bool ignoreWhitespace = false,
  }) {
    return compute(_compareFilesIsolate, {
      'leftPath': leftPath,
      'rightPath': rightPath,
      'ignoreWhitespace': ignoreWhitespace,
    });
  }

  /// Pure in-memory line diff helper (also convenient for unit tests).
  static FileDiffResult diffTexts({
    required String leftPath,
    required String rightPath,
    required String leftContent,
    required String rightContent,
    bool ignoreWhitespace = false,
  }) {
    final leftLines = _splitLines(leftContent);
    final rightLines = _splitLines(rightContent);

    final rawOps = _computeLineOps(
      leftLines,
      rightLines,
      ignoreWhitespace: ignoreWhitespace,
    );

    final rows = <DiffRow>[];
    final hunkStartRows = <int>[];
    int added = 0;
    int removed = 0;
    int modified = 0;

    int i = 0;
    while (i < rawOps.length) {
      final op = rawOps[i];
      if (op.kind == _RawOpKind.equal) {
        rows.add(
          DiffRow(
            kind: DiffRowKind.equal,
            leftLineNumber: op.leftIndex! + 1,
            rightLineNumber: op.rightIndex! + 1,
            leftText: leftLines[op.leftIndex!],
            rightText: rightLines[op.rightIndex!],
          ),
        );
        i++;
        continue;
      }

      final deletes = <_RawOp>[];
      final inserts = <_RawOp>[];
      while (i < rawOps.length && rawOps[i].kind != _RawOpKind.equal) {
        if (rawOps[i].kind == _RawOpKind.delete) {
          deletes.add(rawOps[i]);
        } else {
          inserts.add(rawOps[i]);
        }
        i++;
      }

      hunkStartRows.add(rows.length);
      final pairCount = deletes.length < inserts.length
          ? deletes.length
          : inserts.length;

      for (int p = 0; p < pairCount; p++) {
        modified++;
        rows.add(
          DiffRow(
            kind: DiffRowKind.modified,
            leftLineNumber: deletes[p].leftIndex! + 1,
            rightLineNumber: inserts[p].rightIndex! + 1,
            leftText: leftLines[deletes[p].leftIndex!],
            rightText: rightLines[inserts[p].rightIndex!],
          ),
        );
      }

      for (int p = pairCount; p < deletes.length; p++) {
        removed++;
        rows.add(
          DiffRow(
            kind: DiffRowKind.deleted,
            leftLineNumber: deletes[p].leftIndex! + 1,
            leftText: leftLines[deletes[p].leftIndex!],
          ),
        );
      }

      for (int p = pairCount; p < inserts.length; p++) {
        added++;
        rows.add(
          DiffRow(
            kind: DiffRowKind.inserted,
            rightLineNumber: inserts[p].rightIndex! + 1,
            rightText: rightLines[inserts[p].rightIndex!],
          ),
        );
      }
    }

    return FileDiffResult(
      leftPath: leftPath,
      rightPath: rightPath,
      rows: rows,
      hunkStartRows: hunkStartRows,
      addedCount: added,
      removedCount: removed,
      modifiedCount: modified,
    );
  }
}

Future<FileDiffResult> _compareFilesIsolate(Map<String, dynamic> args) async {
  final leftPath = args['leftPath'] as String;
  final rightPath = args['rightPath'] as String;
  final ignoreWhitespace = args['ignoreWhitespace'] as bool? ?? false;

  try {
    final leftText = _readTextFile(leftPath);
    if (leftText.$2 != null) {
      return FileDiffResult(
        leftPath: leftPath,
        rightPath: rightPath,
        error: leftText.$2,
      );
    }

    final rightText = _readTextFile(rightPath);
    if (rightText.$2 != null) {
      return FileDiffResult(
        leftPath: leftPath,
        rightPath: rightPath,
        error: rightText.$2,
      );
    }

    return FileDiffService.diffTexts(
      leftPath: leftPath,
      rightPath: rightPath,
      leftContent: leftText.$1!,
      rightContent: rightText.$1!,
      ignoreWhitespace: ignoreWhitespace,
    );
  } catch (e) {
    return FileDiffResult(
      leftPath: leftPath,
      rightPath: rightPath,
      error: e.toString(),
    );
  }
}

(String?, String?) _readTextFile(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    return (null, 'File not found: $path');
  }
  final length = file.lengthSync();
  if (length > FileDiffService.maxDiffFileBytes) {
    return (null, 'File exceeds 2 MB comparison limit: $path');
  }

  final bytes = file.readAsBytesSync();
  final probeLen = bytes.length < 8192 ? bytes.length : 8192;
  for (int i = 0; i < probeLen; i++) {
    if (bytes[i] == 0) {
      return (null, 'Binary files cannot be compared as text ($path).');
    }
  }

  try {
    return (utf8.decode(bytes), null);
  } catch (_) {
    return (latin1.decode(bytes), null);
  }
}

List<String> _splitLines(String content) {
  if (content.isEmpty) return const [];
  final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final lines = normalized.split('\n');
  if (lines.length > 1 && lines.last.isEmpty) {
    lines.removeLast();
  }
  return lines;
}

enum _RawOpKind { equal, delete, insert }

class _RawOp {
  final _RawOpKind kind;
  final int? leftIndex;
  final int? rightIndex;

  const _RawOp(this.kind, this.leftIndex, this.rightIndex);
}

List<_RawOp> _computeLineOps(
  List<String> leftLines,
  List<String> rightLines, {
  required bool ignoreWhitespace,
}) {
  String norm(String line) =>
      ignoreWhitespace ? line.replaceAll(RegExp(r'\s+'), ' ').trim() : line;

  final leftKeys = leftLines.map(norm).toList(growable: false);
  final rightKeys = rightLines.map(norm).toList(growable: false);

  final n = leftKeys.length;
  final m = rightKeys.length;

  int prefix = 0;
  while (prefix < n && prefix < m && leftKeys[prefix] == rightKeys[prefix]) {
    prefix++;
  }

  int suffix = 0;
  while (suffix < n - prefix &&
      suffix < m - prefix &&
      leftKeys[n - 1 - suffix] == rightKeys[m - 1 - suffix]) {
    suffix++;
  }

  final ops = <_RawOp>[];
  for (int i = 0; i < prefix; i++) {
    ops.add(_RawOp(_RawOpKind.equal, i, i));
  }

  final leftMidLen = n - prefix - suffix;
  final rightMidLen = m - prefix - suffix;

  if (leftMidLen == 0) {
    for (int j = 0; j < rightMidLen; j++) {
      ops.add(_RawOp(_RawOpKind.insert, null, prefix + j));
    }
  } else if (rightMidLen == 0) {
    for (int i = 0; i < leftMidLen; i++) {
      ops.add(_RawOp(_RawOpKind.delete, prefix + i, null));
    }
  } else if (leftMidLen * rightMidLen <= 300000) {
    _appendLcsOps(
      ops: ops,
      leftKeys: leftKeys,
      rightKeys: rightKeys,
      leftOffset: prefix,
      rightOffset: prefix,
      leftLen: leftMidLen,
      rightLen: rightMidLen,
    );
  } else {
    _appendGreedySyncOps(
      ops: ops,
      leftKeys: leftKeys,
      rightKeys: rightKeys,
      leftOffset: prefix,
      rightOffset: prefix,
      leftLen: leftMidLen,
      rightLen: rightMidLen,
    );
  }

  for (int s = 0; s < suffix; s++) {
    ops.add(_RawOp(_RawOpKind.equal, n - suffix + s, m - suffix + s));
  }

  return ops;
}

void _appendLcsOps({
  required List<_RawOp> ops,
  required List<String> leftKeys,
  required List<String> rightKeys,
  required int leftOffset,
  required int rightOffset,
  required int leftLen,
  required int rightLen,
}) {
  final cols = rightLen + 1;
  final dp = List<int>.filled((leftLen + 1) * cols, 0);

  for (int i = leftLen - 1; i >= 0; i--) {
    final rowBase = i * cols;
    final nextRowBase = (i + 1) * cols;
    final leftVal = leftKeys[leftOffset + i];
    for (int j = rightLen - 1; j >= 0; j--) {
      if (leftVal == rightKeys[rightOffset + j]) {
        dp[rowBase + j] = dp[nextRowBase + j + 1] + 1;
      } else {
        final down = dp[nextRowBase + j];
        final right = dp[rowBase + j + 1];
        dp[rowBase + j] = down >= right ? down : right;
      }
    }
  }

  int i = 0;
  int j = 0;
  while (i < leftLen && j < rightLen) {
    if (leftKeys[leftOffset + i] == rightKeys[rightOffset + j]) {
      ops.add(_RawOp(_RawOpKind.equal, leftOffset + i, rightOffset + j));
      i++;
      j++;
    } else if (dp[(i + 1) * cols + j] >= dp[i * cols + j + 1]) {
      ops.add(_RawOp(_RawOpKind.delete, leftOffset + i, null));
      i++;
    } else {
      ops.add(_RawOp(_RawOpKind.insert, null, rightOffset + j));
      j++;
    }
  }

  while (i < leftLen) {
    ops.add(_RawOp(_RawOpKind.delete, leftOffset + i, null));
    i++;
  }
  while (j < rightLen) {
    ops.add(_RawOp(_RawOpKind.insert, null, rightOffset + j));
    j++;
  }
}

void _appendGreedySyncOps({
  required List<_RawOp> ops,
  required List<String> leftKeys,
  required List<String> rightKeys,
  required int leftOffset,
  required int rightOffset,
  required int leftLen,
  required int rightLen,
}) {
  const int maxLookahead = 40;
  int i = 0;
  int j = 0;

  while (i < leftLen && j < rightLen) {
    if (leftKeys[leftOffset + i] == rightKeys[rightOffset + j]) {
      ops.add(_RawOp(_RawOpKind.equal, leftOffset + i, rightOffset + j));
      i++;
      j++;
      continue;
    }

    int bestDi = -1;
    int bestDj = -1;
    int bestDist = maxLookahead * 2 + 1;

    for (int di = 0; di < maxLookahead && i + di < leftLen; di++) {
      final candidate = leftKeys[leftOffset + i + di];
      for (int dj = 0; dj < maxLookahead && j + dj < rightLen; dj++) {
        if (di + dj >= bestDist) break;
        if (candidate == rightKeys[rightOffset + j + dj]) {
          bestDi = di;
          bestDj = dj;
          bestDist = di + dj;
          break;
        }
      }
    }

    if (bestDi == -1) {
      ops.add(_RawOp(_RawOpKind.delete, leftOffset + i, null));
      ops.add(_RawOp(_RawOpKind.insert, null, rightOffset + j));
      i++;
      j++;
    } else {
      for (int d = 0; d < bestDi; d++) {
        ops.add(_RawOp(_RawOpKind.delete, leftOffset + i + d, null));
      }
      for (int d = 0; d < bestDj; d++) {
        ops.add(_RawOp(_RawOpKind.insert, null, rightOffset + j + d));
      }
      i += bestDi;
      j += bestDj;
    }
  }

  while (i < leftLen) {
    ops.add(_RawOp(_RawOpKind.delete, leftOffset + i, null));
    i++;
  }
  while (j < rightLen) {
    ops.add(_RawOp(_RawOpKind.insert, null, rightOffset + j));
    j++;
  }
}

