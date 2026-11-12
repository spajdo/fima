import 'package:fima/domain/entity/bookmark.dart';
import 'package:fima/domain/entity/key_map_action.dart';
import 'package:fima/domain/entity/panel_tab.dart';
import 'package:fima/domain/entity/path_index_entry.dart';
import 'package:fima/domain/entity/remote_connection.dart';
import 'package:fima/domain/entity/workspace.dart';

class UserSettings {
  final List<PanelTab> leftTabs;
  final int leftActiveTabIndex;
  final List<PanelTab> rightTabs;
  final int rightActiveTabIndex;
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
  final List<Bookmark> bookmarks;
  final String themeName;
  final Map<String, String> keyMap;
  final bool useBuiltInTerminal;
  final List<RemoteConnection> remoteConnections;
  final bool showWalkthroughOnStartup;

  const UserSettings({
    required this.leftTabs,
    this.leftActiveTabIndex = 0,
    required this.rightTabs,
    this.rightActiveTabIndex = 0,
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
    this.bookmarks = const [],
    this.themeName = 'Light',
    this.keyMap = const {},
    this.useBuiltInTerminal = false,
    this.remoteConnections = const [],
    this.showWalkthroughOnStartup = true,
  });

  PanelTab get activeLeftTab {
    if (leftTabs.isEmpty) return const PanelTab(id: 'left_fallback');
    return leftTabs[leftActiveTabIndex.clamp(0, leftTabs.length - 1)];
  }

  PanelTab get activeRightTab {
    if (rightTabs.isEmpty) return const PanelTab(id: 'right_fallback');
    return rightTabs[rightActiveTabIndex.clamp(0, rightTabs.length - 1)];
  }

  String get leftPanelPath => activeLeftTab.path;
  String get rightPanelPath => activeRightTab.path;
  int get leftPanelSortColumn => activeLeftTab.sortColumn;
  bool get leftPanelSortAscending => activeLeftTab.sortAscending;
  int get rightPanelSortColumn => activeRightTab.sortColumn;
  bool get rightPanelSortAscending => activeRightTab.sortAscending;

  /// Returns `true` when [json] is in a legacy format that should be migrated
  /// and persisted in the current tab-based schema.
  static bool needsMigration(Map<String, dynamic> json) {
    if (!json.containsKey('leftTabs') || !json.containsKey('rightTabs')) {
      return true;
    }

    final rawWorkspaces = json['workspaces'];
    if (rawWorkspaces is List) {
      for (final item in rawWorkspaces) {
        if (item is Map<String, dynamic> && Workspace.isLegacyJson(item)) {
          return true;
        }
      }
    }

    final rawKeyMap = json['keyMap'];
    if (rawKeyMap is Map<String, dynamic>) {
      final wsShortcut = rawKeyMap['workspaceDialog'] as String?;
      if (wsShortcut != null &&
          (KeyMapActionDefs.shortcutsMatch(wsShortcut, 'Ctrl+W') ||
              KeyMapActionDefs.shortcutsMatch(wsShortcut, '⌘ + W'))) {
        return true;
      }
    }

    return false;
  }

