import 'dart:io';

import 'package:fima/domain/entity/file_operation.dart';
import 'package:fima/infrastructure/service/system_clipboard_service.dart';
import 'package:fima/presentation/providers/file_system_provider.dart';
import 'package:fima/presentation/providers/focus_provider.dart';
import 'package:fima/presentation/providers/internal_clipboard_provider.dart';
import 'package:fima/presentation/providers/panel_tabs_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

final clipboardActionsProvider = Provider<ClipboardActions>(
  (ref) => ClipboardActions(ref),
);

/// Shared clipboard operations (copy, cut, paste) used by keyboard shortcuts,
/// the omni-panel, and context menus.
class ClipboardActions {
  final Ref _ref;

  ClipboardActions(this._ref);

  Future<void> copyOrCut(
    String activeTabId,
    ClipboardOperation operation, {
    List<String>? explicitPaths,
  }) async {
    final panelState = _ref.read(panelStateProvider(activeTabId));
    List<String> paths = explicitPaths != null
        ? List<String>.from(explicitPaths)
        : panelState.selectedItems.toList();

    if (paths.isEmpty &&
        panelState.focusedIndex >= 0 &&
        panelState.focusedIndex < panelState.items.length) {
      final item = panelState.items[panelState.focusedIndex];
      if (!item.isParentDetails) {
        paths.add(item.path);
      }
    }

    if (paths.isEmpty) return;

    await SystemClipboard.setFilePaths(paths, operation);

    if (operation == ClipboardOperation.cut) {
      _ref
          .read(internalClipboardProvider.notifier)
          .setCutPaths(paths, panelState.currentPath);
    } else {
      _ref.read(internalClipboardProvider.notifier).clearCutPaths();
    }
  }

  Future<void> paste(String activeTabId) async {
    final clipboardData = await SystemClipboard.getFilePaths();
    final destPath = _ref.read(panelStateProvider(activeTabId)).currentPath;

    if (destPath.isEmpty) return;

    final internalClipboard = _ref.read(internalClipboardProvider);
    final repository = _ref.read(fileSystemRepositoryProvider);

    bool isInternalCut = false;
    List<String> paths;

    if (clipboardData != null) {
      paths = clipboardData.$1;

      if (internalClipboard.cutPaths.isNotEmpty &&
          paths.length == internalClipboard.cutPaths.length &&
          internalClipboard.cutSourcePath != null &&
          paths.every((path) => internalClipboard.cutPaths.contains(path))) {
        isInternalCut = true;
      }
    } else if (internalClipboard.cutPaths.isNotEmpty) {
      paths = internalClipboard.cutPaths;
      isInternalCut = true;
    } else {
      return;
    }

    if (paths.isEmpty) return;

    String? sourcePath;
    if (isInternalCut && internalClipboard.cutSourcePath != null) {
      sourcePath = internalClipboard.cutSourcePath;
    } else {
      sourcePath = p.dirname(paths.first);
    }

    final isSameLocation = sourcePath == destPath;

    if (isInternalCut) {
      if (!isSameLocation) {
        final stream = repository.moveItems(
          paths,
          destPath,
          CancellationToken(),
        );
        await for (final _ in stream) {
          // Wait for completion
        }
      }

      _ref.read(internalClipboardProvider.notifier).clearCutPaths();

      final sourcePanelId = _ref
          .read(focusProvider.notifier)
          .getInactivePanelId();
      final sourceTabId = _ref
          .read(panelTabsProvider(sourcePanelId))
          .activeTabId;

      final sourcePanelState = _ref.read(panelStateProvider(sourceTabId));
      String? sourceSelectPath;
      final remaining = sourcePanelState.items
          .where((item) => !paths.contains(item.path))
          .toList();
      if (remaining.isNotEmpty) {
        final focusedIdx = sourcePanelState.focusedIndex;
        if (focusedIdx >= 0 &&
            focusedIdx < sourcePanelState.items.length &&
            !paths.contains(sourcePanelState.items[focusedIdx].path)) {
          sourceSelectPath = sourcePanelState.items[focusedIdx].path;
        } else {
          final targetIdx = focusedIdx.clamp(0, remaining.length - 1);
          sourceSelectPath = remaining[targetIdx].path;
        }
      }

      if (sourcePath != null) {
        _ref
            .read(panelStateProvider(sourceTabId).notifier)
            .loadPath(sourcePath, selectItemPath: sourceSelectPath);
      }
      _ref
          .read(panelStateProvider(activeTabId).notifier)
          .loadPath(destPath, preserveFocusedIndex: true);
    } else {
      if (isSameLocation) {
        final newPaths = _generateCopyNames(paths, destPath);
        for (int i = 0; i < paths.length; i++) {
          await repository.copyItem(paths[i], newPaths[i]);
        }

        final destSelectPath = newPaths.isNotEmpty ? newPaths.first : null;
        _ref
            .read(panelStateProvider(activeTabId).notifier)
            .loadPath(destPath, selectItemPath: destSelectPath);
      } else {
        final stream = repository.copyItems(
          paths,
          destPath,
          CancellationToken(),
        );
        await for (final _ in stream) {
          // Wait for completion
        }

        final copiedFileName = paths.isNotEmpty
            ? p.basename(paths.first)
            : null;
        final destSelectPath = copiedFileName != null
            ? p.join(destPath, copiedFileName)
            : null;
        _ref
            .read(panelStateProvider(activeTabId).notifier)
            .loadPath(destPath, selectItemPath: destSelectPath);
      }
    }
  }

  List<String> _generateCopyNames(List<String> paths, String destPath) {
    final result = <String>[];

    for (final originalPath in paths) {
      final fileName = p.basename(originalPath);
      final dotIndex = fileName.lastIndexOf('.');

      String baseName;
      String extension;

      if (dotIndex > 0) {
        baseName = fileName.substring(0, dotIndex);
        extension = fileName.substring(dotIndex);
      } else {
        baseName = fileName;
        extension = '';
      }

      String newName = '$baseName (copy)$extension';
      String newPath = p.join(destPath, newName);

      int counter = 1;
      while (_fileExists(newPath)) {
        newName = '$baseName ($counter copy)$extension';
        newPath = p.join(destPath, newName);
        counter++;
      }

      result.add(newPath);
    }

    return result;
  }

  bool _fileExists(String path) {
    return File(path).existsSync() || Directory(path).existsSync();
  }
}
