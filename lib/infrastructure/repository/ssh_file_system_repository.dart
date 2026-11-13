import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:fima/domain/entity/file_operation.dart';
import 'package:fima/domain/entity/file_system_item.dart';
import 'package:fima/domain/entity/remote_connection.dart';
import 'package:fima/domain/repository/file_system_repository.dart';
import 'package:fima/domain/utils/fima_path.dart';
import 'package:fima/infrastructure/service/ssh_file_tail_service.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// An active SSH session (client + SFTP client).
class _SshSession {
  final SSHClient client;
  final SftpClient sftp;

  _SshSession(this.client, this.sftp);

  Future<void> close() async {
    sftp.close();
    client.close();
  }
}

/// FileSystemRepository that talks to a remote server via SSH/SFTP.
/// Paths are expected in the format: ssh://connectionId/remotePath
class SshFileSystemRepository implements FileSystemRepository {
  // Active sessions keyed by connectionId.
  final Map<String, _SshSession> _sessions = {};

  /// Shared tail service for all SSH sessions.
  final tailService = SshFileTailService();

  /// Pre-connect to the server and store the session.
  Future<void> connect(RemoteConnection connection, String password) async {
    // Close stale session if exists.
    await disconnect(connection.id);

    final socket = await SSHSocket.connect(connection.host, connection.port);
    final client = SSHClient(
      socket,
      username: connection.username,
      onPasswordRequest: () => password,
    );

    // Wait for authentication to complete.
    await client.authenticated;

    final sftp = await client.sftp();
    _sessions[connection.id] = _SshSession(client, sftp);
  }

  Future<void> disconnect(String connectionId) async {
    tailService.stopAllForConnection(connectionId);
    final session = _sessions.remove(connectionId);
    await session?.close();
  }

  Future<void> disconnectAll() async {
    for (final session in _sessions.values) {
      await session.close();
    }
    _sessions.clear();
  }

  bool isConnected(String connectionId) => _sessions.containsKey(connectionId);

  _SshSession? _getSession(String connectionId) => _sessions[connectionId];

  /// Returns the SftpClient for a given connection (used by tail service).
  SftpClient? getSftpClientFor(String connectionId) =>
      _sessions[connectionId]?.sftp;

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _remotePath(String sshUrl) =>
      RemoteConnection.remotePathFromSshUrl(sshUrl);

  String _connectionId(String sshUrl) =>
      RemoteConnection.connectionIdFromSshUrl(sshUrl);

  /// Builds an ssh:// URL from a connection ID and a remote path.
  String _buildUrl(String connectionId, String remotePath) {
    final clean = remotePath.startsWith('/') ? remotePath : '/$remotePath';
    return 'ssh://$connectionId$clean';
  }

  String _sftpParent(String path) {
    if (path == '/') return '/';
    final parts = path.split('/');
    parts.removeLast();
    if (parts.isEmpty || (parts.length == 1 && parts[0].isEmpty)) return '/';
    return parts.join('/');
  }

  // ── FileSystemRepository impl ─────────────────────────────────────────────

  @override
  Future<List<FileSystemItem>> getItems(
    String path, {
    bool showHiddenFiles = false,
  }) async {
    final connId = _connectionId(path);
    final remotePath = _remotePath(path);
    final session = _getSession(connId);
    if (session == null) throw StateError('Not connected: $connId');

    final sftp = session.sftp;
    final entries = await sftp.listdir(remotePath);

    final items = <FileSystemItem>[];

    // Add parent directory if not at root.
    if (remotePath != '/') {
      final parentPath = _sftpParent(remotePath);
      items.add(
        FileSystemItem(
          path: _buildUrl(connId, parentPath),
          name: '..',
          size: 0,
          modified: DateTime.now(),
          isDirectory: true,
          isParentDetails: true,
        ),
      );
    }

    for (final entry in entries) {
      final name = entry.filename;
      if (name == '.' || name == '..') continue;
      if (!showHiddenFiles && name.startsWith('.')) continue;

      final attrs = entry.attr;
      final isDir = attrs.isDirectory;
      final size = attrs.size?.toInt() ?? 0;
      final modifiedMs = attrs.modifyTime;
      final modified = modifiedMs != null
          ? DateTime.fromMillisecondsSinceEpoch(modifiedMs * 1000)
          : DateTime.now();

      final childRemotePath = remotePath == '/'
          ? '/$name'
          : '$remotePath/$name';

      items.add(
        FileSystemItem(
          path: _buildUrl(connId, childRemotePath),
          name: name,
          size: isDir ? 0 : size,
          modified: modified,
          isDirectory: isDir,
        ),
      );
    }

    return items;
  }

  @override
  Future<String> getHomeDirectory() async {
    return '/';
  }

  @override
  Future<void> deleteItem(String path) async {
    final connId = _connectionId(path);
    final remotePath = _remotePath(path);
    final session = _getSession(connId);
    if (session == null) throw StateError('Not connected: $connId');
    await _deleteRemote(session.sftp, remotePath);
  }

