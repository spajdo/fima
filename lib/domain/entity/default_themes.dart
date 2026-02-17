import 'package:flutter/material.dart';

import 'package:fima/domain/entity/app_theme.dart';

class DefaultThemes {
  static const FimaTheme light = FimaTheme(
    name: 'Light',
    backgroundColor: Color(0xFFFFFFFF),
    surfaceColor: Color(0xFFF5F5F5),
    textColor: Color(0xFF1A1A1A),
    secondaryTextColor: Color(0xFF757575),
    accentColor: Color(0xFF2196F3),
    borderColor: Color(0xFFE0E0E0),
    focusedItemColor: Color(0xFFE3F2FD),
    selectedItemColor: Color(0xFFBBDEFB),
  );

  static const FimaTheme dark = FimaTheme(
    name: 'Dark',
    backgroundColor: Color(0xFF1E1E1E),
    surfaceColor: Color(0xFF252525),
    textColor: Color(0xFFE0E0E0),
    secondaryTextColor: Color(0xFF9E9E9E),
    accentColor: Color(0xFF64B5F6),
    borderColor: Color(0xFF424242),
    focusedItemColor: Color(0xFF333333),
    selectedItemColor: Color(0xFF1E3A5F),
  );

  static const FimaTheme nightOwl = FimaTheme(
    name: 'NightOwl',
    backgroundColor: Color(0xFF011627),
    surfaceColor: Color(0xFF0B2942),
    textColor: Color(0xFFD6DEEB),
    secondaryTextColor: Color(0xFF89A4BB),
    accentColor: Color(0xFF7E57C2),
    borderColor: Color(0xFF5F7E97),
    focusedItemColor: Color(0xFF234D70),
    selectedItemColor: Color(0xFF1D3B53),
  );

  static List<FimaTheme> get all => [light, dark, nightOwl];

  static FimaTheme getByName(String name) {
    return all.firstWhere((theme) => theme.name == name, orElse: () => light);
  }
}
