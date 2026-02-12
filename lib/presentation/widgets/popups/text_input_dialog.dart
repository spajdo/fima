import 'package:fima/presentation/widgets/popups/base_dialog.dart';
import 'package:flutter/material.dart';

class TextInputDialog extends StatefulWidget {
  final String title;
  final String label;
  final String initialValue;
  final String? okButtonLabel;

  const TextInputDialog({
    super.key,
    required this.title,
    required this.label,
    this.initialValue = '',
    this.okButtonLabel,
  });

  @override
  State<TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<TextInputDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: widget.label,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.okButtonLabel ?? 'OK'),
        ),
      ],
    );
  }

  void _submit() {
    Navigator.of(context).pop(_controller.text);
  }
}
