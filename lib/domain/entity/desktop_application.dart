class DesktopApplication {
  final String name;
  final String exec;
  final String icon;
  final String? comment;
  final String path;

  const DesktopApplication({
    required this.name,
    required this.exec,
    required this.icon,
    this.comment,
    required this.path,
  });
}
