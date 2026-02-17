import 'package:fima/domain/entity/user_settings.dart';
import 'package:fima/presentation/providers/overlay_provider.dart';
import 'package:fima/presentation/providers/settings_provider.dart';
import 'package:fima/presentation/widgets/bottom_status_bar.dart';
import 'package:fima/presentation/widgets/panel/file_panel.dart';
import 'package:fima/presentation/widgets/popups/settings_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  double _splitRatio = 0.5;
  bool _settingsLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
    });
  }

  Future<void> _loadSettings() async {
    await ref.read(userSettingsProvider.notifier).load();
    final settings = ref.read(userSettingsProvider);

    setState(() {
      _splitRatio = settings.panelSplitRatio;
      _settingsLoaded = true;
    });
  }

  void _updateSplitRatio(double ratio) {
    setState(() {
      _splitRatio = ratio;
    });
    ref.read(userSettingsProvider.notifier).setPanelSplitRatio(ratio);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(userSettingsProvider);
    final overlayState = ref.watch(overlayProvider);

    return Scaffold(
      body: !_settingsLoaded
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final height = constraints.maxHeight;
                      final leftWidth = width * _splitRatio;
                      final rightWidth = width - leftWidth - 4;

                      return Stack(
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: leftWidth,
                                child: FilePanel(
                                  panelId: 'left',
                                  initialPath: settings.leftPanelPath,
                                ),
                              ),
                              GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onHorizontalDragUpdate: (details) {
                                  final newRatio =
                                      (_splitRatio + details.delta.dx / width)
                                          .clamp(0.2, 0.8);
                                  _updateSplitRatio(newRatio);
                                },
                                child: Container(
                                  width: 4,
                                  color: Theme.of(context).dividerColor,
                                  child: Center(
                                    child: Container(
                                      width: 2,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: rightWidth,
                                child: FilePanel(
                                  panelId: 'right',
                                  initialPath: settings.rightPanelPath,
                                ),
                              ),
                            ],
                          ),
                          if (overlayState.isActive)
                            _buildOverlay(
                              overlayState,
                              width,
                              height,
                              settings,
                            ),
                        ],
                      );
                    },
                  ),
                ),
                const BottomStatusBar(),
              ],
            ),
    );
  }

  Widget _buildOverlay(
    PanelOverlayState overlayState,
    double totalWidth,
    double totalHeight,
    UserSettings settings,
  ) {
    final splitterWidth = 4.0;
    final isLeftPanel = overlayState.isLeftPanel;

    double panelWidth;
    double panelX;

    if (isLeftPanel) {
      panelWidth = totalWidth * _splitRatio - splitterWidth / 2;
      panelX = 0;
    } else {
      panelWidth = totalWidth * (1 - _splitRatio) - splitterWidth / 2;
      panelX = totalWidth * _splitRatio + splitterWidth / 2;
    }

    final panelHeight = totalHeight;

    Widget overlayContent;
    switch (overlayState.type) {
      case OverlayType.settings:
        overlayContent = SettingsDialogContent(
          width: panelWidth,
          height: panelHeight,
          onClose: () => ref.read(overlayProvider.notifier).close(),
        );
      case OverlayType.terminal:
        overlayContent = Container(
          color: Colors.black87,
          child: const Center(
            child: Text(
              'Terminal - Coming soon',
              style: TextStyle(color: Colors.white),
            ),
          ),
        );
      case OverlayType.none:
        return const SizedBox.shrink();
    }

    return Positioned(
      left: panelX,
      top: 0,
      width: panelWidth,
      height: panelHeight,
      child: overlayContent,
    );
  }
}
