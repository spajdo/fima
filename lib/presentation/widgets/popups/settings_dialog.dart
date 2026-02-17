import 'package:fima/presentation/providers/settings_provider.dart';
import 'package:fima/presentation/widgets/panel/panel_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsDialogContent extends ConsumerStatefulWidget {
  final double width;
  final double height;
  final VoidCallback onClose;

  const SettingsDialogContent({
    super.key,
    required this.width,
    required this.height,
    required this.onClose,
  });

  @override
  ConsumerState<SettingsDialogContent> createState() =>
      _SettingsDialogContentState();
}

class _SettingsDialogContentState extends ConsumerState<SettingsDialogContent> {
  late double _fontSize;
  late bool _showHiddenFiles;
  late int _maxPathIndexes;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(userSettingsProvider);
    _fontSize = settings.fontSize;
    _showHiddenFiles = settings.showHiddenFiles;
    _maxPathIndexes = settings.maxPathIndexes;
  }

  void _onFontSizeChanged(double value) {
    setState(() {
      _fontSize = value;
      _hasChanges = true;
    });
  }

  void _onShowHiddenFilesChanged(bool value) {
    setState(() {
      _showHiddenFiles = value;
      _hasChanges = true;
    });
  }

  void _onMaxPathIndexesChanged(int value) {
    setState(() {
      _maxPathIndexes = value.clamp(10, 100);
      _hasChanges = true;
    });
  }

  Future<void> _saveAndReload() async {
    final controller = ref.read(userSettingsProvider.notifier);
    controller.setFontSize(_fontSize);
    if (_showHiddenFiles != ref.read(userSettingsProvider).showHiddenFiles) {
      controller.toggleShowHiddenFiles();
    }
    controller.setMaxPathIndexes(_maxPathIndexes);
    await ref.read(userSettingsProvider.notifier).save();
  }

  Future<void> _handleOk() async {
    await _saveAndReload();
    widget.onClose();
  }

  Future<void> _handleApply() async {
    await _saveAndReload();
    setState(() {
      _hasChanges = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _handleCancel() {
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PanelOverlay(
      width: widget.width,
      height: widget.height,
      hasChanges: _hasChanges,
      onOk: _handleOk,
      onCancel: _handleCancel,
      onApply: _handleApply,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(theme),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(theme, 'Display'),
                  const SizedBox(height: 16),
                  _buildFontSizeControl(theme),
                  const SizedBox(height: 16),
                  _buildShowHiddenFilesControl(theme),
                  const SizedBox(height: 24),
                  _buildSectionTitle(theme, 'Performance'),
                  const SizedBox(height: 16),
                  _buildMaxPathIndexesControl(theme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Text(
            'Settings',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.primary,
      ),
    );
  }

  Widget _buildFontSizeControl(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Font size', style: theme.textTheme.bodyLarge),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Text(
                '${_fontSize.toInt()}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: theme.colorScheme.primary,
            inactiveTrackColor: theme.colorScheme.surfaceContainerHighest,
            thumbColor: theme.colorScheme.primary,
            overlayColor: theme.colorScheme.primary.withValues(alpha: 0.12),
          ),
          child: Slider(
            value: _fontSize,
            min: 8,
            max: 32,
            divisions: 24,
            onChanged: _onFontSizeChanged,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '8',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              '32',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildShowHiddenFilesControl(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Show hidden files', style: theme.textTheme.bodyLarge),
              const SizedBox(height: 4),
              Text(
                'Display files starting with a dot',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Switch(value: _showHiddenFiles, onChanged: _onShowHiddenFilesChanged),
      ],
    );
  }

  Widget _buildMaxPathIndexesControl(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Path indexes count', style: theme.textTheme.bodyLarge),
            SizedBox(
              width: 80,
              child: TextField(
                controller: TextEditingController(
                  text: _maxPathIndexes.toString(),
                ),
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                ),
                onSubmitted: (value) {
                  final parsed = int.tryParse(value);
                  if (parsed != null) {
                    _onMaxPathIndexesChanged(parsed);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Maximum number of paths to remember in history (10-100)',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
