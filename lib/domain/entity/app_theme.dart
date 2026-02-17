import 'dart:convert';

import 'package:flutter/material.dart';

class FimaTheme {
  final String name;
  final Color backgroundColor;
  final Color surfaceColor;
  final Color textColor;
  final Color secondaryTextColor;
  final Color accentColor;
  final Color borderColor;
  final Color focusedItemColor;
  final Color selectedItemColor;

  static const String _fimaThemeKey = 'fimaTheme';

  const FimaTheme({
    required this.name,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.textColor,
    required this.secondaryTextColor,
    required this.accentColor,
    required this.borderColor,
    required this.focusedItemColor,
    required this.selectedItemColor,
  });

  factory FimaTheme.fromJson(Map<String, dynamic> json) {
    return FimaTheme(
      name: json['name'] as String,
      backgroundColor: _parseColor(json['backgroundColor']),
      surfaceColor: _parseColor(json['surfaceColor']),
      textColor: _parseColor(json['textColor']),
      secondaryTextColor: _parseColor(json['secondaryTextColor']),
      accentColor: _parseColor(json['accentColor']),
      borderColor: _parseColor(json['borderColor']),
      focusedItemColor: _parseColor(json['focusedItemColor']),
      selectedItemColor: _parseColor(json['selectedItemColor']),
    );
  }

  factory FimaTheme.fromFimaThemeJson(Map<String, dynamic> json) {
    final fimaThemeJson = json[_fimaThemeKey];
    if (fimaThemeJson == null) {
      throw FormatException('Invalid theme file: missing "$_fimaThemeKey" key');
    }
    return FimaTheme.fromJson(fimaThemeJson as Map<String, dynamic>);
  }

  static bool isValidFimaThemeJson(Map<String, dynamic> json) {
    return json.containsKey(_fimaThemeKey) &&
        json[_fimaThemeKey] is Map<String, dynamic>;
  }

  Map<String, dynamic> toJson() {
    return {
      _fimaThemeKey: {
        'name': name,
        'backgroundColor': _colorToHex(backgroundColor),
        'surfaceColor': _colorToHex(surfaceColor),
        'textColor': _colorToHex(textColor),
        'secondaryTextColor': _colorToHex(secondaryTextColor),
        'accentColor': _colorToHex(accentColor),
        'borderColor': _colorToHex(borderColor),
        'focusedItemColor': _colorToHex(focusedItemColor),
        'selectedItemColor': _colorToHex(selectedItemColor),
      },
    };
  }

  static Color _parseColor(dynamic value) {
    if (value == null) {
      return Colors.black;
    }
    final hex = value.toString().replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  static String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());

  FimaTheme copyWith({
    String? name,
    Color? backgroundColor,
    Color? surfaceColor,
    Color? textColor,
    Color? secondaryTextColor,
    Color? accentColor,
    Color? borderColor,
    Color? focusedItemColor,
    Color? selectedItemColor,
  }) {
    return FimaTheme(
      name: name ?? this.name,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      textColor: textColor ?? this.textColor,
      secondaryTextColor: secondaryTextColor ?? this.secondaryTextColor,
      accentColor: accentColor ?? this.accentColor,
      borderColor: borderColor ?? this.borderColor,
      focusedItemColor: focusedItemColor ?? this.focusedItemColor,
      selectedItemColor: selectedItemColor ?? this.selectedItemColor,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FimaTheme && other.name == name;
  }

  @override
  int get hashCode => name.hashCode;
}
