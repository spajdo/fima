import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fima/domain/entity/app_theme.dart';
import 'package:fima/domain/entity/key_map_action.dart';
import 'package:fima/domain/entity/panel_state.dart';
import 'package:fima/domain/entity/remote_connection.dart';
import 'package:fima/infrastructure/service/keyboard_utils.dart';
import 'package:fima/presentation/providers/file_system_provider.dart';
import 'package:fima/presentation/providers/focus_provider.dart';
import 'package:fima/presentation/providers/overlay_provider.dart';
import 'package:fima/presentation/providers/panel_tabs_provider.dart';
import 'package:fima/presentation/providers/settings_provider.dart';

/// Displays an interactive breadcrumb strip and inline path editor for local paths.
class PanelPathBar extends ConsumerStatefulWidget {
  final String panelId;
  final String tabId;
  final PanelState panelState;
  final FimaTheme fimaTheme;
  final double fontSize;
  final VoidCallback onActivatePanel;
  final VoidCallback onRestorePanelFocus;

  const PanelPathBar({
    super.key,
    required this.panelId,
    required this.tabId,
    required this.panelState,
    required this.fimaTheme,
    required this.fontSize,
    required this.onActivatePanel,
    required this.onRestorePanelFocus,
  });

  @override
  ConsumerState<PanelPathBar> createState() => _PanelPathBarState();
}

class _PanelPathBarState extends ConsumerState<PanelPathBar> {
  final ScrollController _breadcrumbScrollController = ScrollController();
  late final TextEditingController _pathController;
  late final FocusNode _pathFocusNode;
  String? _pathError;
  bool _isValidatingPath = false;

  @override
  void initState() {
    super.initState();
    _pathController = TextEditingController(
      text: widget.panelState.currentPath,
    );
    _pathFocusNode = FocusNode(onKeyEvent: _handlePathKeyEvent);
    _pathFocusNode.addListener(_onPathFocusChanged);
    if (widget.panelState.isEditingPath) {
      _activatePathEditor(widget.panelState.currentPath);
    }
  }

