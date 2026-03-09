import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:fima/domain/entity/file_operation.dart';
import 'package:fima/domain/entity/file_system_item.dart';
import 'package:fima/domain/repository/file_system_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class ZipFileSystemRepository implements FileSystemRepository {
  final FileSystemRepository fallbackRepository;

  ZipFileSystemRepository(this.fallbackRepository);

  @override
  Future<List<FileSystemItem>> getItems(
    String path, {
    bool showHiddenFiles = false,
  }) async {
    final zipPathResult = _extractZipPath(path);
    if (zipPathResult == null) {
      return fallbackRepository.getItems(
        path,
        showHiddenFiles: showHiddenFiles,
      );
    }

    final String zipFilePath = zipPathResult.$1;
    final String innerPath = zipPathResult.$2;

    final bytes = await File(zipFilePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final Set<String> processedNames = {};
    final List<FileSystemItem> items = [];

    // Add parent directory ".." if not root of ZIP or further inside
    // If innerPath is empty, the parent is the directory containing the zip file
    final parent = p.dirname(path);
    if (parent != path) {
      items.add(
        FileSystemItem(
          path: parent,
          name: '..',
          size: 0,
          modified: DateTime.now(), // dummy
          isDirectory: true,
          isParentDetails: true,
        ),
      );
    }

    final targetPrefix = innerPath.isEmpty
        ? ''
        : (innerPath.endsWith('/') ? innerPath : '$innerPath/');

    for (final file in archive) {
      if (!file.isFile) {
        // Some zips have directory entries, some don't. We will deduce directories from file paths.
      }

      final fullZipPath = file.name; // e.g., 'folder/file.txt'
      if (fullZipPath.startsWith(targetPrefix) && fullZipPath != targetPrefix) {
        final relativePath = fullZipPath.substring(targetPrefix.length);
        final parts = relativePath.split('/');
        final name = parts.first;

        // Skip hidden files unless showHiddenFiles is true
        if (!showHiddenFiles && name.startsWith('.')) {
          continue;
        }

        if (parts.length > 1 ||
            (parts.length == 1 && file.name.endsWith('/'))) {
          // It's a directory
          if (!processedNames.contains(name) && name.isNotEmpty) {
            processedNames.add(name);
            items.add(
              FileSystemItem(
                path: p.join(zipFilePath, targetPrefix + name),
                name: name,
                size: 0,
                // Last modified date of directory could be omitted or dummy
                modified: DateTime.fromMillisecondsSinceEpoch(
                  file.lastModTime * 1000,
                ),
                isDirectory: true,
              ),
            );
          }
        } else {
          // It's a file
          if (!processedNames.contains(name) && name.isNotEmpty) {
            processedNames.add(name);
            items.add(
              FileSystemItem(
                path: p.join(zipFilePath, fullZipPath),
                name: name,
                size: file.size,
                modified: DateTime.fromMillisecondsSinceEpoch(
                  file.lastModTime * 1000,
                ),
                isDirectory: false,
              ),
            );
          }
        }
      }
    }

    return items;
  }

  (String, String)? _extractZipPath(String path) {
    if (path.isEmpty) return null;

    final lowerPath = path.toLowerCase();
    final zipIndex = lowerPath.indexOf('.zip');

    if (zipIndex != -1) {
      // It ends with .zip or has .zip/ inside it
      int endIndex = zipIndex + 4;
      if (endIndex == path.length ||
          path[endIndex] == Platform.pathSeparator ||
          path[endIndex] == '/') {
        final zipFilePath = path.substring(0, endIndex);
        String innerPath = '';
        if (endIndex < path.length) {
          innerPath = path.substring(endIndex + 1);
          // Normalize separators for zip internal paths which are typically '/'
          innerPath = innerPath.replaceAll(Platform.pathSeparator, '/');
        }
        return (zipFilePath, innerPath);
      }
    }
    return null;
  }

  /// Extracts files/directories from inside a ZIP archive to a local
  /// destination, streaming progress via [OperationStatus].
  Stream<OperationStatus> extractItems(
    List<String> sourcePaths,
    String destinationPath,
    CancellationToken token,
  ) async* {
    // Group source inner-paths by their ZIP file so each archive is read once.
    final Map<String, List<String>> zipGroups = {};
    for (final src in sourcePaths) {
      final result = _extractZipPath(src);
      if (result == null) continue;
      zipGroups.putIfAbsent(result.$1, () => []).add(result.$2);
    }

    // Collect all (archiveEntry, relativeDestPath) pairs and compute totals.
    final List<(ArchiveFile, String)> work = [];
    final Set<String> seenEntryNames = {};
    int totalBytes = 0;

    for (final group in zipGroups.entries) {
      final zipFilePath = group.key;
      final innerPaths = group.value;

      final bytes = await File(zipFilePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final innerPath in innerPaths) {
        // Determine the base name for the destination folder structure.
        final trimmedInner = innerPath.endsWith('/')
            ? innerPath.substring(0, innerPath.length - 1)
            : innerPath;
        final parentPrefix = trimmedInner.contains('/')
            ? trimmedInner.substring(
                0, trimmedInner.lastIndexOf('/') + 1)
            : '';

        for (final entry in archive) {
          final entryName = entry.name;

          // Match: exact file, exact dir entry, or contents inside dir.
          final bool isMatch = entryName == innerPath ||
              entryName == '$innerPath/' ||
              entryName.startsWith(
                innerPath.endsWith('/') ? innerPath : '$innerPath/');

          if (!isMatch) continue;
          if (seenEntryNames.contains(entryName)) continue;
          seenEntryNames.add(entryName);

          // Relative path under the destination.
          final relPath = entryName.substring(parentPrefix.length);
          if (relPath.isEmpty) continue;

          work.add((entry, relPath));
          if (entry.isFile) {
            totalBytes += entry.size;
          }
        }
      }
    }

    if (work.isEmpty) return;

    final totalItems = work.length;
    int processedBytes = 0;
    int processedItems = 0;

    yield OperationStatus(
      totalBytes: totalBytes,
      processedBytes: 0,
      totalItems: totalItems,
      processedItems: 0,
      currentItem: 'Preparing...',
    );

    for (final (entry, relPath) in work) {
      if (token.isCancelled) return;

      final destPath = p.join(destinationPath, relPath);

      try {
        if (!entry.isFile || entry.name.endsWith('/')) {
          await Directory(destPath).create(recursive: true);
        } else {
          await Directory(p.dirname(destPath)).create(recursive: true);
          final content = entry.content as List<int>;
          await File(destPath).writeAsBytes(content);
          processedBytes += entry.size;
        }
      } catch (e) {
        debugPrint('ZIP extract error ($relPath): $e');
      }

      processedItems++;
      yield OperationStatus(
        totalBytes: totalBytes,
        processedBytes: processedBytes,
        totalItems: totalItems,
        processedItems: processedItems,
        currentItem: p.basename(relPath),
      );
    }
  }

  @override
  Future<String> getHomeDirectory() {
    return fallbackRepository.getHomeDirectory();
  }

  @override
  Future<void> deleteItem(String path) {
    return fallbackRepository.deleteItem(path);
  }

  @override
  Future<void> createDirectory(String path) {
    return fallbackRepository.createDirectory(path);
  }

  @override
  Future<void> createFile(String path) {
    return fallbackRepository.createFile(path);
  }

  @override
  Future<void> renameItem(String oldPath, String newPath) {
    return fallbackRepository.renameItem(oldPath, newPath);
  }

  @override
  Future<void> copyItem(String sourcePath, String destinationPath) {
    return fallbackRepository.copyItem(sourcePath, destinationPath);
  }

  @override
  Future<void> moveItem(String sourcePath, String destinationPath) {
    return fallbackRepository.moveItem(sourcePath, destinationPath);
  }

  @override
  Future<void> moveToTrash(String path) {
    return fallbackRepository.moveToTrash(path);
  }

  @override
  Stream<OperationStatus> copyItems(
    List<String> sourcePaths,
    String destinationPath,
    CancellationToken token,
  ) {
    return fallbackRepository.copyItems(sourcePaths, destinationPath, token);
  }

  @override
  Stream<OperationStatus> moveItems(
    List<String> sourcePaths,
    String destinationPath,
    CancellationToken token,
  ) {
    return fallbackRepository.moveItems(sourcePaths, destinationPath, token);
  }
}
