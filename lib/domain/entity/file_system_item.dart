class FileSystemItem {
  final String path;
  final String name;
  final int size;
  final DateTime modified;
  final bool isDirectory;
  final bool isParentDetails;

  const FileSystemItem({
    required this.path,
    required this.name,
    required this.size,
    required this.modified,
    required this.isDirectory,
    this.isParentDetails = false,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FileSystemItem &&
        other.path == path &&
        other.name == name &&
        other.size == size &&
        other.modified == modified &&
        other.isDirectory == isDirectory &&
        other.isParentDetails == isParentDetails;
  }

  @override
  int get hashCode {
    return Object.hash(path, name, size, modified, isDirectory, isParentDetails);
  }
}
