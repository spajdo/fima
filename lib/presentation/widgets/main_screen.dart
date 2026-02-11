import 'package:fima/presentation/providers/settings_provider.dart';
import 'package:fima/presentation/widgets/panel/file_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  // Initial ratio for the splitter
  double _splitRatio = 0.5;
  bool _settingsLoaded = false;

  @override
  void initState() {
    super.initState();
    // Load settings after first frame
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
    // Save to settings
    ref.read(userSettingsProvider.notifier).setPanelSplitRatio(ratio);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(userSettingsProvider);
    
    return Scaffold(
      body: !_settingsLoaded
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final leftWidth = width * _splitRatio;
          final rightWidth = width - leftWidth - 4; // 4 is splitter width

          return Row(
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
                  final newRatio = (_splitRatio + details.delta.dx / width).clamp(0.2, 0.8);
                  _updateSplitRatio(newRatio);
                },
                child: Container(
                  width: 4,
                  color: Theme.of(context).dividerColor,
                  child: Center(
                    child: Container(
                      width: 2,
                      color: Colors.grey, // Visual indicator
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
          );
        },
      ),
    );
  }
}
