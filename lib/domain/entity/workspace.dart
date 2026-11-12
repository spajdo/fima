import 'package:fima/domain/entity/panel_tab.dart';

class Workspace {
  final String name;
  final List<PanelTab> leftTabs;
  final int leftActiveTabIndex;
  final List<PanelTab> rightTabs;
  final int rightActiveTabIndex;

  const Workspace({
    required this.name,
    required this.leftTabs,
    this.leftActiveTabIndex = 0,
    required this.rightTabs,
    this.rightActiveTabIndex = 0,
  });

  String get leftPanelPath {
    if (leftTabs.isEmpty) return '';
    final idx = leftActiveTabIndex.clamp(0, leftTabs.length - 1);
    return leftTabs[idx].path;
  }

  String get rightPanelPath {
    if (rightTabs.isEmpty) return '';
    final idx = rightActiveTabIndex.clamp(0, rightTabs.length - 1);
    return rightTabs[idx].path;
  }

  static bool isLegacyJson(Map<String, dynamic> json) {
    return !json.containsKey('leftTabs') || !json.containsKey('rightTabs');
  }

  factory Workspace.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? '';

    List<PanelTab> parseTabs(dynamic rawTabs, String? legacyPath) {
      if (rawTabs is List && rawTabs.isNotEmpty) {
        return rawTabs
            .map((e) => PanelTab.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [PanelTab.create(path: legacyPath ?? '')];
    }

    final leftTabs = parseTabs(
      json['leftTabs'],
      json['leftPanelPath'] as String?,
    );
    final rightTabs = parseTabs(
      json['rightTabs'],
      json['rightPanelPath'] as String?,
    );

    final rawLeftIdx = json['leftActiveTabIndex'] as int? ?? 0;
    final rawRightIdx = json['rightActiveTabIndex'] as int? ?? 0;

    return Workspace(
      name: name,
      leftTabs: leftTabs,
      leftActiveTabIndex: rawLeftIdx.clamp(0, leftTabs.length - 1),
      rightTabs: rightTabs,
      rightActiveTabIndex: rawRightIdx.clamp(0, rightTabs.length - 1),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'leftTabs': leftTabs.map((t) => t.toJson()).toList(),
      'leftActiveTabIndex': leftActiveTabIndex,
      'rightTabs': rightTabs.map((t) => t.toJson()).toList(),
      'rightActiveTabIndex': rightActiveTabIndex,
    };
  }

  Workspace copyWith({
    String? name,
    List<PanelTab>? leftTabs,
    int? leftActiveTabIndex,
    List<PanelTab>? rightTabs,
    int? rightActiveTabIndex,
  }) {
    return Workspace(
      name: name ?? this.name,
      leftTabs: leftTabs ?? this.leftTabs,
      leftActiveTabIndex: leftActiveTabIndex ?? this.leftActiveTabIndex,
      rightTabs: rightTabs ?? this.rightTabs,
      rightActiveTabIndex: rightActiveTabIndex ?? this.rightActiveTabIndex,
    );
  }
}
