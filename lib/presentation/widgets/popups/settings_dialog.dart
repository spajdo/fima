import 'dart:convert';
import 'dart:io';

import 'package:fima/domain/entity/app_theme.dart';
import 'package:fima/presentation/providers/settings_provider.dart';
import 'package:fima/presentation/providers/theme_provider.dart';
import 'package:fima/presentation/widgets/panel/panel_overlay.dart';
import 'package:fima/presentation/widgets/popups/key_map_tab.dart';
import 'package:file_picker/file_picker.dart';
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

class _SettingsDialogContentState extends ConsumerState<SettingsDialogContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late double _fontSize;
  late bool _showHiddenFiles;
  late int _maxPathIndexes;
  late String _selectedThemeName;
  List<FimaTheme> _availableThemes = [];
  bool _hasChanges = false;
  bool _themesLoaded = false;
  late bool _useBuiltInTerminal;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final settings = ref.read(userSettingsProvider);
    _fontSize = settings.fontSize;
    _showHiddenFiles = settings.showHiddenFiles;
    _maxPathIndexes = settings.maxPathIndexes;
    _selectedThemeName = settings.themeName;
    _useBuiltInTerminal = settings.useBuiltInTerminal;
    _loadThemes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadThemes() async {
    final themeService = ref.read(themeServiceProvider);
    final themes = await themeService.loadThemes();
    if (mounted) {
      setState(() {
        _availableThemes = themes;
        _themesLoaded = true;
        if (!_availableThemes.any((t) => t.name == _selectedThemeName)) {
          if (_availableThemes.isNotEmpty) {
            _selectedThemeName = _availableThemes.first.name;
          }
        }
      });
    }
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

  void _onThemeChanged(String? value) {
    if (value != null) {
      setState(() {
        _selectedThemeName = value;
        _hasChanges = true;
      });
    }
  }

  void _onUseBuiltInTerminalChanged(bool value) {
    setState(() {
      _useBuiltInTerminal = value;
      _hasChanges = true;
    });
  }

  Future<void> _importTheme() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['theme'],
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final themeService = ref.read(themeServiceProvider);
    int importedCount = 0;
    String? lastImportedName;
    String? errorMessage;

    for (final file in result.files) {
      if (file.path == null) continue;

      try {
        final fileObj = File(file.path!);
        if (!await fileObj.exists()) {
          errorMessage = 'File not found: ${file.name}';
          continue;
        }

        final content = await fileObj.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;

        if (!FimaTheme.isValidFimaThemeJson(json)) {
          errorMessage =
              'Invalid theme file: ${file.name}. Missing "fimaTheme" root key.';
          continue;
        }

        final theme = FimaTheme.fromFimaThemeJson(json);
        await themeService.saveTheme(theme);
        importedCount++;
        lastImportedName = theme.name;
      } catch (e) {
        errorMessage = 'Error importing ${file.name}: $e';
      }
    }

    await _loadThemes();

    if (mounted) {
      if (importedCount > 0) {
        setState(() {
          if (lastImportedName != null) {
            _selectedThemeName = lastImportedName;
            _hasChanges = true;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported $importedCount theme(s)'),
            duration: const Duration(seconds: 2),
          ),
        );
      } else if (errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _saveAndReload() async {
    final controller = ref.read(userSettingsProvider.notifier);
    controller.setFontSize(_fontSize);
    if (_showHiddenFiles != ref.read(userSettingsProvider).showHiddenFiles) {
      controller.toggleShowHiddenFiles();
    }
    if (_useBuiltInTerminal !=
        ref.read(userSettingsProvider).useBuiltInTerminal) {
      controller.toggleUseBuiltInTerminal();
    }
    controller.setMaxPathIndexes(_maxPathIndexes);

    final currentThemeName = ref.read(userSettingsProvider).themeName;
    if (_selectedThemeName != currentThemeName) {
      controller.setThemeName(_selectedThemeName);
      final themeController = ref.read(themeProvider.notifier);
      await themeController.loadTheme(_selectedThemeName);
    }

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
          _buildTabBar(theme),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSettingsTab(theme),
                KeyMapTab(
                  onShortcutChanged: () {
                    setState(() {
                      _hasChanges = true;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: theme.colorScheme.primary,
        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
        indicatorColor: theme.colorScheme.primary,
        tabs: const [
          Tab(text: 'Settings'),
          Tab(text: 'Key Map'),
        ],
      ),
    );
  }

  Widget _buildSettingsTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(theme, 'Appearance'),
          const SizedBox(height: 16),
          _buildThemeSelector(theme),
          const SizedBox(height: 16),
          _buildImportThemeButton(theme),
          const SizedBox(height: 24),
          _buildSectionTitle(theme, 'Display'),
          const SizedBox(height: 16),
          _buildFontSizeControl(theme),
          const SizedBox(height: 16),
          _buildShowHiddenFilesControl(theme),
          const SizedBox(height: 24),
          _buildSectionTitle(theme, 'Terminal'),
          const SizedBox(height: 16),
          _buildUseBuiltInTerminalControl(theme),
          const SizedBox(height: 24),
          _buildSectionTitle(theme, 'Performance'),
          const SizedBox(height: 16),
          _buildMaxPathIndexesControl(theme),
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

  Widget _buildThemeSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Theme', style: theme.textTheme.bodyLarge),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: _selectedThemeName,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: _availableThemes.map((t) {
                    return DropdownMenuItem<String>(
                      value: t.name,
                      child: Text(t.name),
                    );
                  }).toList(),
                  onChanged: _themesLoaded ? _onThemeChanged : null,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImportThemeButton(ThemeData theme) {
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: _importTheme,
          icon: const Icon(Icons.file_download),
          label: const Text('Import Theme'),
        ),
      ],
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

  Widget _buildUseBuiltInTerminalControl(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Use built-in terminal', style: theme.textTheme.bodyLarge),
              const SizedBox(height: 4),
              Text(
                'Open terminal inside the panel instead of the system app',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: _useBuiltInTerminal,
          onChanged: _onUseBuiltInTerminalChanged,
        ),
      ],
    );
  }
}
