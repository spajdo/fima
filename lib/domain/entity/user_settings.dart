class UserSettings {
  final String leftPanelPath;
  final String rightPanelPath;
  final double panelSplitRatio;

  const UserSettings({
    required this.leftPanelPath,
    required this.rightPanelPath,
    this.panelSplitRatio = 0.5,
  });

  // Default settings
  factory UserSettings.defaultSettings() {
    return const UserSettings(
      leftPanelPath: '',  // Empty means use home directory
      rightPanelPath: '',
      panelSplitRatio: 0.5,
    );
  }

  // From JSON
  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      leftPanelPath: json['leftPanelPath'] as String? ?? '',
      rightPanelPath: json['rightPanelPath'] as String? ?? '',
      panelSplitRatio: (json['panelSplitRatio'] as num?)?.toDouble() ?? 0.5,
    );
  }

  // To JSON
  Map<String, dynamic> toJson() {
    return {
      'leftPanelPath': leftPanelPath,
      'rightPanelPath': rightPanelPath,
      'panelSplitRatio': panelSplitRatio,
    };
  }

  // CopyWith
  UserSettings copyWith({
    String? leftPanelPath,
    String? rightPanelPath,
    double? panelSplitRatio,
  }) {
    return UserSettings(
      leftPanelPath: leftPanelPath ?? this.leftPanelPath,
      rightPanelPath: rightPanelPath ?? this.rightPanelPath,
      panelSplitRatio: panelSplitRatio ?? this.panelSplitRatio,
    );
  }
}
