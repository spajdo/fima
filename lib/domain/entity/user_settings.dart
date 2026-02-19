import 'package:fima/domain/entity/path_index_entry.dart';
import 'package:fima/domain/entity/workspace.dart';

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
  final List<PathIndexEntry> pathIndexes;
  final int maxPathIndexes;
  final List<Workspace> workspaces;
  final String themeName;
  final Map<String, String> keyMap;

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
    this.pathIndexes = const [],
    this.maxPathIndexes = 50,
    this.workspaces = const [],
    this.themeName = 'Light',
    this.keyMap = const {},
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
      pathIndexes: [],
      maxPathIndexes: 50,
      workspaces: [],
      themeName: 'Light',
      keyMap: {},
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
      pathIndexes: (json['pathIndexes'] as List? ?? [])
          .map((e) => PathIndexEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      maxPathIndexes: json['maxPathIndexes'] as int? ?? 50,
      workspaces: (json['workspaces'] as List? ?? [])
          .map((e) => Workspace.fromJson(e as Map<String, dynamic>))
          .toList(),
      themeName: json['themeName'] as String? ?? 'Light',
      keyMap:
          (json['keyMap'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, value as String),
          ) ??
          {},
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
      'pathIndexes': pathIndexes.map((e) => e.toJson()).toList(),
      'maxPathIndexes': maxPathIndexes,
      'workspaces': workspaces.map((e) => e.toJson()).toList(),
      'themeName': themeName,
      'keyMap': keyMap,
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
    List<PathIndexEntry>? pathIndexes,
    int? maxPathIndexes,
    List<Workspace>? workspaces,
    String? themeName,
    Map<String, String>? keyMap,
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
      pathIndexes: pathIndexes ?? this.pathIndexes,
      maxPathIndexes: maxPathIndexes ?? this.maxPathIndexes,
      workspaces: workspaces ?? this.workspaces,
      themeName: themeName ?? this.themeName,
      keyMap: keyMap ?? this.keyMap,
    );
  }
}
