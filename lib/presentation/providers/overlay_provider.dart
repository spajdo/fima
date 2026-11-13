import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum OverlayType { none, settings, terminal }

class PanelOverlayState {
  final OverlayType type;
  final bool isLeftPanel;
  final String? toastMessage;
  final bool isToastError;
  final String? terminalPath;
  final String? terminalTabId;

  const PanelOverlayState({
    this.type = OverlayType.none,
    this.isLeftPanel = true,
    this.toastMessage,
    this.isToastError = false,
    this.terminalPath,
    this.terminalTabId,
  });

  PanelOverlayState copyWith({
    OverlayType? type,
    bool? isLeftPanel,
    String? toastMessage,
    bool? isToastError,
    bool clearToast = false,
    String? terminalPath,
    String? terminalTabId,
  }) {
    return PanelOverlayState(
      type: type ?? this.type,
      isLeftPanel: isLeftPanel ?? this.isLeftPanel,
      toastMessage: clearToast ? null : (toastMessage ?? this.toastMessage),
      isToastError: clearToast ? false : (isToastError ?? this.isToastError),
      terminalPath: terminalPath ?? this.terminalPath,
      terminalTabId: terminalTabId ?? this.terminalTabId,
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

  void showTerminal(bool isLeftPanel, String path, {String? tabId}) {
    state = PanelOverlayState(
      type: OverlayType.terminal,
      isLeftPanel: isLeftPanel,
      terminalPath: path,
      terminalTabId: tabId,
    );
  }

  void showToast(String message, {bool isError = false}) {
    state = state.copyWith(toastMessage: message, isToastError: isError);
    Future.delayed(Duration(seconds: isError ? 3 : 2), () {
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
