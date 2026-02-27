import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:fima/domain/entity/file_operation.dart';
import 'package:fima/domain/entity/file_system_item.dart';
import 'package:fima/domain/entity/remote_connection.dart';
import 'package:fima/domain/repository/file_system_repository.dart';
import 'package:fima/infrastructure/service/ssh_file_tail_service.dart';
import 'package:flutter/foundation.dart';

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

  @override
  Future<void> copyItem(String sourcePath, String destinationPath) async {
    final connId = _connectionId(sourcePath);
    final srcRemote = _remotePath(sourcePath);
    final dstRemote = _remotePath(destinationPath);
    final session = _getSession(connId);
    if (session == null) throw StateError('Not connected: $connId');
    final data = await _downloadBytes(session.sftp, srcRemote);
    await _uploadBytes(session.sftp, dstRemote, data);
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
      final remoteName = _remotePath(src).split('/').last;
      final connIdSrc = _connectionId(src);
      final connIdDst = _connectionId(destinationPath);

      if (connIdSrc == connIdDst) {
        final dstRemote = '${_remotePath(destinationPath)}/$remoteName';
        final session = _getSession(connIdSrc)!;
        try {
          final data = await _downloadBytes(session.sftp, _remotePath(src));
          await _uploadBytes(session.sftp, dstRemote, data);
        } catch (e) {
          debugPrint('SSH copy error: $e');
        }
      } else {
        debugPrint('Cross-server copy not yet supported');
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
      final remoteName = _remotePath(src).split('/').last;
      final dstUrl = _buildUrl(
        _connectionId(src),
        '${_remotePath(destinationPath)}/$remoteName',
      );
      try {
        await renameItem(src, dstUrl);
      } catch (e) {
        debugPrint('SSH move error: $e');
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

  Future<Uint8List> _downloadBytes(SftpClient sftp, String remotePath) async {
    final file = await sftp.open(remotePath, mode: SftpFileOpenMode.read);
    final chunks = <int>[];
    await for (final chunk in file.read()) {
      chunks.addAll(chunk);
    }
    await file.close();
    return Uint8List.fromList(chunks);
  }

  Future<void> _uploadBytes(
    SftpClient sftp,
    String remotePath,
    Uint8List data,
  ) async {
    final file = await sftp.open(
      remotePath,
      mode: SftpFileOpenMode.create | SftpFileOpenMode.write,
    );
    await file.write(Stream.value(data));
    await file.close();
  }

  /// Downloads a file from SSH to local filesystem.
  Future<int> downloadToLocal(String sshPath, String localPath) async {
    final connId = _connectionId(sshPath);
    final remotePath = _remotePath(sshPath);
    final sftp = _getSession(connId)!.sftp;
    final data = await _downloadBytes(sftp, remotePath);
    await File(localPath).writeAsBytes(data);
    return data.length; // Return bytes written so caller knows initial size.
  }

  /// Uploads a local file to the SSH server.
  Future<void> uploadFromLocal(String localPath, String sshPath) async {
    final data = await File(localPath).readAsBytes();
    await _uploadBytes(
      _getSession(_connectionId(sshPath))!.sftp,
      _remotePath(sshPath),
      data,
    );
  }
}
