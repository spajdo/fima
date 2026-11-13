import 'package:fima/domain/entity/file_operation.dart';
import 'package:fima/domain/entity/file_system_item.dart';
import 'package:fima/domain/repository/file_system_repository.dart';
import 'package:fima/domain/utils/fima_path.dart';
import 'package:fima/infrastructure/repository/ssh_file_system_repository.dart';
import 'package:fima/infrastructure/repository/zip_file_system_repository.dart';
import 'package:path/path.dart' as p;

class CompoundFileSystemRepository implements FileSystemRepository {
  final FileSystemRepository defaultRepository;
  final ZipFileSystemRepository zipRepository;
  final SshFileSystemRepository sshRepository;

  CompoundFileSystemRepository(this.defaultRepository)
    : zipRepository = ZipFileSystemRepository(defaultRepository),
      sshRepository = SshFileSystemRepository();

  bool _isSshPath(String path) => FimaPath.isSshPath(path);

  bool _isZipPath(String path) => FimaPath.isZipPath(path);

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
  Future<void> copyItem(String sourcePath, String destinationPath) async {
    if (_isZipPath(sourcePath)) {
      // ZIP → Local: extract from archive
      final token = CancellationToken();
      await for (final _ in zipRepository.extractItems(
        [sourcePath],
        p.dirname(destinationPath),
        token,
      )) {}
      return;
    }

    final srcIsSsh = _isSshPath(sourcePath);
    final dstIsSsh = _isSshPath(destinationPath);

    if (srcIsSsh && dstIsSsh) {
      return sshRepository.copyItem(sourcePath, destinationPath);
    } else if (srcIsSsh && !dstIsSsh) {
      // SSH -> local
      return sshRepository.downloadEntryToLocal(sourcePath, destinationPath);
    } else if (!srcIsSsh && dstIsSsh) {
      // Local -> SSH
      return sshRepository.uploadLocalEntry(sourcePath, destinationPath);
    } else {
      return defaultRepository.copyItem(sourcePath, destinationPath);
    }
  }

  @override
  Future<void> moveItem(String sourcePath, String destinationPath) {
    if (_isZipPath(sourcePath)) {
      // ZIP is read-only; move behaves as copy.
      return copyItem(sourcePath, destinationPath);
    }
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

      final srcIsZip = _isZipPath(src);
      final srcIsSsh = _isSshPath(src);
      final dstIsSsh = _isSshPath(destinationPath);
      final name = _itemName(src);
      final destItemPath = _joinPath(destinationPath, name);

      if (srcIsZip) {
        // ZIP -> Local: extract from archive
        await for (final status in zipRepository.extractItems(
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
      } else if (srcIsSsh && !dstIsSsh) {
        // SSH -> Local
        await sshRepository.downloadEntryToLocal(src, destItemPath);
      } else if (!srcIsSsh && dstIsSsh) {
        // Local -> SSH
        await sshRepository.uploadLocalEntry(src, destItemPath);
      } else if (srcIsSsh && dstIsSsh) {
        // SSH -> SSH (same server)
        await sshRepository.copyItem(src, destItemPath);
      } else {
        // Local -> Local (stream for progress)
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

      final srcIsZip = _isZipPath(src);
      final srcIsSsh = _isSshPath(src);
      final dstIsSsh = _isSshPath(destinationPath);
      final name = _itemName(src);
      final destItemPath = _joinPath(destinationPath, name);

      if (srcIsZip) {
        // ZIP is read-only; "move" just copies.
        await for (final status in zipRepository.extractItems(
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
      } else if (srcIsSsh && !dstIsSsh) {
        // SSH -> Local: download then delete remote
        await sshRepository.downloadEntryToLocal(src, destItemPath);
        await sshRepository.deleteItem(src);
      } else if (!srcIsSsh && dstIsSsh) {
        // Local -> SSH: upload then delete local
        await sshRepository.uploadLocalEntry(src, destItemPath);
        await defaultRepository.deleteItem(src);
      } else if (srcIsSsh && dstIsSsh) {
        await for (final status in sshRepository.moveItems(
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
      } else {
        // Local -> Local (stream for progress)
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

  String _itemName(String path) => FimaPath.basename(path);

  String _joinPath(String base, String name) => FimaPath.join(base, name);
}
