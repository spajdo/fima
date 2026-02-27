import 'dart:math';

/// Represents a saved SSH remote server connection.
class RemoteConnection {
  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  // Password is NOT stored here; it lives in flutter_secure_storage.
  final bool rememberPassword;

  const RemoteConnection({
    required this.id,
    required this.name,
    required this.host,
    this.port = 22,
    required this.username,
    this.rememberPassword = false,
  });

  factory RemoteConnection.create({
    required String name,
    required String host,
    int port = 22,
    required String username,
    bool rememberPassword = false,
  }) {
    return RemoteConnection(
      id: _generateId(),
      name: name,
      host: host,
      port: port,
      username: username,
      rememberPassword: rememberPassword,
    );
  }

  static String _generateId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  factory RemoteConnection.fromJson(Map<String, dynamic> json) {
    return RemoteConnection(
      id: json['id'] as String,
      name: json['name'] as String,
      host: json['host'] as String,
      port: json['port'] as int? ?? 22,
      username: json['username'] as String,
      rememberPassword: json['rememberPassword'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'host': host,
      'port': port,
      'username': username,
      'rememberPassword': rememberPassword,
    };
  }

  RemoteConnection copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? username,
    bool? rememberPassword,
  }) {
    return RemoteConnection(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      rememberPassword: rememberPassword ?? this.rememberPassword,
    );
  }

  /// SSH path prefix used internally to identify SSH paths.
  /// Format: ssh://connectionId/remotePath
  String buildPath(String remotePath) {
    final cleanPath = remotePath.startsWith('/') ? remotePath : '/$remotePath';
    return 'ssh://$id$cleanPath';
  }

  /// Parses a path to extract remote path component from a ssh:// URL.
  static String remotePathFromSshUrl(String sshUrl) {
    final uri = Uri.tryParse(sshUrl);
    if (uri == null) return '/';
    return uri.path.isEmpty ? '/' : uri.path;
  }

  /// Extracts the connection ID from a ssh:// URL.
  static String connectionIdFromSshUrl(String sshUrl) {
    final uri = Uri.tryParse(sshUrl);
    return uri?.host ?? '';
  }
}
