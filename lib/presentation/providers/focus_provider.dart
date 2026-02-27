import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ActivePanel { left, right }

class FocusState {
  final ActivePanel activePanel;

  const FocusState({this.activePanel = ActivePanel.left});

  FocusState copyWith({ActivePanel? activePanel}) {
    return FocusState(activePanel: activePanel ?? this.activePanel);
  }
}

class FocusController extends StateNotifier<FocusState> {
  FocusController() : super(const FocusState());

  void setActivePanel(ActivePanel panel) {
    state = state.copyWith(activePanel: panel);
  }

  void switchPanel() {
    state = state.copyWith(
      activePanel: state.activePanel == ActivePanel.left
          ? ActivePanel.right
          : ActivePanel.left,
    );
  }

  String getActivePanelId() {
    return state.activePanel == ActivePanel.left ? 'left' : 'right';
  }

  String getInactivePanelId() {
    return state.activePanel == ActivePanel.left ? 'right' : 'left';
  }
}

final focusProvider = StateNotifierProvider<FocusController, FocusState>((ref) {
  return FocusController();
});

/// The [FocusNode] owned by [KeyboardHandler].
/// Registering it here lets any widget return focus directly to the keyboard
/// handler without walking the widget tree or leaving a focus gap.
final keyboardHandlerFocusNodeProvider = Provider<FocusNode>((ref) {
  return FocusNode(debugLabel: 'KeyboardHandler');
});