  /// Recursively deletes a remote file or directory.
  Future<void> _deleteRemote(SftpClient sftp, String remotePath) async {
    SftpFileAttrs? attrs;
    try {
      attrs = await sftp.stat(remotePath);
    } catch (_) {
      // If stat fails, try direct remove.
      await sftp.remove(remotePath);
      return;
    }

    if (attrs.isDirectory) {
      // List and recursively delete children.
      final entries = await sftp.listdir(remotePath);
      for (final entry in entries) {
        final name = entry.filename;
        if (name == '.' || name == '..') continue;
        final childPath = remotePath == '/' ? '/$name' : '$remotePath/$name';
        await _deleteRemote(sftp, childPath);
      }
      await sftp.rmdir(remotePath);
    } else {
      await sftp.remove(remotePath);
    }
  }

  @override
  Future<void> createDirectory(String path) async {
    final connId = _connectionId(path);
    final remotePath = _remotePath(path);
    final session = _getSession(connId);
    if (session == null) throw StateError('Not connected: $connId');
    await session.sftp.mkdir(remotePath);
  }

  @override
  Future<void> createFile(String path) async {
    final connId = _connectionId(path);
    final remotePath = _remotePath(path);
    final session = _getSession(connId);
    if (session == null) throw StateError('Not connected: $connId');
    final file = await session.sftp.open(
      remotePath,
      mode: SftpFileOpenMode.create | SftpFileOpenMode.write,
    );
    await file.close();
  }

  @override
  Future<void> renameItem(String oldPath, String newPath) async {
    final connId = _connectionId(oldPath);
    final oldRemote = _remotePath(oldPath);
    final newRemote = _remotePath(newPath);
    final session = _getSession(connId);
    if (session == null) throw StateError('Not connected: $connId');
    await session.sftp.rename(oldRemote, newRemote);
  }

  String _joinRemote(String remoteDir, String name) {
    final cleanName = name.startsWith('/') ? name.substring(1) : name;
    return p.posix.join(remoteDir, cleanName);
  }

  Future<void> _copyRemoteRecursive(
    SftpClient sftp,
    String srcRemote,
    String dstRemote,
  ) async {
    final normalizedSrc = p.posix.normalize(srcRemote);
    final normalizedDst = p.posix.normalize(dstRemote);
    if (normalizedSrc == normalizedDst ||
        p.posix.isWithin(normalizedSrc, normalizedDst)) {
      throw FileSystemException(
        'Cannot copy remote item onto itself or into its own subdirectory',
        srcRemote,
      );
    }

    final attrs = await sftp.stat(srcRemote);
    if (attrs.isDirectory) {
      try {
        await sftp.mkdir(dstRemote);
      } catch (_) {
        // Directory may already exist
      }
      final entries = await sftp.listdir(srcRemote);
      for (final entry in entries) {
        final name = entry.filename;
        if (name == '.' || name == '..') continue;
        await _copyRemoteRecursive(
          sftp,
          _joinRemote(srcRemote, name),
          _joinRemote(dstRemote, name),
        );
      }
      return;
    }

    final srcFile = await sftp.open(srcRemote, mode: SftpFileOpenMode.read);
    final dstFile = await sftp.open(
      dstRemote,
      mode:
          SftpFileOpenMode.create |
          SftpFileOpenMode.write |
          SftpFileOpenMode.truncate,
    );
    try {
      await dstFile.write(srcFile.read());
    } finally {
      await srcFile.close();
      await dstFile.close();
    }
  }

  @override
  Future<void> copyItem(String sourcePath, String destinationPath) async {
    final connId = _connectionId(sourcePath);
    final srcRemote = _remotePath(sourcePath);
    final dstRemote = _remotePath(destinationPath);
    final session = _getSession(connId);
    if (session == null) throw StateError('Not connected: $connId');
    await _copyRemoteRecursive(session.sftp, srcRemote, dstRemote);
  }

  @override
  Future<void> moveItem(String sourcePath, String destinationPath) async {
    await renameItem(sourcePath, destinationPath);
  }

  @override
  Future<void> moveToTrash(String path) async {
    // Remote FS doesn't have a trash; permanent delete.
    await deleteItem(path);
  }

  @override
  Stream<OperationStatus> copyItems(
    List<String> sourcePaths,
    String destinationPath,
    CancellationToken token,
  ) async* {
    final total = sourcePaths.length;
    int done = 0;

    for (final src in sourcePaths) {
      if (token.isCancelled) return;
      final remoteName = FimaPath.basename(src);
      final connIdSrc = _connectionId(src);
      final connIdDst = _connectionId(destinationPath);

      if (connIdSrc != connIdDst) {
        throw UnsupportedError('Cross-server SSH copy is not supported');
      }

      final session = _getSession(connIdSrc);
      if (session == null) throw StateError('Not connected: $connIdSrc');

      final srcRemote = _remotePath(src);
      final dstRemote = _joinRemote(_remotePath(destinationPath), remoteName);
      await _copyRemoteRecursive(session.sftp, srcRemote, dstRemote);

      done++;
      yield OperationStatus(
        totalBytes: 0,
        processedBytes: 0,
        totalItems: total,
        processedItems: done,
        currentItem: remoteName,
      );
    }
  }