  factory UserSettings.defaultSettings() {
    return UserSettings(
      leftTabs: [PanelTab.create(path: '')],
      leftActiveTabIndex: 0,
      rightTabs: [PanelTab.create(path: '')],
      rightActiveTabIndex: 0,
      panelSplitRatio: 0.5,
      fontSize: 14.0,
      showHiddenFiles: false,
      windowWidth: 1280.0,
      windowHeight: 720.0,
      windowX: null,
      windowY: null,
      windowMaximized: false,
      pathIndexes: const [],
      maxPathIndexes: 50,
      workspaces: const [],
      bookmarks: const [],
      themeName: 'Light',
      keyMap: const {},
      useBuiltInTerminal: false,
      remoteConnections: const [],
      showWalkthroughOnStartup: true,
    );
  }

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    List<PanelTab> parsePanelTabs({
      required dynamic rawTabs,
      required String legacyPath,
      required int legacySortCol,
      required bool legacySortAsc,
    }) {
      if (rawTabs is List && rawTabs.isNotEmpty) {
        return rawTabs
            .map((e) => PanelTab.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [
        PanelTab.create(
          path: legacyPath,
          sortColumn: legacySortCol,
          sortAscending: legacySortAsc,
        ),
      ];
    }

    final leftTabs = parsePanelTabs(
      rawTabs: json['leftTabs'],
      legacyPath: json['leftPanelPath'] as String? ?? '',
      legacySortCol: json['leftPanelSortColumn'] as int? ?? 0,
      legacySortAsc: json['leftPanelSortAscending'] as bool? ?? true,
    );
    final rightTabs = parsePanelTabs(
      rawTabs: json['rightTabs'],
      legacyPath: json['rightPanelPath'] as String? ?? '',
      legacySortCol: json['rightPanelSortColumn'] as int? ?? 0,
      legacySortAsc: json['rightPanelSortAscending'] as bool? ?? true,
    );

    final rawLeftIdx = json['leftActiveTabIndex'] as int? ?? 0;
    final rawRightIdx = json['rightActiveTabIndex'] as int? ?? 0;

    final parsedKeyMap =
        (json['keyMap'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, value as String),
        ) ??
        <String, String>{};

    // Migrate old workspaceDialog shortcut if it conflicts with closeTab.
    final wsShortcut = parsedKeyMap['workspaceDialog'];
    if (wsShortcut != null &&
        (KeyMapActionDefs.shortcutsMatch(wsShortcut, 'Ctrl+W') ||
            KeyMapActionDefs.shortcutsMatch(wsShortcut, '⌘ + W'))) {
      parsedKeyMap.remove('workspaceDialog');
    }

    return UserSettings(
      leftTabs: leftTabs,
      leftActiveTabIndex: rawLeftIdx.clamp(0, leftTabs.length - 1),
      rightTabs: rightTabs,
      rightActiveTabIndex: rawRightIdx.clamp(0, rightTabs.length - 1),
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
      bookmarks: (json['bookmarks'] as List? ?? [])
          .map((e) => Bookmark.fromJson(e as Map<String, dynamic>))
          .toList(),
      themeName: json['themeName'] as String? ?? 'Light',
      keyMap: parsedKeyMap,
      useBuiltInTerminal: json['useBuiltInTerminal'] as bool? ?? false,
      remoteConnections: (json['remoteConnections'] as List? ?? [])
          .map((e) => RemoteConnection.fromJson(e as Map<String, dynamic>))
          .toList(),
      showWalkthroughOnStartup:
          json['showWalkthroughOnStartup'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'leftTabs': leftTabs.map((t) => t.toJson()).toList(),
      'leftActiveTabIndex': leftActiveTabIndex,
      'rightTabs': rightTabs.map((t) => t.toJson()).toList(),
      'rightActiveTabIndex': rightActiveTabIndex,
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
      'bookmarks': bookmarks.map((e) => e.toJson()).toList(),
      'themeName': themeName,
      'keyMap': keyMap,
      'useBuiltInTerminal': useBuiltInTerminal,
      'remoteConnections': remoteConnections.map((e) => e.toJson()).toList(),
      'showWalkthroughOnStartup': showWalkthroughOnStartup,
    };
  }

  UserSettings copyWith({
    List<PanelTab>? leftTabs,
    int? leftActiveTabIndex,
    List<PanelTab>? rightTabs,
    int? rightActiveTabIndex,
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
    List<Bookmark>? bookmarks,
    String? themeName,
    Map<String, String>? keyMap,
    bool? useBuiltInTerminal,
    List<RemoteConnection>? remoteConnections,
    bool? showWalkthroughOnStartup,
  }) {
    return UserSettings(
      leftTabs: leftTabs ?? this.leftTabs,
      leftActiveTabIndex: leftActiveTabIndex ?? this.leftActiveTabIndex,
      rightTabs: rightTabs ?? this.rightTabs,
      rightActiveTabIndex: rightActiveTabIndex ?? this.rightActiveTabIndex,
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
      bookmarks: bookmarks ?? this.bookmarks,
      themeName: themeName ?? this.themeName,
      keyMap: keyMap ?? this.keyMap,
      useBuiltInTerminal: useBuiltInTerminal ?? this.useBuiltInTerminal,
      remoteConnections: remoteConnections ?? this.remoteConnections,
      showWalkthroughOnStartup:
          showWalkthroughOnStartup ?? this.showWalkthroughOnStartup,
    );
  }
}
