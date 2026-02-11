class UserSettings {
  final String leftPanelPath;
  final String rightPanelPath;
  final double panelSplitRatio;
  final double fontSize;
  final bool showHiddenFiles;

  const UserSettings({
    required this.leftPanelPath,
    required this.rightPanelPath,
    this.panelSplitRatio = 0.5,
    this.fontSize = 14.0,
    this.showHiddenFiles = false,
  });

  // Default settings
  factory UserSettings.defaultSettings() {
    return const UserSettings(
      leftPanelPath: '', // Empty means use home directory
      rightPanelPath: '',
      panelSplitRatio: 0.5,
      fontSize: 14.0,
      showHiddenFiles: false, // Hidden files are hidden by default
    );
  }

  // From JSON
  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      leftPanelPath: json['leftPanelPath'] as String? ?? '',
      rightPanelPath: json['rightPanelPath'] as String? ?? '',
      panelSplitRatio: (json['panelSplitRatio'] as num?)?.toDouble() ?? 0.5,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 14.0,
      showHiddenFiles: json['showHiddenFiles'] as bool? ?? false,
    );
  }

  // To JSON
  Map<String, dynamic> toJson() {
    return {
      'leftPanelPath': leftPanelPath,
      'rightPanelPath': rightPanelPath,
      'panelSplitRatio': panelSplitRatio,
      'fontSize': fontSize,
      'showHiddenFiles': showHiddenFiles,
    };
  }

  // CopyWith
  UserSettings copyWith({
    String? leftPanelPath,
    String? rightPanelPath,
    double? panelSplitRatio,
    double? fontSize,
    bool? showHiddenFiles,
  }) {
    return UserSettings(
      leftPanelPath: leftPanelPath ?? this.leftPanelPath,
      rightPanelPath: rightPanelPath ?? this.rightPanelPath,
      panelSplitRatio: panelSplitRatio ?? this.panelSplitRatio,
      fontSize: fontSize ?? this.fontSize,
      showHiddenFiles: showHiddenFiles ?? this.showHiddenFiles,
    );
  }
}