  @override
  Stream<OperationStatus> moveItems(
    List<String> sourcePaths,
    String destinationPath,
    CancellationToken token,
  ) async* {
    final total = sourcePaths.length;
    int done = 0;

    for (final src in sourcePaths) {
      if (token.isCancelled) return;
      final remoteName = FimaPath.basename(src);
      final dstUrl = FimaPath.join(destinationPath, remoteName);
      final srcRemote = p.posix.normalize(_remotePath(src));
      final dstRemote = p.posix.normalize(_remotePath(dstUrl));
      if (p.posix.isWithin(srcRemote, dstRemote)) {
        throw FileSystemException(
          'Cannot move remote directory into its own subdirectory',
          src,
        );
      }
      if (srcRemote != dstRemote) {
        await renameItem(src, dstUrl);
      }
      done++;
      yield OperationStatus(
        totalBytes: 0,
        processedBytes: 0,
        totalItems: total,
        processedItems: done,
        currentItem: remoteName,
      );
    }
  }

  // ── Download / Upload helpers ───────────────────────────────────────────

  Future<int> _streamRemoteFileToLocal(
    SftpClient sftp,
    String remotePath,
    String localPath,
  ) async {
    await Directory(p.dirname(localPath)).create(recursive: true);
    final remoteFile = await sftp.open(remotePath, mode: SftpFileOpenMode.read);
    final localSink = File(localPath).openWrite();
    int totalBytes = 0;
    try {
      await for (final chunk in remoteFile.read()) {
        localSink.add(chunk);
        totalBytes += chunk.length;
      }
      await localSink.flush();
      return totalBytes;
    } finally {
      await localSink.close();
      await remoteFile.close();
    }
  }

  Future<void> _streamLocalFileToRemote(
    SftpClient sftp,
    String localPath,
    String remotePath,
  ) async {
    final remoteFile = await sftp.open(
      remotePath,
      mode:
          SftpFileOpenMode.create |
          SftpFileOpenMode.write |
          SftpFileOpenMode.truncate,
    );
    try {
      await remoteFile.write(
        File(localPath).openRead().map(Uint8List.fromList),
      );
    } finally {
      await remoteFile.close();
    }
  }

  /// Downloads a file from SSH to local filesystem.
  Future<int> downloadToLocal(String sshPath, String localPath) async {
    final connId = _connectionId(sshPath);
    final session = _getSession(connId);
    if (session == null) throw StateError('Not connected: $connId');
    return _streamRemoteFileToLocal(
      session.sftp,
      _remotePath(sshPath),
      localPath,
    );
  }

  /// Downloads a remote file or directory recursively to [localPath].
  Future<void> downloadEntryToLocal(String sshPath, String localPath) async {
    final connId = _connectionId(sshPath);
    final session = _getSession(connId);
    if (session == null) throw StateError('Not connected: $connId');
    await _downloadRemoteRecursive(
      session.sftp,
      _remotePath(sshPath),
      localPath,
    );
  }

  Future<void> _downloadRemoteRecursive(
    SftpClient sftp,
    String remotePath,
    String localPath,
  ) async {
    final attrs = await sftp.stat(remotePath);
    if (!attrs.isDirectory) {
      await _streamRemoteFileToLocal(sftp, remotePath, localPath);
      return;
    }

    await Directory(localPath).create(recursive: true);
    final entries = await sftp.listdir(remotePath);
    for (final entry in entries) {
      final name = entry.filename;
      if (name == '.' || name == '..') continue;
      await _downloadRemoteRecursive(
        sftp,
        _joinRemote(remotePath, name),
        p.join(localPath, name),
      );
    }
  }

  /// Uploads a local file to the SSH server.
  Future<void> uploadFromLocal(String localPath, String sshPath) async {
    final connId = _connectionId(sshPath);
    final session = _getSession(connId);
    if (session == null) throw StateError('Not connected: $connId');
    await _streamLocalFileToRemote(
      session.sftp,
      localPath,
      _remotePath(sshPath),
    );
  }

  /// Uploads a local file or directory recursively to [sshPath].
  Future<void> uploadLocalEntry(String localPath, String sshPath) async {
    final connId = _connectionId(sshPath);
    final session = _getSession(connId);
    if (session == null) throw StateError('Not connected: $connId');
    await _uploadLocalRecursive(session.sftp, localPath, _remotePath(sshPath));
  }

  Future<void> _uploadLocalRecursive(
    SftpClient sftp,
    String localPath,
    String remotePath,
  ) async {
    final type = await FileSystemEntity.type(localPath, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      try {
        await sftp.mkdir(remotePath);
      } catch (_) {
        // Directory may already exist
      }
      await for (final entity in Directory(
        localPath,
      ).list(recursive: false, followLinks: false)) {
        final name = p.basename(entity.path);
        await _uploadLocalRecursive(
          sftp,
          entity.path,
          _joinRemote(remotePath, name),
        );
      }
      return;
    }

    if (type == FileSystemEntityType.file) {
      await _streamLocalFileToRemote(sftp, localPath, remotePath);
    }
  }
}
