import 'dart:async';
import 'dart:io';

import 'package:fima/domain/entity/remote_connection.dart';
import 'package:fima/domain/repository/file_system_repository.dart';
import 'package:fima/infrastructure/repository/compound_file_system_repository.dart';
import 'package:fima/infrastructure/service/desktop_integration_service.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Manages downloading remote SSH files to a local temporary mirror, tailing
/// remote appends, and uploading local edits back over SFTP.
class RemoteFileEditService {
  final DesktopIntegrationService _desktop;
  final Map<String, StreamSubscription<FileSystemEvent>> _watchers = {};

  RemoteFileEditService([DesktopIntegrationService? desktop])
    : _desktop = desktop ?? const DesktopIntegrationService();

  Future<void> openRemoteFileLocally(
    FileSystemRepository repository,
    String sshPath,
  ) async {
    if (repository is! CompoundFileSystemRepository) return;

    try {
      final connId = RemoteConnection.connectionIdFromSshUrl(sshPath);
      final remotePath = RemoteConnection.remotePathFromSshUrl(sshPath);
      final relativeRemote = remotePath.startsWith('/')
          ? remotePath.substring(1)
          : remotePath;

      final localPath = p.join(
        Directory.systemTemp.path,
        'fima_ssh',
        connId,
        relativeRemote,
      );
      final file = File(localPath);
      await file.parent.create(recursive: true);

      await _watchers[sshPath]?.cancel();
      _watchers.remove(sshPath);

      var currentSize = await repository.sshRepository.downloadToLocal(
        sshPath,
        localPath,
      );

      final sftp = repository.sshRepository.getSftpClientFor(connId);
      if (sftp == null) return;

      void startTailing() {
        repository.sshRepository.tailService.startTailing(
          sftp: sftp,
          sshPath: sshPath,
          remotePath: remotePath,
          localPath: localPath,
          initialSize: currentSize,
        );
      }

      startTailing();

      bool isUploading = false;
      _watchers[sshPath] = file.watch().listen((_) async {
        if (isUploading) return;
        await Future.delayed(const Duration(milliseconds: 100));

        try {
          isUploading = true;
          repository.sshRepository.tailService.stopTailing(sshPath);
          await repository.sshRepository.uploadFromLocal(localPath, sshPath);
          currentSize = await file.length();
          startTailing();
        } catch (e) {
          debugPrint('Error uploading edited file: $e');
        } finally {
          isUploading = false;
        }
      });

      await _desktop.openFile(localPath);
    } catch (e) {
      debugPrint('Error opening remote file locally: $e');
    }
  }

  void disposeForConnection(String connId) {
    final prefix = 'ssh://$connId';
    final keysToRemove = _watchers.keys
        .where((k) => k.startsWith(prefix))
        .toList();
    for (final k in keysToRemove) {
      _watchers[k]?.cancel();
      _watchers.remove(k);
    }
  }

  void dispose() {
    for (final watcher in _watchers.values) {
      watcher.cancel();
    }
    _watchers.clear();
  }
}
