import 'package:flutter_riverpod/flutter_riverpod.dart';

class InternalClipboardState {
  final List<String> cutPaths;
  final String? cutSourcePath;
  final DateTime? cutTime;

  const InternalClipboardState({
    this.cutPaths = const [],
    this.cutSourcePath,
    this.cutTime,
  });

  InternalClipboardState copyWith({
    List<String>? cutPaths,
    String? cutSourcePath,
    DateTime? cutTime,
  }) {
    return InternalClipboardState(
      cutPaths: cutPaths ?? this.cutPaths,
      cutSourcePath: cutSourcePath ?? this.cutSourcePath,
      cutTime: cutTime ?? this.cutTime,
    );
  }
}

class InternalClipboardController
    extends StateNotifier<InternalClipboardState> {
  InternalClipboardController() : super(const InternalClipboardState());

  void setCutPaths(List<String> paths, String sourcePath) {
    state = InternalClipboardState(
      cutPaths: paths,
      cutSourcePath: sourcePath,
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
