import 'dart:io';

import 'package:fima/domain/entity/desktop_application.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ApplicationPickerDialog extends StatefulWidget {
  final List<DesktopApplication> applications;

  const ApplicationPickerDialog({super.key, required this.applications});

  static Future<DesktopApplication?> show(
    BuildContext context,
    List<DesktopApplication> applications,
  ) {
    return showDialog<DesktopApplication>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => ApplicationPickerDialog(applications: applications),
    );
  }

  @override
  State<ApplicationPickerDialog> createState() =>
      _ApplicationPickerDialogState();
}

class _ApplicationPickerDialogState extends State<ApplicationPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<DesktopApplication> _filteredApps = [];
  int _selectedIndex = 0;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _filteredApps = widget.applications;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredApps = widget.applications;
      } else {
        _filteredApps = widget.applications.where((app) {
          return app.name.toLowerCase().contains(query) ||
              (app.comment?.toLowerCase().contains(query) ?? false);
        }).toList();
      }
      _selectedIndex = 0;
    });
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() {
          if (_selectedIndex < _filteredApps.length - 1) {
            _selectedIndex++;
            _scrollToSelected();
          }
        });
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          if (_selectedIndex > 0) {
            _selectedIndex--;
            _scrollToSelected();
          }
        });
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (_filteredApps.isNotEmpty) {
          _selectApp(_filteredApps[_selectedIndex]);
        }
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        Navigator.of(context).pop();
      }
    }
  }

  void _scrollToSelected() {
    if (_scrollController.hasClients) {
      const itemHeight = 56.0;
      final targetOffset = _selectedIndex * itemHeight;
      final viewportHeight = _scrollController.position.viewportDimension;
      final currentOffset = _scrollController.offset;

      if (targetOffset < currentOffset) {
        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      } else if (targetOffset + itemHeight > currentOffset + viewportHeight) {
        _scrollController.animateTo(
          targetOffset + itemHeight - viewportHeight,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    }
  }

  void _selectApp(DesktopApplication app) {
    Navigator.of(context).pop(app);
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      onKeyEvent: _handleKeyEvent,
      child: Dialog(
        elevation: 50,
        shadowColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        child: Container(
          width: 500,
          constraints: const BoxConstraints(maxHeight: 500),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Open with...',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search applications...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) {
                  if (_filteredApps.isNotEmpty) {
                    _selectApp(_filteredApps[_selectedIndex]);
                  }
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _filteredApps.length,
                  itemBuilder: (context, index) {
                    final app = _filteredApps[index];
                    final isSelected = index == _selectedIndex;
                    return Material(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Colors.transparent,
                      child: ListTile(
                        leading: app.icon.isNotEmpty
                            ? _AppIcon(iconPath: app.icon)
                            : const Icon(Icons.apps, size: 24),
                        title: Text(app.name, overflow: TextOverflow.ellipsis),
                        subtitle: app.comment != null
                            ? Text(
                                app.comment!,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              )
                            : null,
                        dense: true,
                        selected: isSelected,
                        onTap: () => _selectApp(app),
                      ),
                    );
                  },
                ),
              ),
              if (_filteredApps.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No applications found',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  final String iconPath;

  const _AppIcon({required this.iconPath});

  @override
  Widget build(BuildContext context) {
    if (iconPath.isEmpty || iconPath.startsWith('/') == false) {
      return const Icon(Icons.apps, size: 24);
    }

    return Image.file(
      File(iconPath),
      width: 24,
      height: 24,
      errorBuilder: (context, error, stackTrace) {
        return const Icon(Icons.apps, size: 24);
      },
    );
  }
}
