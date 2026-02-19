import 'dart:io';

import 'package:fima/domain/entity/file_operation.dart';
import 'package:fima/domain/entity/file_system_item.dart';
import 'package:fima/domain/repository/file_system_repository.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LocalFileSystemRepository implements FileSystemRepository {
  @override
  Future<List<FileSystemItem>> getItems(
    String path, {
    bool showHiddenFiles = false,
  }) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      throw FileSystemException('Directory not found', path);
    }

    final List<FileSystemItem> items = [];

    // Add parent directory ".." if not root
    // parentOf returns the parent directory.
    // simpler check: if path is not root.
    final parent = dir.parent;
    if (parent.path != dir.path) {
      items.add(
        FileSystemItem(
          path: parent.path,
          name: '..',
          size: 0,
          modified: DateTime.now(), // dummy
          isDirectory: true,
          isParentDetails: true,
        ),
      );
    }

    try {
      final entities = await dir.list().toList();
      for (final entity in entities) {
        try {
          final stat = await entity.stat();
          final name = p.basename(entity.path);

          // Skip hidden files unless showHiddenFiles is true
          if (!showHiddenFiles && name.startsWith('.')) {
            continue;
          }

          items.add(
            FileSystemItem(
              path: entity.path,
              name: name,
              size: stat.size,
              modified: stat.modified,
              isDirectory: entity is Directory,
            ),
          );
        } catch (e) {
          // Ignore items we can't stat (permission denied etc)
          // or handle them gracefully?
          // print('Error processing ${entity.path}: $e');
        }
      }
    } catch (e) {
      // access denied to list directory
      rethrow;
    }

    // Sort logic is in the UI/State layer usually, but repository just returns items.
    return items;
  }

  @override
  Future<String> getHomeDirectory() async {
    // Attempt to use Platform environment variables first as it is more reliable for "Home" on desktop
    String? home;
    try {
      if (Platform.isMacOS || Platform.isLinux) {
        home = Platform.environment['HOME'];
      } else if (Platform.isWindows) {
        home = Platform.environment['USERPROFILE'];
      }
    } catch (_) {}

    if (home != null && await Directory(home).exists()) {
      return home;
    }

    // Fallback to path_provider
    try {
      final directory = await getApplicationDocumentsDirectory();
      return directory
          .parent
          .path; // Often documents is ~/Documents, so parent is ~
    } catch (_) {
      return '/'; // Fallback to root
    }
  }

  @override
  Future<void> deleteItem(String path) async {
    final type = await FileSystemEntity.type(path);
    if (type == FileSystemEntityType.directory) {
      await Directory(path).delete(recursive: true);
    } else if (type == FileSystemEntityType.file) {
      await File(path).delete();
    } else if (type == FileSystemEntityType.link) {
      await Link(path).delete();
    }
  }

  @override
  Future<void> createDirectory(String path) async {
    await Directory(path).create();
  }

  @override
  Future<void> createFile(String path) async {
    await File(path).create();
  }

  @override
  Future<void> renameItem(String oldPath, String newPath) async {
    final type = await FileSystemEntity.type(oldPath);
    if (type == FileSystemEntityType.directory) {
      await Directory(oldPath).rename(newPath);
    } else {
      await File(oldPath).rename(newPath);
    }
  }

  @override
  Future<void> copyItem(String sourcePath, String destinationPath) async {
    final type = await FileSystemEntity.type(sourcePath);
    if (type == FileSystemEntityType.directory) {
      // Recursive copy is manual in Dart
      await _copyDirectory(Directory(sourcePath), Directory(destinationPath));
    } else {
      await File(sourcePath).copy(destinationPath);
    }
  }

  @override
  Future<void> moveItem(String sourcePath, String destinationPath) async {
    await renameItem(sourcePath, destinationPath);
  }

  // Helper for non-stream copy (used by copyItem)
  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (final entity in source.list(recursive: false)) {
      final newPath = p.join(destination.path, p.basename(entity.path));
      if (entity is Directory) {
        await _copyDirectory(entity, Directory(newPath));
      } else if (entity is File) {
        await entity.copy(newPath);
      }
    }
  }

  @override
  Stream<OperationStatus> copyItems(
    List<String> sourcePaths,
    String destinationPath,
    CancellationToken token,
  ) async* {
    int totalItems = 0;
    int totalBytes = 0;
    int processedItems = 0;
    int processedBytes = 0;

    // 1. Calculate totals
    for (final path in sourcePaths) {
      if (token.isCancelled) return;
      final stats = await _calculateTotalSize(path);
      totalItems += stats.$1;
      totalBytes += stats.$2;
    }

    yield OperationStatus(
      totalBytes: totalBytes,
      processedBytes: 0,
      totalItems: totalItems,
      processedItems: 0,
      currentItem: 'Preparing...',
    );

    // 2. Perform copy
    for (final sourcePath in sourcePaths) {
      if (token.isCancelled) return;
      final entityName = p.basename(sourcePath);
      final destPath = p.join(destinationPath, entityName);

      // Recursive copy with stream
      await for (final status in _recursiveCopy(
        sourcePath,
        destPath,
        token,
        totalBytes,
        totalItems,
        processedBytes,
        processedItems,
      )) {
        yield status;
        processedBytes = status.processedBytes;
        processedItems = status.processedItems;
      }

      // Update totals for next iteration if needed
      // (processedBytes and processedItems are updated via stream yield)
    }
  }

  @override
  Stream<OperationStatus> moveItems(
    List<String> sourcePaths,
    String destinationPath,
    CancellationToken token,
  ) async* {
    int totalItems = sourcePaths.length;
    int processedItems = 0;
    // For move totalBytes is only accurate if we fallback to copy.
    // We start with 0 and update if fallback happens.

    yield OperationStatus(
      totalBytes: 0,
      processedBytes: 0,
      totalItems: totalItems,
      processedItems: 0,
      currentItem: 'Preparing...',
    );

    for (final sourcePath in sourcePaths) {
      if (token.isCancelled) return;
      final entityName = p.basename(sourcePath);
      final destPath = p.join(destinationPath, entityName);

      bool renameSuccess = false;
      try {
        await renameItem(sourcePath, destPath);
        renameSuccess = true;
      } catch (e) {
        // Fallback to copy + delete
        renameSuccess = false;
      }

      if (renameSuccess) {
        processedItems++;
        yield OperationStatus(
          totalBytes: 0,
          processedBytes: 0,
          totalItems: totalItems,
          processedItems: processedItems,
          currentItem: entityName,
        );
      } else {
        // Fallback: Copy then Delete
        final stats = await _calculateTotalSize(sourcePath);
        final copyTotalItems = stats.$1;
        final copyTotalBytes = stats.$2;

        await for (final status in _recursiveCopy(
          sourcePath,
          destPath,
          token,
          copyTotalBytes,
          copyTotalItems,
          0,
          0,
        )) {
          yield status.copyWith(currentItem: 'Moving ${status.currentItem}');
        }

        if (!token.isCancelled) {
          await deleteItem(sourcePath);
          processedItems++;
        }
      }
    }
  }

  // Tuple <Items, Bytes>
  // Simple Pair implementation since we don't have tuple package
  Future<(int, int)> _calculateTotalSize(String path) async {
    int items = 0;
    int bytes = 0;
    final type = await FileSystemEntity.type(path);

    if (type == FileSystemEntityType.file) {
      items = 1;
      bytes = (await File(path).stat()).size;
    } else if (type == FileSystemEntityType.directory) {
      items = 1; // Directory itself
      try {
        await for (final entity in Directory(
          path,
        ).list(recursive: true, followLinks: false)) {
          items++;
          if (entity is File) {
            bytes += (await entity.stat()).size;
          }
        }
      } catch (e) {
        // Ignore access errors
      }
    }
    return (items, bytes);
  }

  Stream<OperationStatus> _recursiveCopy(
    String sourceStr,
    String destStr,
    CancellationToken token,
    int totalBytes,
    int totalItems,
    int initialProcessedBytes,
    int initialProcessedItems,
  ) async* {
    int processedBytes = initialProcessedBytes;
    int processedItems = initialProcessedItems;

    final type = await FileSystemEntity.type(sourceStr);

    if (type == FileSystemEntityType.directory) {
      await Directory(destStr).create(recursive: true);
      processedItems++;
      yield OperationStatus(
        totalBytes: totalBytes,
        processedBytes: processedBytes,
        totalItems: totalItems,
        processedItems: processedItems,
        currentItem: p.basename(sourceStr),
      );

      await for (final entity in Directory(sourceStr).list(recursive: false)) {
        if (token.isCancelled) return;
        final newDest = p.join(destStr, p.basename(entity.path));
        await for (final status in _recursiveCopy(
          entity.path,
          newDest,
          token,
          totalBytes,
          totalItems,
          processedBytes,
          processedItems,
        )) {
          yield status;
          processedBytes = status.processedBytes;
          processedItems = status.processedItems;
        }
      }
    } else if (type == FileSystemEntityType.file) {
      final file = File(sourceStr);
      // Create streams
      final inputStream = file.openRead();
      final outputSink = File(destStr).openWrite();

      try {
        await for (final chunk in inputStream) {
          if (token.isCancelled) {
            await outputSink.close();
            await File(destStr).delete(); // Cleanup partial
            return;
          }
          outputSink.add(chunk);
          processedBytes += chunk.length;

          yield OperationStatus(
            totalBytes: totalBytes,
            processedBytes: processedBytes,
            totalItems: totalItems,
            processedItems: processedItems,
            currentItem: p.basename(sourceStr),
          );
        }
        await outputSink.flush();
        await outputSink.close();
        processedItems++;
        yield OperationStatus(
          totalBytes: totalBytes,
          processedBytes: processedBytes,
          totalItems: totalItems,
          processedItems: processedItems,
          currentItem: p.basename(sourceStr),
        );
      } catch (e) {
        await outputSink.close();
        rethrow;
      }
    }
  }

  @override
  Future<void> moveToTrash(String path) async {
    // Determine trash directory (Freedesktop.org spec)
    // ~/.local/share/Trash
    final home = Platform.environment['HOME'];
    if (home == null) {
      // Fallback to permanent delete if HOME not set (unlikely on Linux)
      return deleteItem(path);
    }

    final trashDir = Directory(p.join(home, '.local', 'share', 'Trash'));
    final filesDir = Directory(p.join(trashDir.path, 'files'));
    final infoDir = Directory(p.join(trashDir.path, 'info'));

    if (!await filesDir.exists()) {
      await filesDir.create(recursive: true);
    }
    if (!await infoDir.exists()) {
      await infoDir.create(recursive: true);
    }

    final entityName = p.basename(path);
    String uniqueName = entityName;
    int counter = 1;

    // Ensure unique name in trash
    while (await File(p.join(filesDir.path, uniqueName)).exists() ||
        await Directory(p.join(filesDir.path, uniqueName)).exists()) {
      final extension = p.extension(entityName);
      final nameWithoutExtension = p.basenameWithoutExtension(entityName);
      uniqueName = '$nameWithoutExtension.$counter$extension';
      counter++;
    }

    final destinationPath = p.join(filesDir.path, uniqueName);
    final infoPath = p.join(infoDir.path, '$uniqueName.trashinfo');

    // Move the actual file/directory
    await moveItem(path, destinationPath);

    // Create .trashinfo file
    // [Trash Info]
    // Path=/original/path/to/file
    // DeletionDate=YYYY-MM-DDThh:mm:ss
    final now = DateTime.now().toUtc(); // Spec says usually RFC3339
    // Format: YYYY-MM-DDThh:mm:ss (no timezone, assumed local/UTC? Spec says YYYYMMDDThhmmss)
    // "The date and time are in the YYYY-MM-DDThh:mm:ss format."
    final formattedDate =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}T'
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';

    final infoContent =
        '''[Trash Info]
Path=$path
DeletionDate=$formattedDate
''';

    await File(infoPath).writeAsString(infoContent);
  }
}
