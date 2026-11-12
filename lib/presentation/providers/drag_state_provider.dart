import 'package:flutter_riverpod/flutter_riverpod.dart';

class DragState {
  final String? sourcePanelId;
  final String? sourceTabId;
  final List<String> draggedPaths;
  final String? hoveredDropTargetPath;

  const DragState({
    this.sourcePanelId,
    this.sourceTabId,
    this.draggedPaths = const [],
    this.hoveredDropTargetPath,
  });
}

class DragStateNotifier extends StateNotifier<DragState> {
  DragStateNotifier() : super(const DragState());

  void startInternalDrag(
    String panelId,
    List<String> paths, {
    String? sourceTabId,
  }) {
    state = DragState(
      sourcePanelId: panelId,
      sourceTabId: sourceTabId,
      draggedPaths: paths,
    );
  }

  void setHoveredTarget(String? path) {
    state = DragState(
      sourcePanelId: state.sourcePanelId,
      sourceTabId: state.sourceTabId,
      draggedPaths: state.draggedPaths,
      hoveredDropTargetPath: path,
    );
  }

  void endDrag() {
    state = const DragState();
  }
}

final dragStateProvider = StateNotifierProvider<DragStateNotifier, DragState>(
  (ref) => DragStateNotifier(),
);
