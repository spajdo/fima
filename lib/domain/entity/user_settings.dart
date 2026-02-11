class UserSettings {
  final String leftPanelPath;
  final String rightPanelPath;
  final double panelSplitRatio;
  final double fontSize;
  final bool showHiddenFiles;
  final double? windowWidth;
  final double? windowHeight;
  final double? windowX;
  final double? windowY;
  final bool windowMaximized;

  const UserSettings({
    required this.leftPanelPath,
    required this.rightPanelPath,
    this.panelSplitRatio = 0.5,
    this.fontSize = 14.0,
    this.showHiddenFiles = false,
    this.windowWidth,
    this.windowHeight,
    this.windowX,
    this.windowY,
    this.windowMaximized = false,
  });

  // Default settings
  factory UserSettings.defaultSettings() {
    return const UserSettings(
      leftPanelPath: '', // Empty means use home directory
      rightPanelPath: '',
      panelSplitRatio: 0.5,
      fontSize: 14.0,
      showHiddenFiles: false, // Hidden files are hidden by default
      windowWidth: 1280.0, // Default window width
      windowHeight: 720.0, // Default window height
      windowX: null, // Will be centered by system
      windowY: null, // Will be centered by system
      windowMaximized: false,
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
      windowWidth: (json['windowWidth'] as num?)?.toDouble(),
      windowHeight: (json['windowHeight'] as num?)?.toDouble(),
      windowX: (json['windowX'] as num?)?.toDouble(),
      windowY: (json['windowY'] as num?)?.toDouble(),
      windowMaximized: json['windowMaximized'] as bool? ?? false,
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
      'windowWidth': windowWidth,
      'windowHeight': windowHeight,
      'windowX': windowX,
      'windowY': windowY,
      'windowMaximized': windowMaximized,
    };
  }

  // CopyWith
  UserSettings copyWith({
    String? leftPanelPath,
    String? rightPanelPath,
    double? panelSplitRatio,
    double? fontSize,
    bool? showHiddenFiles,
    double? windowWidth,
    double? windowHeight,
    double? windowX,
    double? windowY,
    bool? windowMaximized,
  }) {
    return UserSettings(
      leftPanelPath: leftPanelPath ?? this.leftPanelPath,
      rightPanelPath: rightPanelPath ?? this.rightPanelPath,
      panelSplitRatio: panelSplitRatio ?? this.panelSplitRatio,
      fontSize: fontSize ?? this.fontSize,
      showHiddenFiles: showHiddenFiles ?? this.showHiddenFiles,
      windowWidth: windowWidth ?? this.windowWidth,
      windowHeight: windowHeight ?? this.windowHeight,
      windowX: windowX ?? this.windowX,
      windowY: windowY ?? this.windowY,
      windowMaximized: windowMaximized ?? this.windowMaximized,
    );
  }
}
