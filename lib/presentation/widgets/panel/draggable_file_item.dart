import 'package:fima/domain/entity/file_system_item.dart';
import 'package:fima/domain/entity/panel_state.dart';
import 'package:fima/presentation/providers/drag_state_provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

class DraggableFileItem extends ConsumerWidget {
  final FileSystemItem item;
  final PanelState panelState;
  final String panelId;
  final Widget child;

  const DraggableFileItem({
    super.key,
    required this.item,
    required this.panelState,
    required this.panelId,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Parent entry and items in rename mode are not draggable.
    if (item.isParentDetails || panelState.editingPath == item.path) {
      return child;
    }

    // Pre-compute paths so both dragBuilder and dragItemProvider share them.
    final paths = panelState.selectedItems.contains(item.path)
        ? panelState.selectedItems.toList()
        : [item.path];

    // Resolve full FileSystemItem list so the preview shows correct icons.
    final dragItems = paths.map((path) {
      return panelState.items.firstWhere(
        (i) => i.path == path,
        orElse: () => FileSystemItem(
          path: path,
          name: p.basename(path),
          size: 0,
          modified: DateTime.now(),
          isDirectory: false,
        ),
      );
    }).toList();

    return DragItemWidget(
      allowedOperations: () => [DropOperation.move, DropOperation.copy],
      dragBuilder: (context, child) => SnapshotSettings(
        constraintsTransform: (constraints) => BoxConstraints(
          maxWidth: constraints.maxWidth,
          maxHeight: double.infinity,
        ),
        child: DragPreviewCard(items: dragItems),
      ),
      dragItemProvider: (request) async {
        ref.read(dragStateProvider.notifier).startInternalDrag(panelId, paths);
        final dragItem = DragItem(localData: paths);

        // Provide a native file URI for local (non-SSH) paths so the OS
        // can accept the drag into external applications.
        if (!item.path.startsWith('ssh://') && paths.isNotEmpty) {
          dragItem.add(Formats.fileUri(Uri.file(paths.first)));
        }

        // Plain-text fallback: all paths, one per line.
        dragItem.add(Formats.plainText(paths.join('\n')));

        return dragItem;
      },
      child: DraggableWidget(
        child: child,
      ),
    );
  }
}

/// Finder-style drag preview: dark card with blue-highlighted rows, one per
/// item. Self-contained (no Theme/Material ancestors required) so the drag
/// snapshot renders correctly.
class DragPreviewCard extends StatelessWidget {
  final List<FileSystemItem> items;

  static const int _maxVisible = 6;
  static const double _maxNameWidth = 200;

  const DragPreviewCard({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final visible = items.take(_maxVisible).toList();
    final overflow = items.length - _maxVisible;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: DefaultTextStyle(
        style: const TextStyle(
          fontFamily: 'sans-serif',
          fontSize: 13,
          color: Colors.white,
          decoration: TextDecoration.none,
        ),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2E),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < visible.length; i++) ...[
                  _itemRow(visible[i]),
                  if (i < visible.length - 1 || overflow > 0)
                    const SizedBox(height: 3),
                ],
                if (overflow > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, left: 4),
                    child: Text(
                      '+ $overflow more',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _itemRow(FileSystemItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF3478F6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(
            item.isDirectory ? FontAwesomeIcons.folder : FontAwesomeIcons.file,
            size: 13,
            color: item.isDirectory ? Colors.amber : Colors.white70,
          ),
          const SizedBox(width: 7),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxNameWidth),
            child: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
