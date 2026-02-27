import 'package:fima/domain/entity/app_action.dart';
import 'package:fima/domain/entity/path_index_entry.dart';
import 'package:fima/domain/entity/remote_connection.dart';
import 'package:fima/domain/entity/workspace.dart';
import 'package:fima/infrastructure/repository/compound_file_system_repository.dart';
import 'package:fima/infrastructure/service/secure_password_service.dart';
import 'package:fima/presentation/providers/action_provider.dart';
import 'package:fima/presentation/providers/file_system_provider.dart';
import 'package:fima/presentation/providers/focus_provider.dart';
import 'package:fima/presentation/providers/settings_provider.dart';
import 'package:fima/presentation/providers/theme_provider.dart';
import 'package:fima/presentation/widgets/popups/connect_server_dialog.dart';
import 'package:fima/presentation/widgets/popups/text_input_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum OmniMode { path, action, workspace, remote }

enum WorkspaceAction { none, edit, delete }

class OmniDialog extends ConsumerStatefulWidget {
  final String initialText;

  const OmniDialog({super.key, this.initialText = ''});

  @override
  ConsumerState<OmniDialog> createState() => _OmniDialogState();
}

class _OmniDialogState extends ConsumerState<OmniDialog> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  final ScrollController _scrollController = ScrollController();

  List<PathIndexEntry> _filteredPaths = [];
  List<AppAction> _filteredActions = [];
  List<Workspace> _filteredWorkspaces = [];
  List<RemoteConnection> _filteredConnections = [];
  int _selectedIndex = 0;
  WorkspaceAction _focusedAction = WorkspaceAction.none;

  OmniMode get _mode {
    final text = _controller.text;
    if (text.startsWith('w ')) return OmniMode.workspace;
    if (text.startsWith('r ') || text.startsWith('r ')) return OmniMode.remote;
    if (text.startsWith('>')) return OmniMode.action;
    return OmniMode.path;
  }

  String get _workspaceQuery {
    final text = _controller.text;
    if (_mode == OmniMode.workspace) {
      return text.substring(2).toLowerCase();
    }
    return '';
  }

  String get _remoteQuery {
    final text = _controller.text;
    if (_mode == OmniMode.remote) {
      return text.substring(2).toLowerCase();
    }
    return '';
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

    _focusNode = FocusNode();
    _focusNode.requestFocus();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateFilter();
    });

    _controller.addListener(() {
      _updateFilter();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _updateFilter() {
    final text = _controller.text;

    if (_mode == OmniMode.action) {
      final query = text.substring(1).toLowerCase();
      final actions = ActionGenerator(context, ref).generate();

      setState(() {
        _filteredActions = actions.where((action) {
          return action.label.toLowerCase().contains(query);
        }).toList();
        _filteredPaths = [];
        _filteredWorkspaces = [];
        _selectedIndex = 0;
      });
    } else if (_mode == OmniMode.workspace) {
      final query = _workspaceQuery;
      final allWorkspaces = ref.read(userSettingsProvider).workspaces;

      setState(() {
        _filteredWorkspaces = allWorkspaces.where((workspace) {
          return workspace.name.toLowerCase().contains(query);
        }).toList();
        _filteredPaths = [];
        _filteredActions = [];
        _filteredConnections = [];
        _selectedIndex = 0;
      });
    } else if (_mode == OmniMode.remote) {
      final query = _remoteQuery;
      final allConnections = ref.read(userSettingsProvider).remoteConnections;

      setState(() {
        _filteredConnections = allConnections.where((c) {
          return c.name.toLowerCase().contains(query) ||
              c.host.toLowerCase().contains(query);
        }).toList();
        _filteredPaths = [];
        _filteredActions = [];
        _filteredWorkspaces = [];
        _selectedIndex = 0;
      });
    } else {
      final query = text.toLowerCase();
      final allPaths = ref.read(userSettingsProvider).pathIndexes;

      setState(() {
        _filteredActions = [];
        _filteredWorkspaces = [];
        _filteredConnections = [];
        _filteredPaths = allPaths.where((entry) {
          return entry.path.toLowerCase().contains(query);
        }).toList();
        _selectedIndex = 0;
      });
    }
  }

  void _handleSubmitWithAction() {
    if (_mode == OmniMode.workspace && _focusedAction != WorkspaceAction.none) {
      if (_selectedIndex < _filteredWorkspaces.length) {
        final workspace = _filteredWorkspaces[_selectedIndex];
        if (_focusedAction == WorkspaceAction.edit) {
          _showRenameDialog(workspace);
        } else if (_focusedAction == WorkspaceAction.delete) {
          _deleteWorkspace(workspace);
        }
      }
      return;
    }
    if (_mode == OmniMode.remote && _focusedAction != WorkspaceAction.none) {
      if (_selectedIndex < _filteredConnections.length) {
        final connection = _filteredConnections[_selectedIndex];
        if (_focusedAction == WorkspaceAction.edit) {
          _showEditConnectionDialog(connection);
        } else if (_focusedAction == WorkspaceAction.delete) {
          _deleteConnection(connection);
        }
      }
      return;
    }
    _handleSubmit();
  }

  void _handleSubmit() {
    if (_mode == OmniMode.action) {
      if (_filteredActions.isNotEmpty) {
        final action = _filteredActions[_selectedIndex];
        Navigator.of(context).pop();
        action.callback();
      }
    } else if (_mode == OmniMode.workspace) {
      if (_focusedAction == WorkspaceAction.none &&
          _filteredWorkspaces.isNotEmpty) {
        final workspace = _filteredWorkspaces[_selectedIndex];
        Navigator.of(context).pop();
        _loadWorkspace(workspace);
      }
    } else if (_mode == OmniMode.remote) {
      if (_focusedAction == WorkspaceAction.none &&
          _filteredConnections.isNotEmpty) {
        final connection = _filteredConnections[_selectedIndex];
        Navigator.of(context).pop();
        _connectToRemote(connection);
      }
    } else {
      if (_filteredPaths.isNotEmpty) {
        final path = _filteredPaths[_selectedIndex].path;
        Navigator.of(context).pop();
        _navigateToPath(path);
      } else if (_controller.text.isNotEmpty) {
        final path = _controller.text;
        Navigator.of(context).pop();
        _navigateToPath(path);
      }
    }
  }

  void _navigateToPath(String path) {
    final focusController = ref.read(focusProvider.notifier);
    final activePanelId = focusController.getActivePanelId();
    final panelController = ref.read(
      panelStateProvider(activePanelId).notifier,
    );
    panelController.loadPath(path);
  }

  void _loadWorkspace(Workspace workspace) {
    ref
        .read(panelStateProvider('left').notifier)
        .loadPath(workspace.leftPanelPath, addToVisited: false);
    ref
        .read(panelStateProvider('right').notifier)
        .loadPath(workspace.rightPanelPath, addToVisited: false);
  }

  void _deleteWorkspace(Workspace workspace) {
    ref.read(userSettingsProvider.notifier).deleteWorkspace(workspace.name);
    _updateFilter();
  }

  void _renameWorkspace(Workspace workspace, String newName) {
    ref
        .read(userSettingsProvider.notifier)
        .updateWorkspace(workspace.name, workspace.copyWith(name: newName));
    _updateFilter();
  }

  void _scrollToSelected(double itemHeight) {
    if (!_scrollController.hasClients) return;

    final currentScroll = _scrollController.offset;
    final viewHeight = _scrollController.position.viewportDimension;
    final targetOffset = _selectedIndex * itemHeight;

    if (targetOffset < currentScroll) {
      _scrollController.jumpTo(targetOffset);
    } else if (targetOffset + itemHeight > currentScroll + viewHeight) {
      _scrollController.jumpTo(targetOffset + itemHeight - viewHeight);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fimaTheme = ref.watch(themeProvider);
    final itemCount = _mode == OmniMode.action
        ? _filteredActions.length
        : _mode == OmniMode.workspace
        ? _filteredWorkspaces.length
        : _mode == OmniMode.remote
        ? _filteredConnections.length
        : _filteredPaths.length;
    final itemHeight = 48.0;
    final maxListHeight = 300.0;
    final listHeight = (itemCount * itemHeight).clamp(0.0, maxListHeight);

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
                        _scrollToSelected(itemHeight);
                      });
                    },
                    const SingleActivator(LogicalKeyboardKey.arrowDown): () {
                      setState(() {
                        _selectedIndex = (_selectedIndex + 1).clamp(
                          0,
                          itemCount - 1,
                        );
                        _focusedAction = WorkspaceAction.none;
                        _scrollToSelected(itemHeight);
                      });
                    },
                    const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
                      if ((_mode == OmniMode.workspace &&
                              _selectedIndex < _filteredWorkspaces.length) ||
                          (_mode == OmniMode.remote &&
                              _selectedIndex < _filteredConnections.length)) {
                        setState(() {
                          if (_focusedAction == WorkspaceAction.none) {
                            _focusedAction = WorkspaceAction.delete;
                          } else if (_focusedAction == WorkspaceAction.delete) {
                            _focusedAction = WorkspaceAction.edit;
                          } else {
                            _focusedAction = WorkspaceAction.none;
                          }
                        });
                      }
                    },
                    const SingleActivator(LogicalKeyboardKey.arrowRight): () {
                      if ((_mode == OmniMode.workspace &&
                              _selectedIndex < _filteredWorkspaces.length) ||
                          (_mode == OmniMode.remote &&
                              _selectedIndex < _filteredConnections.length)) {
                        setState(() {
                          if (_focusedAction == WorkspaceAction.none) {
                            _focusedAction = WorkspaceAction.edit;
                          } else if (_focusedAction == WorkspaceAction.edit) {
                            _focusedAction = WorkspaceAction.delete;
                          } else {
                            _focusedAction = WorkspaceAction.none;
                          }
                        });
                      }
                    },
                    const SingleActivator(LogicalKeyboardKey.enter): () {
                      _handleSubmitWithAction();
                    },
                  },
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    selectAllOnFocus: false,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: _mode == OmniMode.workspace
                          ? 'Search workspaces...'
                          : _mode == OmniMode.remote
                          ? 'Search connections...'
                          : 'Type to search...',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      prefixIcon: _mode == OmniMode.workspace
                          ? Icon(Icons.work, color: fimaTheme.textColor)
                          : _mode == OmniMode.remote
                          ? Icon(Icons.dns, color: fimaTheme.textColor)
                          : null,
                      hintStyle: TextStyle(color: fimaTheme.secondaryTextColor),
                    ),
                    style: TextStyle(fontSize: 18, color: fimaTheme.textColor),
                  ),
                ),
              ),

              if (itemCount > 0) const Divider(height: 1),

              if (itemCount > 0)
                SizedBox(
                  height: listHeight,
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: itemCount,
                    itemExtent: itemHeight,
                    itemBuilder: (context, index) {
                      final isSelected = index == _selectedIndex;

                      if (_mode == OmniMode.action) {
                        final action = _filteredActions[index];
                        return _buildListItem(
                          label: action.label,
                          shortcut: action.shortcut,
                          isSelected: isSelected,
                          onTap: () {
                            setState(() => _selectedIndex = index);
                            _handleSubmit();
                          },
                        );
                      } else if (_mode == OmniMode.workspace) {
                        final workspace = _filteredWorkspaces[index];
                        return _buildWorkspaceItem(
                          workspace: workspace,
                          isSelected: isSelected,
                          focusedAction: index == _selectedIndex
                              ? _focusedAction
                              : WorkspaceAction.none,
                          onTap: () {
                            setState(() {
                              _selectedIndex = index;
                              _focusedAction = WorkspaceAction.none;
                            });
                            _handleSubmit();
                          },
                          onEdit: () {
                            _showRenameDialog(workspace);
                          },
                          onDelete: () {
                            _deleteWorkspace(workspace);
                          },
                        );
                      } else if (_mode == OmniMode.remote) {
                        final connection = _filteredConnections[index];
                        return _buildRemoteConnectionItem(
                          connection: connection,
                          isSelected: isSelected,
                          focusedAction: index == _selectedIndex
                              ? _focusedAction
                              : WorkspaceAction.none,
                          onTap: () {
                            setState(() {
                              _selectedIndex = index;
                              _focusedAction = WorkspaceAction.none;
                            });
                            _handleSubmit();
                          },
                          onEdit: () {
                            _showEditConnectionDialog(connection);
                          },
                          onDelete: () {
                            _deleteConnection(connection);
                          },
                        );
                      } else {
                        final entry = _filteredPaths[index];
                        return _buildListItem(
                          label: entry.path,
                          isSelected: isSelected,
                          onTap: () {
                            setState(() => _selectedIndex = index);
                            _handleSubmit();
                          },
                        );
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRenameDialog(Workspace workspace) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => TextInputDialog(
        title: 'Rename Workspace',
        label: 'Workspace Name',
        okButtonLabel: 'Rename',
        initialValue: workspace.name,
      ),
    ).then((newName) {
      if (newName != null && newName.toString().isNotEmpty) {
        _renameWorkspace(workspace, newName.toString());
      }
    });
  }

  Widget _buildListItem({
    required String label,
    String? shortcut,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final fimaTheme = ref.watch(themeProvider);
    return InkWell(
      onTap: onTap,
      child: Container(
        color: isSelected ? fimaTheme.accentColor.withValues(alpha: 0.1) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: fimaTheme.textColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (shortcut != null)
              Text(
                shortcut,
                style: TextStyle(
                  fontSize: 12,
                  color: fimaTheme.secondaryTextColor,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkspaceItem({
    required Workspace workspace,
    required bool isSelected,
    required WorkspaceAction focusedAction,
    required VoidCallback onTap,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    final fimaTheme = ref.watch(themeProvider);
    return InkWell(
      onTap: onTap,
      child: Container(
        color: isSelected ? fimaTheme.accentColor.withValues(alpha: 0.1) : null,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.work, size: 24, color: fimaTheme.textColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                workspace.name,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 16,
                  color: fimaTheme.textColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildActionButton(
                  icon: Icons.edit,
                  tooltip: 'Rename',
                  isFocused: focusedAction == WorkspaceAction.edit,
                  onTap: onEdit,
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: Icons.delete,
                  tooltip: 'Delete',
                  isFocused: focusedAction == WorkspaceAction.delete,
                  onTap: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required bool isFocused,
    required VoidCallback onTap,
  }) {
    final fimaTheme = ref.watch(themeProvider);
    return Material(
      color: isFocused ? fimaTheme.accentColor : Colors.transparent,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 20,
            color: isFocused ? Colors.white : fimaTheme.secondaryTextColor,
          ),
        ),
      ),
    );
  }

  // ── Remote Connection helpers ────────────────────────────────────────────

  Future<void> _connectToRemote(RemoteConnection connection) async {
    // Capture all ref-dependent values BEFORE any awaits, because the dialog
    // may be disposed (popped) by the time the async calls complete.
    final compoundRepo =
        ref.read(fileSystemRepositoryProvider) as CompoundFileSystemRepository;
    final sshRepo = compoundRepo.sshRepository;
    final focusController = ref.read(focusProvider.notifier);
    final activePanelId = focusController.getActivePanelId();
    final panelNotifier = ref.read(panelStateProvider(activePanelId).notifier);

    if (!sshRepo.isConnected(connection.id)) {
      // Try remembered password first.
      String? password;
      if (connection.rememberPassword) {
        password = await SecurePasswordService().getPassword(connection.id);
      }

      if (password != null && password.isNotEmpty) {
        try {
          await sshRepo.connect(connection, password);
        } catch (e) {
          // Password may be stale; open dialog to re-enter.
          if (mounted) {
            showDialog(
              context: context,
              barrierColor: Colors.black54,
              builder: (_) =>
                  ConnectServerDialog(existingConnection: connection),
            );
          }
          return;
        }
      } else {
        // No saved password, open dialog.
        if (mounted) {
          showDialog(
            context: context,
            barrierColor: Colors.black54,
            builder: (_) => ConnectServerDialog(existingConnection: connection),
          );
        }
        return;
      }
    }

    // Navigate the active panel to the server root.
    panelNotifier.loadSshPath(connection);
  }

  void _showEditConnectionDialog(RemoteConnection connection) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => ConnectServerDialog(existingConnection: connection),
    ).then((_) => _updateFilter());
  }

  void _deleteConnection(RemoteConnection connection) {
    ref
        .read(userSettingsProvider.notifier)
        .deleteRemoteConnection(connection.id);
    _updateFilter();
  }

  Widget _buildRemoteConnectionItem({
    required RemoteConnection connection,
    required bool isSelected,
    required WorkspaceAction focusedAction,
    required VoidCallback onTap,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    final fimaTheme = ref.watch(themeProvider);
    return InkWell(
      onTap: onTap,
      child: Container(
        color: isSelected ? fimaTheme.accentColor.withValues(alpha: 0.1) : null,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.dns, size: 24, color: fimaTheme.accentColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    connection.name,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 14,
                      color: fimaTheme.textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${connection.username}@${connection.host}:${connection.port}',
                    style: TextStyle(
                      fontSize: 11,
                      color: fimaTheme.secondaryTextColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildActionButton(
                  icon: Icons.edit,
                  tooltip: 'Edit',
                  isFocused: focusedAction == WorkspaceAction.edit,
                  onTap: onEdit,
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: Icons.delete,
                  tooltip: 'Delete',
                  isFocused: focusedAction == WorkspaceAction.delete,
                  onTap: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
