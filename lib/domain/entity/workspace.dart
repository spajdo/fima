class Workspace {
  final String name;
  final String leftPanelPath;
  final String rightPanelPath;

  const Workspace({
    required this.name,
    required this.leftPanelPath,
    required this.rightPanelPath,
  });

  factory Workspace.fromJson(Map<String, dynamic> json) {
    return Workspace(
      name: json['name'] as String,
      leftPanelPath: json['leftPanelPath'] as String,
      rightPanelPath: json['rightPanelPath'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'leftPanelPath': leftPanelPath,
      'rightPanelPath': rightPanelPath,
    };
  }

  Workspace copyWith({
    String? name,
    String? leftPanelPath,
    String? rightPanelPath,
  }) {
    return Workspace(
      name: name ?? this.name,
      leftPanelPath: leftPanelPath ?? this.leftPanelPath,
      rightPanelPath: rightPanelPath ?? this.rightPanelPath,
    );
  }
}
