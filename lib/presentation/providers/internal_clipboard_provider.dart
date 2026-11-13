import 'package:flutter_riverpod/flutter_riverpod.dart';

class InternalClipboardState {
  final List<String> cutPaths;
  final String? cutSourcePath;
  final String? cutSourcePanelId;
  final String? cutSourceTabId;
  final DateTime? cutTime;

  const InternalClipboardState({
    this.cutPaths = const [],
    this.cutSourcePath,
    this.cutSourcePanelId,
    this.cutSourceTabId,
    this.cutTime,
  });

  InternalClipboardState copyWith({
    List<String>? cutPaths,
    String? cutSourcePath,
    String? cutSourcePanelId,
    String? cutSourceTabId,
    DateTime? cutTime,
  }) {
    return InternalClipboardState(
      cutPaths: cutPaths ?? this.cutPaths,
      cutSourcePath: cutSourcePath ?? this.cutSourcePath,
      cutSourcePanelId: cutSourcePanelId ?? this.cutSourcePanelId,
      cutSourceTabId: cutSourceTabId ?? this.cutSourceTabId,
      cutTime: cutTime ?? this.cutTime,
    );
  }
}

class InternalClipboardController
    extends StateNotifier<InternalClipboardState> {
  InternalClipboardController() : super(const InternalClipboardState());

  void setCutPaths(
    List<String> paths,
    String sourcePath, {
    String? sourcePanelId,
    String? sourceTabId,
  }) {
    state = InternalClipboardState(
      cutPaths: paths,
      cutSourcePath: sourcePath,
      cutSourcePanelId: sourcePanelId,
      cutSourceTabId: sourceTabId,
      cutTime: DateTime.now(),
    );
  }

  void clearCutPaths() {
    state = const InternalClipboardState();
  }

  bool hasCutPaths() {
    return state.cutPaths.isNotEmpty;
  }
}

final internalClipboardProvider =
    StateNotifierProvider<InternalClipboardController, InternalClipboardState>((
      ref,
    ) {
      return InternalClipboardController();
    });
