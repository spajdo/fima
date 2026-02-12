import 'package:flutter/material.dart';

class AppAction {
  final String id;
  final String label;
  final String? shortcut;
  final VoidCallback callback;

  const AppAction({
    required this.id,
    required this.label,
    required this.callback,
    this.shortcut,
  });
}
