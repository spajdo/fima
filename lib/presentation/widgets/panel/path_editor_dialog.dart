import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

class PathEditorDialog extends StatefulWidget {
  final String currentPath;
  final Function(String) onPathChanged;

  const PathEditorDialog({
    super.key,
    required this.currentPath,
    required this.onPathChanged,
  });

  @override
  State<PathEditorDialog> createState() => _PathEditorDialogState();
}

class _PathEditorDialogState extends State<PathEditorDialog> {
  late TextEditingController _controller;
  String? _errorMessage;
  bool _isValidating = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentPath);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _validateAndNavigate() async {
    final path = _controller.text.trim();
    
    if (path.isEmpty) {
      setState(() {
        _errorMessage = 'Path cannot be empty';
      });
      return;
    }

    setState(() {
      _isValidating = true;
      _errorMessage = null;
    });

    try {
      // Normalize the path
      final normalizedPath = p.normalize(path);
      
      // Check if directory exists
      final dir = Directory(normalizedPath);
      final exists = await dir.exists();
      
      if (!exists) {
        setState(() {
          _errorMessage = 'Directory does not exist';
          _isValidating = false;
        });
        return;
      }

      // Try to list directory to check permissions
      try {
        await dir.list().take(1).toList();
      } catch (e) {
        setState(() {
          _errorMessage = 'Access denied: Cannot read directory';
          _isValidating = false;
        });
        return;
      }

      // Navigation successful
      if (mounted) {
        widget.onPathChanged(normalizedPath);
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Invalid path: ${e.toString()}';
        _isValidating = false;
      });
    }
  }

  void _navigateToParent() {
    final currentPath = _controller.text.trim();
    if (currentPath.isNotEmpty) {
      final parent = p.dirname(currentPath);
      if (parent != currentPath) {
        _controller.text = parent;
      }
    }
  }

  void _navigateToHome() async {
    String? home;
    try {
      if (Platform.isMacOS || Platform.isLinux) {
        home = Platform.environment['HOME'];
      } else if (Platform.isWindows) {
        home = Platform.environment['USERPROFILE'];
      }
      if (home != null && home.isNotEmpty) {
        _controller.text = home;
      }
    } catch (_) {
      // Ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      title: const Text('Go to Path'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Directory Path',
                hintText: '/path/to/directory',
                errorText: _errorMessage,
                prefixIcon: const Icon(Icons.folder_open),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _validateAndNavigate(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _navigateToHome,
                  icon: const Icon(Icons.home, size: 16),
                  label: const Text('Home'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _navigateToParent,
                  icon: const Icon(Icons.arrow_upward, size: 16),
                  label: const Text('Parent'),
                ),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: theme.colorScheme.error,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isValidating ? null : _validateAndNavigate,
          child: _isValidating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Go'),
        ),
      ],
    );
  }
}
