import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import 'package:fima/presentation/providers/drag_state_provider.dart';
import 'package:fima/presentation/providers/file_system_provider.dart';
import 'package:fima/presentation/providers/operation_status_provider.dart';
import 'package:fima/presentation/providers/panel_tabs_provider.dart';

/// Handles internal cross-panel and external OS file drops onto a panel target.
class PanelDropHandler {
  PanelDropHandler._();

  static Future<void> handleDrop({
    required WidgetRef ref,
    required String panelId,
    required String destinationTabId,
    required PerformDropEvent event,
    required String targetPath,
  }) async {
    final dragState = ref.read(dragStateProvider);

    if (dragState.sourcePanelId != null) {
      await _handleInternalDrop(
        ref: ref,
        dragState: dragState,
        destinationPanelId: panelId,
        destinationTabId: destinationTabId,
        targetPath: targetPath,
      );
      return;
    }

    await _handleExternalDrop(
      ref: ref,
      panelId: panelId,
      destinationTabId: destinationTabId,
      event: event,
      targetPath: targetPath,
    );
  }

  static Future<void> _handleInternalDrop({
    required WidgetRef ref,
    required DragState dragState,
    required String destinationPanelId,
    required String destinationTabId,
    required String targetPath,
  }) async {
    final paths = dragState.draggedPaths;
    final sourcePanelId = dragState.sourcePanelId;
    if (paths.isEmpty || sourcePanelId == null) return;

    final allSameParent = paths.every((path) => p.dirname(path) == targetPath);
    if (allSameParent || paths.any((path) => path == targetPath)) return;

    final sourceTabId = dragState.sourceTabId;
    ref.read(dragStateProvider.notifier).endDrag();

    await ref
        .read(operationStatusProvider.notifier)
        .startDropOperation(
          sourcePaths: paths,
          sourcePanelId: sourcePanelId,
          sourceTabId: sourceTabId,
          destinationPanelId: destinationPanelId,
          destinationTabId: destinationTabId,
          destinationPath: targetPath,
          isCopy: false,
        );
  }

  static Future<void> _handleExternalDrop({
    required WidgetRef ref,
    required String panelId,
    required String destinationTabId,
    required PerformDropEvent event,
    required String targetPath,
  }) async {
    final repository = ref.read(fileSystemRepositoryProvider);
    for (final dropItem in event.session.items) {
      final reader = dropItem.dataReader;
      if (reader == null || !reader.canProvide(Formats.fileUri)) continue;

      final completer = Completer<Uri?>();
      reader.getValue<Uri>(Formats.fileUri, completer.complete);
      final uri = await completer.future;
      if (uri == null) continue;

      final sourcePath = uri.toFilePath();
      final dest = p.join(targetPath, p.basename(sourcePath));
      try {
        await repository.copyItem(sourcePath, dest);
      } catch (e) {
        debugPrint('Error copying dropped file $sourcePath: $e');
      }
    }

    if (ref
        .read(panelTabsProvider(panelId).notifier)
        .hasTab(destinationTabId)) {
      await ref
          .read(panelStateProvider(destinationTabId).notifier)
          .loadPath(
            targetPath,
            addToVisited: false,
            preserveFocusedIndex: true,
          );
    }
  }
}
