class UserSettings {
  final String leftPanelPath;
  final String rightPanelPath;
  final double panelSplitRatio;
  final double fontSize;

  const UserSettings({
    required this.leftPanelPath,
    required this.rightPanelPath,
    this.panelSplitRatio = 0.5,
    this.fontSize = 14.0,
  });

  // Default settings
  factory UserSettings.defaultSettings() {
    return const UserSettings(
      leftPanelPath: '', // Empty means use home directory
      rightPanelPath: '',
      panelSplitRatio: 0.5,
      fontSize: 14.0,
    );
  }

  // From JSON
  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      leftPanelPath: json['leftPanelPath'] as String? ?? '',
      rightPanelPath: json['rightPanelPath'] as String? ?? '',
      panelSplitRatio: (json['panelSplitRatio'] as num?)?.toDouble() ?? 0.5,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 14.0,
    );
  }

  // To JSON
  Map<String, dynamic> toJson() {
    return {
      'leftPanelPath': leftPanelPath,
      'rightPanelPath': rightPanelPath,
      'panelSplitRatio': panelSplitRatio,
      'fontSize': fontSize,
    };
  }

  // CopyWith
  UserSettings copyWith({
    String? leftPanelPath,
    String? rightPanelPath,
    double? panelSplitRatio,
    double? fontSize,
  }) {
    return UserSettings(
      leftPanelPath: leftPanelPath ?? this.leftPanelPath,
      rightPanelPath: rightPanelPath ?? this.rightPanelPath,
      panelSplitRatio: panelSplitRatio ?? this.panelSplitRatio,
      fontSize: fontSize ?? this.fontSize,
    );
  }
}
