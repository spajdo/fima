import 'package:fima/presentation/providers/drag_state_provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

typedef DropCallback = Future<void> Function(
  PerformDropEvent event,
  String targetPath,
);

/// Wraps a directory row with a [DropRegion].  When a drag hovers over this
/// widget the `hoveredDropTargetPath` in [dragStateProvider] is updated so the
/// parent panel can render a highlight border.
class DropTargetFolder extends ConsumerWidget {
  final String folderPath;
  final DropCallback onDrop;
  final Widget child;

  const DropTargetFolder({
    super.key,
    required this.folderPath,
    required this.onDrop,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DropRegion(
      formats: const [Formats.fileUri, Formats.plainText],
      hitTestBehavior: HitTestBehavior.opaque,
      onDropOver: (event) {
        ref.read(dragStateProvider.notifier).setHoveredTarget(folderPath);
        final isInternal = ref.read(dragStateProvider).sourcePanelId != null;
        return isInternal ? DropOperation.move : DropOperation.copy;
      },
      onDropLeave: (event) {
        ref.read(dragStateProvider.notifier).setHoveredTarget(null);
      },
      onPerformDrop: (event) async {
        ref.read(dragStateProvider.notifier).setHoveredTarget(null);
        await onDrop(event, folderPath);
      },
      child: child,
    );
  }
}

/// Wraps the entire file list area with a [DropRegion].  Uses translucent hit
/// testing so that [DropTargetFolder] widgets nested inside can intercept first.
class DropTargetPanel extends ConsumerWidget {
  final String panelId;
  final String currentPath;
  final DropCallback onDrop;
  final Widget child;

  const DropTargetPanel({
    super.key,
    required this.panelId,
    required this.currentPath,
    required this.onDrop,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DropRegion(
      formats: const [Formats.fileUri, Formats.plainText],
      hitTestBehavior: HitTestBehavior.translucent,
      onDropOver: (event) {
        final isInternal = ref.read(dragStateProvider).sourcePanelId != null;
        return isInternal ? DropOperation.move : DropOperation.copy;
      },
      onDropLeave: (event) {
        ref.read(dragStateProvider.notifier).setHoveredTarget(null);
      },
      onPerformDrop: (event) async {
        await onDrop(event, currentPath);
      },
      child: child,
    );
  }
}
