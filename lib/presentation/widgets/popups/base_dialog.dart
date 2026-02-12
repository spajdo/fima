import 'package:flutter/material.dart';

class BaseDialog extends StatelessWidget {
  final Widget title;
  final Widget? content;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? contentPadding;
  final double? width;

  const BaseDialog({
    super.key,
    required this.title,
    this.content,
    this.actions,
    this.contentPadding,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    Widget dialog = AlertDialog(
      elevation: 50,
      shadowColor: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      title: title,
      content: content,
      actions: actions,
      contentPadding: contentPadding,
    );

    if (width != null) {
      dialog = SizedBox(
        width: width,
        child: dialog,
      );
    }

    return dialog;
  }
}
