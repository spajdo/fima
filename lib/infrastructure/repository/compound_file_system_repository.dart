import 'package:fima/domain/entity/file_operation.dart';
import 'package:fima/domain/entity/file_system_item.dart';
import 'package:fima/domain/repository/file_system_repository.dart';
import 'package:fima/infrastructure/repository/zip_file_system_repository.dart';
import 'dart:io';

class CompoundFileSystemRepository implements FileSystemRepository {
  final FileSystemRepository defaultRepository;
  final ZipFileSystemRepository zipRepository;

  CompoundFileSystemRepository(this.defaultRepository)
    : zipRepository = ZipFileSystemRepository(defaultRepository);

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
    if (_isZipPath(path)) {
      return zipRepository;
    }
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
    return _getRepositoryForPath(
      sourcePath,
    ).copyItem(sourcePath, destinationPath);
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
  ) {
    // Basic routing: assume source paths are all same type, or fallback operates normally
    final repo = sourcePaths.isNotEmpty
        ? _getRepositoryForPath(sourcePaths.first)
        : defaultRepository;
    return repo.copyItems(sourcePaths, destinationPath, token);
  }

  @override
  Stream<OperationStatus> moveItems(
    List<String> sourcePaths,
    String destinationPath,
    CancellationToken token,
  ) {
    final repo = sourcePaths.isNotEmpty
        ? _getRepositoryForPath(sourcePaths.first)
        : defaultRepository;
    return repo.moveItems(sourcePaths, destinationPath, token);
  }
}
