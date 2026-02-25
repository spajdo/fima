import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum OverlayType { none, settings, terminal }

class PanelOverlayState {
  final OverlayType type;
  final bool isLeftPanel;
  final String? toastMessage;

  const PanelOverlayState({
    this.type = OverlayType.none,
    this.isLeftPanel = true,
    this.toastMessage,
  });

  PanelOverlayState copyWith({
    OverlayType? type,
    bool? isLeftPanel,
    String? toastMessage,
    bool clearToast = false,
  }) {
    return PanelOverlayState(
      type: type ?? this.type,
      isLeftPanel: isLeftPanel ?? this.isLeftPanel,
      toastMessage: clearToast ? null : (toastMessage ?? this.toastMessage),
    );
  }

  bool get isActive => type != OverlayType.none;
}

class OverlayController extends StateNotifier<PanelOverlayState> {
  OverlayController() : super(const PanelOverlayState());

  void showSettings(bool isLeftPanel) {
    state = PanelOverlayState(
      type: OverlayType.settings,
      isLeftPanel: isLeftPanel,
    );
  }

  void showTerminal(bool isLeftPanel) {
    state = PanelOverlayState(
      type: OverlayType.terminal,
      isLeftPanel: isLeftPanel,
    );
  }

  void showToast(String message) {
    state = state.copyWith(toastMessage: message);
    Future.delayed(const Duration(seconds: 2), () {
      if (state.toastMessage == message) {
        state = state.copyWith(clearToast: true);
      }
    });
  }

  void close() {
    state = const PanelOverlayState();
  }
}

final overlayProvider =
    StateNotifierProvider<OverlayController, PanelOverlayState>((ref) {
      return OverlayController();
    });
