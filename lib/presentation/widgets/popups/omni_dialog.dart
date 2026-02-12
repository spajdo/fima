import 'package:fima/domain/entity/app_action.dart';
import 'package:fima/domain/entity/path_index_entry.dart';
import 'package:fima/presentation/providers/action_provider.dart';
import 'package:fima/presentation/providers/file_system_provider.dart';
import 'package:fima/presentation/providers/focus_provider.dart';
import 'package:fima/presentation/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();

    // Set text AND cursor position together — no intermediate "select all" state
    _controller = TextEditingController.fromValue(
      TextEditingValue(
        text: widget.initialText,
        selection: TextSelection.collapsed(offset: widget.initialText.length),
      ),
    );

    _focusNode = FocusNode();
    _focusNode.requestFocus();

    // Initial filter + no postFrameCallback needed for cursor fix anymore
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

  bool get _isActionMode => _controller.text.startsWith('>');

  void _updateFilter() {
    final text = _controller.text;

    if (_isActionMode) {
      final query = text.substring(1).toLowerCase();
      // Generate actions using the provider/generator
      final actions = ActionGenerator(context, ref).generate();

      setState(() {
        _filteredActions = actions.where((action) {
          return action.label.toLowerCase().contains(query);
        }).toList();
        _filteredPaths = [];
        _selectedIndex = 0;
      });
    } else {
      final query = text.toLowerCase();
      final allPaths = ref.read(userSettingsProvider).pathIndexes;

      setState(() {
        _filteredActions = [];
        _filteredPaths = allPaths.where((entry) {
          return entry.path.toLowerCase().contains(query);
        }).toList();
        // Sort by visits count logic is already handled in provider/settings,
        // but if filtering, we might want to keep that order or re-sort by relevance?
        // For now, assume the list from settings is already sorted by visits.
        // If query is present, we might want to prioritize "starts with" or exact matches?
        // Keeping it simple for now: filter preserves order (likely sorted by visits).
        _selectedIndex = 0;
      });
    }
  }

  void _handleSubmit() {
    if (_isActionMode) {
      if (_filteredActions.isNotEmpty) {
        final action = _filteredActions[_selectedIndex];
        Navigator.of(context).pop(); // Close dialog first
        action.callback();
      }
    } else {
      if (_filteredPaths.isNotEmpty) {
        final path = _filteredPaths[_selectedIndex].path;
        Navigator.of(context).pop(); // Close dialog first

        // Navigate active panel to path
        final focusController = ref.read(focusProvider.notifier);
        final activePanelId = focusController.getActivePanelId();
        final panelController = ref.read(
          panelStateProvider(activePanelId).notifier,
        );
        panelController.loadPath(path);
      } else if (_controller.text.isNotEmpty && !_isActionMode) {
        // Allow entering custom path
        final path = _controller.text;
        Navigator.of(context).pop(); // Close dialog first

        final focusController = ref.read(focusProvider.notifier);
        final activePanelId = focusController.getActivePanelId();
        final panelController = ref.read(
          panelStateProvider(activePanelId).notifier,
        );
        panelController.loadPath(path);
      }
    }
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
    // Calculate height based on items, maxing out at some point
    final itemCount = _isActionMode
        ? _filteredActions.length
        : _filteredPaths.length;
    final itemHeight = 48.0;
    final maxListHeight = 300.0;
    final listHeight = (itemCount * itemHeight).clamp(0.0, maxListHeight);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      alignment: Alignment.topCenter,
      child: Container(
        width:
            600, // Fixed width or responsive? Requirement says "input box will be from side to side"
        // "side to side" of the dialog. Use max width constraint.
        constraints: const BoxConstraints(maxWidth: 800),
        child: Material(
          elevation: 24,
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Input field
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
                        _scrollToSelected(itemHeight);
                      });
                    },
                    const SingleActivator(LogicalKeyboardKey.arrowDown): () {
                      setState(() {
                        _selectedIndex = (_selectedIndex + 1).clamp(
                          0,
                          itemCount - 1,
                        );
                        _scrollToSelected(itemHeight);
                      });
                    },
                    const SingleActivator(LogicalKeyboardKey.enter):
                        _handleSubmit,
                  },
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    selectAllOnFocus: false,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Type to search...',
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                    style: const TextStyle(fontSize: 18),
                    // We handle keys manually via CallbackShortcuts or FocusNode events because
                    // TextField consumes arrow keys for cursor movement.
                    // We want arrows to navigate list.
                    // But left/right should still move cursor?
                    // Up/Down should move list selection.
                  ),
                ),
              ),

              if (itemCount > 0) const Divider(height: 1),

              // List
              if (itemCount > 0)
                SizedBox(
                  height: listHeight,
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: itemCount,
                    itemExtent: itemHeight,
                    itemBuilder: (context, index) {
                      final isSelected = index == _selectedIndex;

                      if (_isActionMode) {
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
                      } else {
                        final entry = _filteredPaths[index];
                        return _buildListItem(
                          label: entry.path,
                          // subtitle: 'Visits: ${entry.visitsCount}', // Optional debug info
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

  Widget _buildListItem({
    required String label,
    String? shortcut,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: isSelected
            ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
