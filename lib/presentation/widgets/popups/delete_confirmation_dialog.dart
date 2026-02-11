import 'package:flutter/material.dart';

class DeleteConfirmationDialog extends StatelessWidget {
  final int count;

  const DeleteConfirmationDialog({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete Permanently?'),
      content: Text(
        'Are you sure you want to permanently delete $count ${count == 1 ? 'item' : 'items'}?\n'
        'This action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
