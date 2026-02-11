import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

class RenameField extends StatefulWidget {
  final String initialValue;
  final Function(String) onSubmitted;
  final VoidCallback onCancel;
  final TextStyle? style;

  const RenameField({
    super.key,
    required this.initialValue,
    required this.onSubmitted,
    required this.onCancel,
    this.style,
  });

  @override
  State<RenameField> createState() => _RenameFieldState();
}

class _RenameFieldState extends State<RenameField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode(onKeyEvent: _handleKeyEvent);

    // Select filename without extension
    WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_focusNode.hasFocus) {
          _focusNode.requestFocus();
        }
        final name = widget.initialValue;
        final extension = p.extension(name);
        final selectionEnd = name.length - extension.length;
        
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: selectionEnd > 0 ? selectionEnd : name.length,
        );
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        widget.onCancel();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        widget.onSubmitted(_controller.text);
        return KeyEventResult.handled;
      }
      // Consume arrows to prevent panel navigation while editing
      if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
          event.logicalKey == LogicalKeyboardKey.arrowDown ||
          event.logicalKey == LogicalKeyboardKey.arrowLeft ||
          event.logicalKey == LogicalKeyboardKey.arrowRight) {
        return KeyEventResult.ignored; // Let TextField handle it internally
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      autofocus: true,
      cursorWidth: 1.0,
      decoration: const InputDecoration(
        border: InputBorder.none,
        focusedBorder: InputBorder.none,
        enabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        isDense: true,
      ),
      style: widget.style,
      onSubmitted: widget.onSubmitted,
    );
  }
}
