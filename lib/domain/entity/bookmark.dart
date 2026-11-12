class Bookmark {
  final String name;
  final String path;

  const Bookmark({required this.name, required this.path});

  factory Bookmark.fromJson(Map<String, dynamic> json) {
    return Bookmark(
      name: json['name'] as String? ?? '',
      path: json['path'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'path': path};
  }

  Bookmark copyWith({String? name, String? path}) {
    return Bookmark(name: name ?? this.name, path: path ?? this.path);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Bookmark && other.name == name && other.path == path;
  }

  @override
  int get hashCode => Object.hash(name, path);
}

