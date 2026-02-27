import 'dart:io';

import 'package:fima/domain/entity/file_operation.dart';
import 'package:fima/domain/entity/file_system_item.dart';
import 'package:fima/domain/repository/file_system_repository.dart';
import 'package:fima/infrastructure/repository/ssh_file_system_repository.dart';
import 'package:fima/infrastructure/repository/zip_file_system_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class CompoundFileSystemRepository implements FileSystemRepository {
  final FileSystemRepository defaultRepository;
  final ZipFileSystemRepository zipRepository;
  final SshFileSystemRepository sshRepository;

  CompoundFileSystemRepository(this.defaultRepository)
    : zipRepository = ZipFileSystemRepository(defaultRepository),
      sshRepository = SshFileSystemRepository();

  bool _isSshPath(String path) => path.startsWith('ssh://');

  bool _isZipPath(String path) {
    final lowerPath = path.toLowerCase();
    final zipIndex = lowerPath.indexOf('.zip');
    if (zipIndex != -1) {
      int endIndex = zipIndex + 4;
      if (endIndex == path.length ||
          path[endIndex] == Platform.pathSeparator ||
          path[endIndex] == '/') {
        return true;
      }
    }
    return false;
  }

  FileSystemRepository _getRepositoryForPath(String path) {
    if (_isSshPath(path)) return sshRepository;
    if (_isZipPath(path)) return zipRepository;
    return defaultRepository;
  }

  @override
  Future<List<FileSystemItem>> getItems(
    String path, {
    bool showHiddenFiles = false,
  }) {
    return _getRepositoryForPath(
      path,
    ).getItems(path, showHiddenFiles: showHiddenFiles);
  }

  @override
  Future<String> getHomeDirectory() {
    return defaultRepository.getHomeDirectory();
  }

  @override
  Future<void> deleteItem(String path) {
    return _getRepositoryForPath(path).deleteItem(path);
  }

  @override
  Future<void> createDirectory(String path) {
    return _getRepositoryForPath(path).createDirectory(path);
  }

  @override
  Future<void> createFile(String path) {
    return _getRepositoryForPath(path).createFile(path);
  }

  @override
  Future<void> renameItem(String oldPath, String newPath) {
    return _getRepositoryForPath(oldPath).renameItem(oldPath, newPath);
  }

  @override
  Future<void> copyItem(String sourcePath, String destinationPath) {
    final srcIsSsh = _isSshPath(sourcePath);
    final dstIsSsh = _isSshPath(destinationPath);

    if (srcIsSsh && dstIsSsh) {
      return sshRepository.copyItem(sourcePath, destinationPath);
    } else if (srcIsSsh && !dstIsSsh) {
      // SSH → local: download to temp then move to destination
      return _downloadSshToLocal(sourcePath, destinationPath);
    } else if (!srcIsSsh && dstIsSsh) {
      // Local → SSH: upload the file
      return sshRepository.uploadFromLocal(sourcePath, destinationPath);
    } else {
      return defaultRepository.copyItem(sourcePath, destinationPath);
    }
  }

  Future<void> _downloadSshToLocal(String sshPath, String localDest) async {
    await sshRepository.downloadToLocal(sshPath, localDest);
  }

  @override
  Future<void> moveItem(String sourcePath, String destinationPath) {
    return _getRepositoryForPath(
      sourcePath,
    ).moveItem(sourcePath, destinationPath);
  }

  @override
  Future<void> moveToTrash(String path) {
    return _getRepositoryForPath(path).moveToTrash(path);
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

      final srcIsSsh = _isSshPath(src);
      final dstIsSsh = _isSshPath(destinationPath);
      final name = _itemName(src);
      final destItemPath = _joinPath(destinationPath, name);

      try {
        if (srcIsSsh && !dstIsSsh) {
          // SSH → Local
          await sshRepository.downloadToLocal(src, destItemPath);
        } else if (!srcIsSsh && dstIsSsh) {
          // Local → SSH
          await sshRepository.uploadFromLocal(src, destItemPath);
        } else if (srcIsSsh && dstIsSsh) {
          // SSH → SSH (same server)
          await sshRepository.copyItem(src, destItemPath);
        } else {
          // Local → Local (stream for progress)
          await for (final status in defaultRepository.copyItems(
            [src],
            destinationPath,
            token,
          )) {
            yield OperationStatus(
              totalBytes: status.totalBytes,
              processedBytes: status.processedBytes,
              totalItems: total,
              processedItems: done,
              currentItem: status.currentItem,
            );
          }
          done++;
          continue;
        }
      } catch (e) {
        debugPrint('Copy error ($src → $destinationPath): $e');
      }

      done++;
      yield OperationStatus(
        totalBytes: 0,
        processedBytes: 0,
        totalItems: total,
        processedItems: done,
        currentItem: name,
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

      final srcIsSsh = _isSshPath(src);
      final dstIsSsh = _isSshPath(destinationPath);
      final name = _itemName(src);
      final destItemPath = _joinPath(destinationPath, name);

      try {
        if (srcIsSsh && !dstIsSsh) {
          // SSH → Local: download then delete remote
          await sshRepository.downloadToLocal(src, destItemPath);
          await sshRepository.deleteItem(src);
        } else if (!srcIsSsh && dstIsSsh) {
          // Local → SSH: upload then delete local
          await sshRepository.uploadFromLocal(src, destItemPath);
          await defaultRepository.deleteItem(src);
        } else if (srcIsSsh && dstIsSsh) {
          await sshRepository.moveItem(src, destItemPath);
        } else {
          // Local → Local (stream for progress)
          await for (final status in defaultRepository.moveItems(
            [src],
            destinationPath,
            token,
          )) {
            yield OperationStatus(
              totalBytes: status.totalBytes,
              processedBytes: status.processedBytes,
              totalItems: total,
              processedItems: done,
              currentItem: status.currentItem,
            );
          }
          done++;
          continue;
        }
      } catch (e) {
        debugPrint('Move error ($src → $destinationPath): $e');
      }

      done++;
      yield OperationStatus(
        totalBytes: 0,
        processedBytes: 0,
        totalItems: total,
        processedItems: done,
        currentItem: name,
      );
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _itemName(String path) {
    if (_isSshPath(path)) {
      final uri = Uri.tryParse(path);
      return uri?.pathSegments.lastWhere(
            (s) => s.isNotEmpty,
            orElse: () => path,
          ) ??
          path;
    }
    return p.basename(path);
  }

  String _joinPath(String base, String name) {
    if (_isSshPath(base)) {
      final remotePart = base.endsWith('/') ? '$base$name' : '$base/$name';
      // Keep the ssh://connId prefix
      final uri = Uri.tryParse(base);
      if (uri != null) {
        final connId = uri.host;
        final basePath = uri.path.endsWith('/') ? uri.path : '${uri.path}/';
        return 'ssh://$connId$basePath$name';
      }
      return remotePart;
    }
    return p.join(base, name);
  }
}
