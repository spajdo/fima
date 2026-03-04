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

  // ── Popular IDE / editor themes ────────────────────────────────────────────

  /// Monokai – classic dark theme from Sublime Text, widely used in VS Code.
  static const FimaTheme monokai = FimaTheme(
    name: 'Monokai',
    backgroundColor: Color(0xFF272822),
    surfaceColor: Color(0xFF3E3D32),
    textColor: Color(0xFFF8F8F2),
    secondaryTextColor: Color(0xFF75715E),
    accentColor: Color(0xFFA6E22E),
    borderColor: Color(0xFF49483E),
    focusedItemColor: Color(0xFF3E3D32),
    selectedItemColor: Color(0xFF49483E),
  );

  /// Solarized Light – warm beige-toned light theme by Ethan Schoonover.
  static const FimaTheme solarizedLight = FimaTheme(
    name: 'Solarized Light',
    backgroundColor: Color(0xFFFDF6E3),
    surfaceColor: Color(0xFFEEE8D5),
    textColor: Color(0xFF657B83),
    secondaryTextColor: Color(0xFF93A1A1),
    accentColor: Color(0xFF268BD2),
    borderColor: Color(0xFFD3CBB6),
    focusedItemColor: Color(0xFFE8E2CF),
    selectedItemColor: Color(0xFFCDC9BB),
  );

  /// Solarized Dark – the dark complement to Solarized Light.
  static const FimaTheme solarizedDark = FimaTheme(
    name: 'Solarized Dark',
    backgroundColor: Color(0xFF002B36),
    surfaceColor: Color(0xFF073642),
    textColor: Color(0xFF839496),
    secondaryTextColor: Color(0xFF586E75),
    accentColor: Color(0xFF268BD2),
    borderColor: Color(0xFF094555),
    focusedItemColor: Color(0xFF0A4050),
    selectedItemColor: Color(0xFF08374A),
  );

  /// Dracula – vibrant purple dark theme popular in VS Code & JetBrains IDEs.
  static const FimaTheme dracula = FimaTheme(
    name: 'Dracula',
    backgroundColor: Color(0xFF282A36),
    surfaceColor: Color(0xFF343746),
    textColor: Color(0xFFF8F8F2),
    secondaryTextColor: Color(0xFF6272A4),
    accentColor: Color(0xFFBD93F9),
    borderColor: Color(0xFF44475A),
    focusedItemColor: Color(0xFF44475A),
    selectedItemColor: Color(0xFF3D4059),
  );

  /// Matrix – green-on-black terminal aesthetic.
  static const FimaTheme matrix = FimaTheme(
    name: 'Matrix',
    backgroundColor: Color(0xFF000000),
    surfaceColor: Color(0xFF0A1A0A),
    textColor: Color(0xFF00FF41),
    secondaryTextColor: Color(0xFF008F11),
    accentColor: Color(0xFF39FF14),
    borderColor: Color(0xFF003B00),
    focusedItemColor: Color(0xFF001A00),
    selectedItemColor: Color(0xFF002B00),
  );

  /// High Contrast – maximum contrast for accessibility.
  static const FimaTheme highContrast = FimaTheme(
    name: 'High Contrast',
    backgroundColor: Color(0xFF000000),
    surfaceColor: Color(0xFF0A0A0A),
    textColor: Color(0xFFFFFFFF),
    secondaryTextColor: Color(0xFFCCCCCC),
    accentColor: Color(0xFFFFFF00),
    borderColor: Color(0xFFFFFFFF),
    focusedItemColor: Color(0xFF1A1A1A),
    selectedItemColor: Color(0xFF003366),
  );

  /// One Dark Pro – the most popular VS Code theme by Binaryify.
  static const FimaTheme oneDarkPro = FimaTheme(
    name: 'One Dark Pro',
    backgroundColor: Color(0xFF282C34),
    surfaceColor: Color(0xFF21252B),
    textColor: Color(0xFFABB2BF),
    secondaryTextColor: Color(0xFF636D83),
    accentColor: Color(0xFF61AFEF),
    borderColor: Color(0xFF3E4451),
    focusedItemColor: Color(0xFF2C313A),
    selectedItemColor: Color(0xFF264F78),
  );

  /// GitHub Dark – VS Code GitHub Dark theme.
  static const FimaTheme githubDark = FimaTheme(
    name: 'GitHub Dark',
    backgroundColor: Color(0xFF0D1117),
    surfaceColor: Color(0xFF161B22),
    textColor: Color(0xFFE6EDF3),
    secondaryTextColor: Color(0xFF8B949E),
    accentColor: Color(0xFF58A6FF),
    borderColor: Color(0xFF30363D),
    focusedItemColor: Color(0xFF21262D),
    selectedItemColor: Color(0xFF1F3552),
  );

  /// Gruvbox Dark – retro warm dark theme popular in Vim/NeoVim communities.
  static const FimaTheme gruvboxDark = FimaTheme(
    name: 'Gruvbox Dark',
    backgroundColor: Color(0xFF282828),
    surfaceColor: Color(0xFF32302F),
    textColor: Color(0xFFEBDBB2),
    secondaryTextColor: Color(0xFFA89984),
    accentColor: Color(0xFFFABD2F),
    borderColor: Color(0xFF504945),
    focusedItemColor: Color(0xFF3C3836),
    selectedItemColor: Color(0xFF45403D),
  );

  /// Catppuccin Mocha – a soothing pastel dark theme, trending in 2024.
  static const FimaTheme catppuccinMocha = FimaTheme(
    name: 'Catppuccin Mocha',
    backgroundColor: Color(0xFF1E1E2E),
    surfaceColor: Color(0xFF181825),
    textColor: Color(0xFFCDD6F4),
    secondaryTextColor: Color(0xFF6C7086),
    accentColor: Color(0xFF89B4FA),
    borderColor: Color(0xFF313244),
    focusedItemColor: Color(0xFF313244),
    selectedItemColor: Color(0xFF45475A),
  );

  /// Tokyo Night – the dark blue VS Code theme inspired by Tokyo lights.
  static const FimaTheme tokyoNight = FimaTheme(
    name: 'Tokyo Night',
    backgroundColor: Color(0xFF1A1B26),
    surfaceColor: Color(0xFF16161E),
    textColor: Color(0xFFC0CAF5),
    secondaryTextColor: Color(0xFF565F89),
    accentColor: Color(0xFF7AA2F7),
    borderColor: Color(0xFF292E42),
    focusedItemColor: Color(0xFF1F2335),
    selectedItemColor: Color(0xFF283457),
  );

  /// Nord – an arctic, north-bluish color palette.
  static const FimaTheme nord = FimaTheme(
    name: 'Nord',
    backgroundColor: Color(0xFF2E3440),
    surfaceColor: Color(0xFF3B4252),
    textColor: Color(0xFFECEFF4),
    secondaryTextColor: Color(0xFF4C566A),
    accentColor: Color(0xFF88C0D0),
    borderColor: Color(0xFF434C5E),
    focusedItemColor: Color(0xFF3B4252),
    selectedItemColor: Color(0xFF4C566A),
  );

  // ── Registry ───────────────────────────────────────────────────────────────

  static List<FimaTheme> get all => [
    light,
    dark,
    catppuccinMocha,
    dracula,
    githubDark,
    gruvboxDark,
    highContrast,
    matrix,
    monokai,
    nightOwl,
    nord,
    oneDarkPro,
    solarizedDark,
    solarizedLight,
    tokyoNight,
  ];

  static FimaTheme getByName(String name) {
    return all.firstWhere((theme) => theme.name == name, orElse: () => light);
  }
}
