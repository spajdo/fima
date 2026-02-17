import 'package:flutter_riverpod/flutter_riverpod.dart';

enum OverlayType { none, settings, terminal }

class PanelOverlayState {
  final OverlayType type;
  final bool isLeftPanel;

  const PanelOverlayState({
    this.type = OverlayType.none,
    this.isLeftPanel = true,
  });

  PanelOverlayState copyWith({OverlayType? type, bool? isLeftPanel}) {
    return PanelOverlayState(
      type: type ?? this.type,
      isLeftPanel: isLeftPanel ?? this.isLeftPanel,
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

  void close() {
    state = const PanelOverlayState();
  }
}

final overlayProvider =
    StateNotifierProvider<OverlayController, PanelOverlayState>((ref) {
      return OverlayController();
    });
