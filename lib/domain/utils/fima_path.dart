import 'dart:io';

import 'package:fima/domain/entity/remote_connection.dart';
import 'package:path/path.dart' as p;

/// Path helpers that handle local paths, `ssh://` URLs, and `.zip` archive
/// virtual paths consistently across platforms.
class FimaPath {
  const FimaPath._();

  static bool isSshPath(String path) => path.startsWith('ssh://');

  static bool isZipPath(String path) => extractZipParts(path) != null;

  /// Splits [path] into `(zipFilePath, innerPath)` when [path] points to a
  /// `.zip` file or an entry inside one, or returns `null` otherwise.
  static (String zipFilePath, String innerPath)? extractZipParts(String path) {
    if (path.isEmpty || isSshPath(path)) return null;

    final lowerPath = path.toLowerCase();
    final zipIndex = lowerPath.indexOf('.zip');
    if (zipIndex == -1) return null;

    final endIndex = zipIndex + 4;
    if (endIndex == path.length ||
        path[endIndex] == Platform.pathSeparator ||
        path[endIndex] == '/') {
      final zipFilePath = path.substring(0, endIndex);
      var innerPath = '';
      if (endIndex < path.length) {
        innerPath = path
            .substring(endIndex + 1)
            .replaceAll(Platform.pathSeparator, '/');
      }
      return (zipFilePath, innerPath);
    }
    return null;
  }

  static String join(String base, String name) {
    if (isSshPath(base)) {
      final connId = RemoteConnection.connectionIdFromSshUrl(base);
      final remoteBase = RemoteConnection.remotePathFromSshUrl(base);
      final cleanBase = remoteBase.endsWith('/') ? remoteBase : '$remoteBase/';
      final cleanName = name.startsWith('/') ? name.substring(1) : name;
      return 'ssh://$connId$cleanBase$cleanName';
    }
    return p.join(base, name);
  }

  static String dirname(String path) {
    if (isSshPath(path)) {
      final connId = RemoteConnection.connectionIdFromSshUrl(path);
      final remotePath = RemoteConnection.remotePathFromSshUrl(path);
      if (remotePath == '/' || remotePath.isEmpty) {
        return 'ssh://$connId/';
      }
      final parent = p.posix.dirname(remotePath);
      final cleanParent = parent.startsWith('/') ? parent : '/$parent';
      return 'ssh://$connId$cleanParent';
    }
    return p.dirname(path);
  }

  static String basename(String path) {
    if (isSshPath(path)) {
      final remotePath = RemoteConnection.remotePathFromSshUrl(path);
      if (remotePath == '/' || remotePath.isEmpty) return '';
      return p.posix.basename(remotePath);
    }
    return p.basename(path);
  }

  /// Returns `true` if [targetPath] resolves strictly inside [rootDir]
  /// (used to prevent Zip Slip traversal and copying a folder into itself).
  static bool isStrictlyWithin(String rootDir, String targetPath) {
    final normalizedRoot = p.normalize(p.absolute(rootDir));
    final normalizedTarget = p.normalize(p.absolute(targetPath));
    return p.isWithin(normalizedRoot, normalizedTarget);
  }

  /// Returns `true` if [targetPath] is equal to or inside [rootDir].
  static bool isSameOrWithin(String rootDir, String targetPath) {
    final normalizedRoot = p.normalize(p.absolute(rootDir));
    final normalizedTarget = p.normalize(p.absolute(targetPath));
    return p.equals(normalizedRoot, normalizedTarget) ||
        p.isWithin(normalizedRoot, normalizedTarget);
  }
}