  @override
  void didUpdateWidget(PanelPathBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabId != widget.tabId && _pathError != null) {
      _pathError = null;
    }
    if (!oldWidget.panelState.isEditingPath &&
        widget.panelState.isEditingPath) {
      _activatePathEditor(widget.panelState.currentPath);
    } else if (oldWidget.panelState.currentPath !=
            widget.panelState.currentPath ||
        (oldWidget.panelState.isEditingPath &&
            !widget.panelState.isEditingPath)) {
      _scrollBreadcrumbsToEnd();
    }
  }

  @override
  void dispose() {
    _pathFocusNode.removeListener(_onPathFocusChanged);
    _pathFocusNode.dispose();
    _pathController.dispose();
    _breadcrumbScrollController.dispose();
    super.dispose();
  }

  void _scrollBreadcrumbsToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_breadcrumbScrollController.hasClients) return;
      _breadcrumbScrollController.jumpTo(
        _breadcrumbScrollController.position.maxScrollExtent,
      );
    });
  }

  void _onPathFocusChanged() {
    if (!_pathFocusNode.hasFocus) {
      final panelState = ref.read(panelStateProvider(widget.tabId));
      if (panelState.isEditingPath) {
        _cancelPathEditing(restoreFocus: false);
      }
    }
  }

  void _activatePathEditor(String currentPath) {
    _pathController.text = currentPath;
    if (_pathError != null) {
      setState(() => _pathError = null);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ref.read(panelStateProvider(widget.tabId)).isEditingPath) return;
      _pathFocusNode.requestFocus();
      _selectAllPathText();
    });
  }

  void _selectAllPathText() {
    _pathController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _pathController.text.length,
    );
  }

  KeyEventResult _handlePathKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _cancelPathEditing(restoreFocus: true);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        _submitPath();
        return KeyEventResult.handled;
      }
      final currentShortcut = KeyboardUtils.buildShortcutString(event);
      if (currentShortcut.isNotEmpty) {
        final editPathShortcut = ref
            .read(userSettingsProvider.notifier)
            .getEffectiveShortcut('editPath');
        if (editPathShortcut != null &&
            KeyMapActionDefs.shortcutsMatch(
              editPathShortcut,
              currentShortcut,
            )) {
          _selectAllPathText();
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  Future<void> _submitPath() async {
    if (_isValidatingPath) return;
    _isValidatingPath = true;

    final tabId = widget.tabId;
    final input = _pathController.text;
    final controller = ref.read(panelStateProvider(tabId).notifier);
    final error = await controller.navigateToPath(input);

    if (!mounted) return;
    _isValidatingPath = false;

    if (error == null) {
      if (_pathError != null) {
        setState(() => _pathError = null);
      }
      widget.onRestorePanelFocus();
    } else {
      setState(() => _pathError = error);
      ref.read(overlayProvider.notifier).showToast(error, isError: true);
      if (ref.read(panelStateProvider(tabId)).isEditingPath &&
          !_pathFocusNode.hasFocus) {
        _pathFocusNode.requestFocus();
      }
    }
  }

  void _cancelPathEditing({required bool restoreFocus}) {
    final tabId = widget.tabId;
    final controller = ref.read(panelStateProvider(tabId).notifier);
    final panelState = ref.read(panelStateProvider(tabId));
    if (!panelState.isEditingPath) return;

    _pathController.text = panelState.currentPath;
    if (_pathError != null) {
      setState(() => _pathError = null);
    }
    controller.stopEditingPath();

    if (restoreFocus) {
      widget.onRestorePanelFocus();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
        final leftTabId = ref.read(panelTabsProvider('left')).activeTabId;
        final rightTabId = ref.read(panelTabsProvider('right')).activeTabId;
        final leftEditing = ref
            .read(panelStateProvider(leftTabId))
            .isEditingPath;
        final rightEditing = ref
            .read(panelStateProvider(rightTabId))
            .isEditingPath;
        if (leftEditing || rightEditing) return;

        final currentFocus = FocusManager.instance.primaryFocus;
        if (currentFocus == null ||
            currentFocus is FocusScopeNode ||
            currentFocus == _pathFocusNode) {
          ref.read(keyboardHandlerFocusNodeProvider).requestFocus();
        }
      });
    }
  }

  List<_PathBreadcrumb> _parseBreadcrumbs(String rawPath) {
    if (rawPath.isEmpty) return const [];

    final driveMatch = RegExp(
      r'^([A-Za-z]:)(?:[/\\](.*))?$',
    ).firstMatch(rawPath);
    if (driveMatch != null) {
      final drive = driveMatch.group(1) ?? '';
      final rest = driveMatch.group(2) ?? '';
      final breadcrumbs = <_PathBreadcrumb>[
        _PathBreadcrumb(label: drive, targetPath: '$drive\\'),
      ];
      final parts = rest
          .split(RegExp(r'[/\\]+'))
          .where((part) => part.isNotEmpty)
          .toList();
      var running = '$drive\\';
      for (int i = 0; i < parts.length; i++) {
        final part = parts[i];
        running = i == 0 ? '$drive\\$part' : '$running\\$part';
        breadcrumbs.add(_PathBreadcrumb(label: part, targetPath: running));
      }
      return breadcrumbs;
    }

    if (rawPath.startsWith('/')) {
      final breadcrumbs = <_PathBreadcrumb>[
        const _PathBreadcrumb(label: '/', targetPath: '/'),
      ];
      final parts = rawPath.split('/').where((part) => part.isNotEmpty);
      var running = '';
      for (final part in parts) {
        running = '$running/$part';
        breadcrumbs.add(_PathBreadcrumb(label: part, targetPath: running));
      }
      return breadcrumbs;
    }

    return [_PathBreadcrumb(label: rawPath, targetPath: rawPath)];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = ref.read(panelStateProvider(widget.tabId).notifier);
    final fimaTheme = widget.fimaTheme;
    final fontSize = widget.fontSize;
    final textStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: fontSize,
      color: fimaTheme.textColor,
    );
    final borderColor = _pathError != null
        ? Colors.redAccent
        : widget.panelState.isEditingPath
        ? fimaTheme.accentColor
        : fimaTheme.borderColor;
    final breadcrumbs = _parseBreadcrumbs(widget.panelState.currentPath);

    return Container(
      constraints: BoxConstraints(minHeight: fontSize + 16),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: widget.panelState.isEditingPath
            ? fimaTheme.backgroundColor
            : fimaTheme.surfaceColor,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: widget.panelState.isEditingPath
          ? TextField(
              controller: _pathController,
              focusNode: _pathFocusNode,
              cursorWidth: 1.0,
              maxLines: 1,
              style: textStyle,
              decoration: const InputDecoration(
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                isDense: true,
              ),
              onChanged: (_) {
                if (_pathError != null) {
                  setState(() => _pathError = null);
                }
              },
              onEditingComplete: () {},
              onTapOutside: (_) => _cancelPathEditing(restoreFocus: false),
            )
          : breadcrumbs.isEmpty
          ? MouseRegion(
              cursor: SystemMouseCursors.text,
              child: GestureDetector(
                key: Key('path_bar_edit_area_${widget.panelId}'),
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  widget.onActivatePanel();
                  controller.startEditingPath();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Text('...', style: textStyle, maxLines: 1),
                ),
              ),
            )
          : SizedBox(
              width: double.infinity,
              height: fontSize + 16,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Positioned.fill(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.text,
                      child: GestureDetector(
                        key: Key('path_bar_edit_area_${widget.panelId}'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          widget.onActivatePanel();
                          controller.startEditingPath();
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 24),
                    child: SingleChildScrollView(
                      controller: _breadcrumbScrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (int i = 0; i < breadcrumbs.length; i++) ...[
                            if (i > 0)
                              Icon(
                                Icons.chevron_right,
                                size: fontSize + 1,
                                color: fimaTheme.secondaryTextColor,
                              ),
                            _BreadcrumbChip(
                              label: breadcrumbs[i].label,
                              isCurrent: i == breadcrumbs.length - 1,
                              fontSize: fontSize,
                              fimaTheme: fimaTheme,
                              onTap: () {
                                widget.onActivatePanel();
                                controller.loadPath(breadcrumbs[i].targetPath);
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// SSH connection header bar shown in place of [PanelPathBar] for remote tabs.
class PanelSshHeader extends ConsumerWidget {
  final String tabId;
  final PanelState panelState;
  final FimaTheme fimaTheme;

  const PanelSshHeader({
    super.key,
    required this.tabId,
    required this.panelState,
    required this.fimaTheme,
  });

  Future<void> _confirmDisconnect(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(panelStateProvider(tabId).notifier);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect from server?'),
        content: const Text('The remote connection will be closed.'),
        actions: [
          FilledButton(
            autofocus: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await controller.disconnectSsh();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final connId = RemoteConnection.connectionIdFromSshUrl(
      panelState.currentPath,
    );
    final settings = ref.read(userSettingsProvider);
    final connection = settings.remoteConnections
        .cast<RemoteConnection?>()
        .firstWhere((c) => c?.id == connId, orElse: () => null);
    final connectionName = connection?.name ?? connId;
    final remotePath = RemoteConnection.remotePathFromSshUrl(
      panelState.currentPath,
    );

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: fimaTheme.surfaceColor,
        border: Border(bottom: BorderSide(color: fimaTheme.borderColor)),
      ),
      child: Row(
        children: [
          Icon(Icons.dns, size: 14, color: fimaTheme.accentColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$connectionName — $remotePath',
              style: theme.textTheme.bodySmall?.copyWith(
                color: fimaTheme.textColor,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            onTap: () => _confirmDisconnect(context, ref),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close, size: 14, color: fimaTheme.textColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _PathBreadcrumb {
  final String label;
  final String targetPath;

  const _PathBreadcrumb({required this.label, required this.targetPath});
}

class _BreadcrumbChip extends StatefulWidget {
  final String label;
  final bool isCurrent;
  final double fontSize;
  final FimaTheme fimaTheme;
  final VoidCallback onTap;

  const _BreadcrumbChip({
    required this.label,
    required this.isCurrent,
    required this.fontSize,
    required this.fimaTheme,
    required this.onTap,
  });

  @override
  State<_BreadcrumbChip> createState() => _BreadcrumbChipState();
}

class _BreadcrumbChipState extends State<_BreadcrumbChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.fimaTheme.accentColor.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: widget.fontSize,
              fontWeight: widget.isCurrent
                  ? FontWeight.w600
                  : FontWeight.normal,
              color: _hovered
                  ? widget.fimaTheme.accentColor
                  : widget.isCurrent
                  ? widget.fimaTheme.textColor
                  : widget.fimaTheme.secondaryTextColor,
            ),
          ),
        ),
      ),
    );
  }
}
