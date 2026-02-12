class PathIndexEntry {
  final String path;
  final int visitsCount;
  final DateTime lastVisited;

  const PathIndexEntry({
    required this.path,
    required this.visitsCount,
    required this.lastVisited,
  });

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'visitsCount': visitsCount,
      'lastVisited': lastVisited.toIso8601String(),
    };
  }

  factory PathIndexEntry.fromJson(Map<String, dynamic> json) {
    return PathIndexEntry(
      path: json['path'] as String,
      visitsCount: json['visitsCount'] as int,
      lastVisited: DateTime.parse(json['lastVisited'] as String),
    );
  }

  PathIndexEntry copyWith({
    String? path,
    int? visitsCount,
    DateTime? lastVisited,
  }) {
    return PathIndexEntry(
      path: path ?? this.path,
      visitsCount: visitsCount ?? this.visitsCount,
      lastVisited: lastVisited ?? this.lastVisited,
    );
  }
}
