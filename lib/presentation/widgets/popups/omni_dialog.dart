import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fima/domain/entity/app_action.dart';
import 'package:fima/domain/entity/app_theme.dart';
import 'package:fima/domain/entity/bookmark.dart';
import 'package:fima/domain/entity/path_index_entry.dart';
import 'package:fima/domain/entity/remote_connection.dart';
import 'package:fima/domain/entity/workspace.dart';
import 'package:fima/presentation/providers/action_provider.dart';
import 'package:fima/presentation/providers/settings_provider.dart';
import 'package:fima/presentation/providers/theme_provider.dart';
import 'package:fima/presentation/widgets/popups/omni/omni_item_actions.dart';
import 'package:fima/presentation/widgets/popups/omni/omni_models.dart';
import 'package:fima/presentation/widgets/popups/omni/omni_result_tiles.dart';

export 'package:fima/presentation/widgets/popups/omni/omni_models.dart'
    show OmniMode, WorkspaceAction;

/// Quick-switcher command/path/workspace/bookmark/remote palette dialog.
class OmniDialog extends ConsumerStatefulWidget {
  final String initialText;

  const OmniDialog({super.key, this.initialText = ''});

  @override
  ConsumerState<OmniDialog> createState() => _OmniDialogState();
}

class _OmniDialogState extends ConsumerState<OmniDialog> {
  static const double _itemHeight = 48.0;
  static const double _maxListHeight = 300.0;

  late TextEditingController _controller;
  late FocusNode _focusNode;
  final ScrollController _scrollController = ScrollController();

  List<PathIndexEntry> _filteredPaths = [];
  List<AppAction> _filteredActions = [];
  List<Workspace> _filteredWorkspaces = [];
  List<Bookmark> _filteredBookmarks = [];
  List<RemoteConnection> _filteredConnections = [];
  int _selectedIndex = 0;
  WorkspaceAction _focusedAction = WorkspaceAction.none;

  OmniModeSpec get _spec => OmniModeSpec.fromInput(_controller.text);
  OmniMode get _mode => _spec.mode;

  int get _currentItemCount {
    return switch (_mode) {
      OmniMode.action => _filteredActions.length,
      OmniMode.workspace => _filteredWorkspaces.length,
      OmniMode.bookmark => _filteredBookmarks.length,
      OmniMode.remote => _filteredConnections.length,
      OmniMode.path => _filteredPaths.length,
    };
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController.fromValue(
      TextEditingValue(
        text: widget.initialText,
        selection: TextSelection.collapsed(offset: widget.initialText.length),
      ),
    );
    _focusNode = FocusNode()..requestFocus();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateFilter();
    });
    _controller.addListener(_updateFilter);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _updateFilter() {
    final spec = _spec;
    final query = spec.query;
    final settings = ref.read(userSettingsProvider);

    setState(() {
      _filteredPaths = [];
      _filteredActions = [];
      _filteredWorkspaces = [];
      _filteredBookmarks = [];
      _filteredConnections = [];
      _selectedIndex = 0;

      switch (spec.mode) {
        case OmniMode.action:
          final actions = ActionGenerator(context, ref).generate();
          _filteredActions = actions
              .where((a) => a.label.toLowerCase().contains(query))
              .toList();
          break;
        case OmniMode.workspace:
          _filteredWorkspaces = settings.workspaces
              .where((w) => w.name.toLowerCase().contains(query))
              .toList();
          break;
        case OmniMode.bookmark:
          _filteredBookmarks = settings.bookmarks
              .where(
                (b) =>
                    b.name.toLowerCase().contains(query) ||
                    b.path.toLowerCase().contains(query),
              )
              .toList();
          break;
        case OmniMode.remote:
          _filteredConnections = settings.remoteConnections
              .where(
                (c) =>
                    c.name.toLowerCase().contains(query) ||
                    c.host.toLowerCase().contains(query),
              )
              .toList();
          break;
        case OmniMode.path:
          _filteredPaths = settings.pathIndexes
              .where((e) => e.path.toLowerCase().contains(query))
              .toList();
          break;
      }
    });
  }

  void _handleSubmitWithAction() {
    if (_mode == OmniMode.workspace &&
        _focusedAction != WorkspaceAction.none &&
        _selectedIndex < _filteredWorkspaces.length) {
      final workspace = _filteredWorkspaces[_selectedIndex];
      if (_focusedAction == WorkspaceAction.edit) {
        OmniItemActions.renameWorkspace(context, ref, workspace, _updateFilter);
      } else {
        _deleteWorkspace(workspace);
      }
      return;
    }

    if (_mode == OmniMode.bookmark &&
        _focusedAction != WorkspaceAction.none &&
        _selectedIndex < _filteredBookmarks.length) {
      final bookmark = _filteredBookmarks[_selectedIndex];
      if (_focusedAction == WorkspaceAction.edit) {
        OmniItemActions.renameBookmark(context, ref, bookmark, _updateFilter);
      } else {
        _deleteBookmark(bookmark);
      }
      return;
    }

    if (_mode == OmniMode.remote &&
        _focusedAction != WorkspaceAction.none &&
        _selectedIndex < _filteredConnections.length) {
      final connection = _filteredConnections[_selectedIndex];
      if (_focusedAction == WorkspaceAction.edit) {
        OmniItemActions.editConnection(context, connection, _updateFilter);
      } else {
        _deleteConnection(connection);
      }
      return;
    }

    _handleSubmit();
  }

  void _handleSubmit() {
    final parentContext = Navigator.of(context).context;

    switch (_mode) {
      case OmniMode.action:
        if (_filteredActions.isEmpty) return;
        final action = _filteredActions[_selectedIndex];
        Navigator.of(context).pop();
        action.callback();
        break;
      case OmniMode.workspace:
        if (_focusedAction != WorkspaceAction.none ||
            _filteredWorkspaces.isEmpty) {
          return;
        }
        final workspace = _filteredWorkspaces[_selectedIndex];
        Navigator.of(context).pop();
        OmniItemActions.loadWorkspace(ref, workspace);
        break;
      case OmniMode.bookmark:
        if (_focusedAction != WorkspaceAction.none ||
            _filteredBookmarks.isEmpty) {
          return;
        }
        final bookmark = _filteredBookmarks[_selectedIndex];
        Navigator.of(context).pop();
        OmniItemActions.navigateToPath(ref, bookmark.path);
        break;
      case OmniMode.remote:
        if (_focusedAction != WorkspaceAction.none ||
            _filteredConnections.isEmpty) {
          return;
        }
        final connection = _filteredConnections[_selectedIndex];
        Navigator.of(context).pop();
        OmniItemActions.connectToRemote(
          parentContext: parentContext,
          ref: ref,
          connection: connection,
        );
        break;
      case OmniMode.path:
        final target = _filteredPaths.isNotEmpty
            ? _filteredPaths[_selectedIndex].path
            : _controller.text;
        if (target.isEmpty) return;
        Navigator.of(context).pop();
        OmniItemActions.navigateToPath(ref, target);
        break;
    }
  }

  void _deleteWorkspace(Workspace workspace) {
    ref.read(userSettingsProvider.notifier).deleteWorkspace(workspace.name);
    _updateFilter();
  }

  void _deleteBookmark(Bookmark bookmark) {
    ref.read(userSettingsProvider.notifier).deleteBookmark(bookmark.name);
    _updateFilter();
  }

  void _deleteConnection(RemoteConnection connection) {
    ref
        .read(userSettingsProvider.notifier)
        .deleteRemoteConnection(connection.id);
    _updateFilter();
  }

  void _cycleInlineAction({required bool forward}) {
    if (!_spec.supportsInlineActions || _selectedIndex >= _currentItemCount) {
      return;
    }
    setState(() {
      _focusedAction = switch ((_focusedAction, forward)) {
        (WorkspaceAction.none, true) => WorkspaceAction.edit,
        (WorkspaceAction.edit, true) => WorkspaceAction.delete,
        (WorkspaceAction.none, false) => WorkspaceAction.delete,
        (WorkspaceAction.delete, false) => WorkspaceAction.edit,
        _ => WorkspaceAction.none,
      };
    });
  }

  void _scrollToSelected() {
    if (!_scrollController.hasClients) return;
    final currentScroll = _scrollController.offset;
    final viewHeight = _scrollController.position.viewportDimension;
    final targetOffset = _selectedIndex * _itemHeight;

    if (targetOffset < currentScroll) {
      _scrollController.jumpTo(targetOffset);
    } else if (targetOffset + _itemHeight > currentScroll + viewHeight) {
      _scrollController.jumpTo(targetOffset + _itemHeight - viewHeight);
    }
  }

  Widget _buildResultTile(int index, FimaTheme fimaTheme) {
    final isSelected = index == _selectedIndex;
    final rowFocus = isSelected ? _focusedAction : WorkspaceAction.none;

    switch (_mode) {
      case OmniMode.action:
        final action = _filteredActions[index];
        return OmniSimpleTile(
          label: action.label,
          shortcut: action.shortcut,
          isSelected: isSelected,
          fimaTheme: fimaTheme,
          onTap: () {
            setState(() => _selectedIndex = index);
            _handleSubmit();
          },
        );
      case OmniMode.workspace:
        final workspace = _filteredWorkspaces[index];
        return OmniManageableTile(
          icon: Icons.work,
          iconColor: fimaTheme.textColor,
          title: workspace.name,
          titleFontSize: 16,
          isSelected: isSelected,
          focusedAction: rowFocus,
          fimaTheme: fimaTheme,
          onTap: () {
            setState(() {
              _selectedIndex = index;
              _focusedAction = WorkspaceAction.none;
            });
            _handleSubmit();
          },
          onEdit: () => OmniItemActions.renameWorkspace(
            context,
            ref,
            workspace,
            _updateFilter,
          ),
          onDelete: () => _deleteWorkspace(workspace),
        );
      case OmniMode.bookmark:
        final bookmark = _filteredBookmarks[index];
        return OmniManageableTile(
          icon: Icons.bookmark,
          iconSize: 22,
          iconColor: fimaTheme.accentColor,
          title: bookmark.name,
          subtitle: bookmark.path,
          isSelected: isSelected,
          focusedAction: rowFocus,
          fimaTheme: fimaTheme,
          onTap: () {
            setState(() {
              _selectedIndex = index;
              _focusedAction = WorkspaceAction.none;
            });
            _handleSubmit();
          },
          onEdit: () => OmniItemActions.renameBookmark(
            context,
            ref,
            bookmark,
            _updateFilter,
          ),
          onDelete: () => _deleteBookmark(bookmark),
        );
      case OmniMode.remote:
        final connection = _filteredConnections[index];
        return OmniManageableTile(
          icon: Icons.dns,
          iconColor: fimaTheme.accentColor,
          title: connection.name,
          subtitle:
              '${connection.username}@${connection.host}:${connection.port}',
          editTooltip: 'Edit',
          isSelected: isSelected,
          focusedAction: rowFocus,
          fimaTheme: fimaTheme,
          onTap: () {
            setState(() {
              _selectedIndex = index;
              _focusedAction = WorkspaceAction.none;
            });
            _handleSubmit();
          },
          onEdit: () => OmniItemActions.editConnection(
            context,
            connection,
            _updateFilter,
          ),
          onDelete: () => _deleteConnection(connection),
        );
      case OmniMode.path:
        final entry = _filteredPaths[index];
        return OmniSimpleTile(
          label: entry.path,
          isSelected: isSelected,
          fimaTheme: fimaTheme,
          onTap: () {
            setState(() => _selectedIndex = index);
            _handleSubmit();
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fimaTheme = ref.watch(themeProvider);
    final spec = _spec;
    final itemCount = _currentItemCount;
    final listHeight = (itemCount * _itemHeight).clamp(0.0, _maxListHeight);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      alignment: Alignment.topCenter,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Material(
          elevation: 24,
          color: fimaTheme.backgroundColor,
          borderRadius: BorderRadius.circular(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CallbackShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.arrowUp): () {
                      setState(() {
                        _selectedIndex = (_selectedIndex - 1).clamp(
                          0,
                          itemCount - 1,
                        );
                        _focusedAction = WorkspaceAction.none;
                        _scrollToSelected();
                      });
                    },
                    const SingleActivator(LogicalKeyboardKey.arrowDown): () {
                      setState(() {
                        _selectedIndex = (_selectedIndex + 1).clamp(
                          0,
                          itemCount - 1,
                        );
                        _focusedAction = WorkspaceAction.none;
                        _scrollToSelected();
                      });
                    },
                    const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                        _cycleInlineAction(forward: false),
                    const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                        _cycleInlineAction(forward: true),
                    const SingleActivator(LogicalKeyboardKey.enter):
                        _handleSubmitWithAction,
                  },
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    selectAllOnFocus: false,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: spec.hintText,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      prefixIcon: spec.prefixIcon != null
                          ? Icon(spec.prefixIcon, color: fimaTheme.textColor)
                          : null,
                      hintStyle: TextStyle(color: fimaTheme.secondaryTextColor),
                    ),
                    style: TextStyle(fontSize: 18, color: fimaTheme.textColor),
                  ),
                ),
              ),
              if (itemCount > 0) ...[
                const Divider(height: 1),
                SizedBox(
                  height: listHeight,
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: itemCount,
                    itemExtent: _itemHeight,
                    itemBuilder: (_, index) =>
                        _buildResultTile(index, fimaTheme),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
