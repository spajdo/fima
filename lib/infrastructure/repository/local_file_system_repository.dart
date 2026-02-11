import 'dart:io';

import 'package:fima/domain/entity/file_system_item.dart';
import 'package:fima/domain/repository/file_system_repository.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LocalFileSystemRepository implements FileSystemRepository {
  @override
  Future<List<FileSystemItem>> getItems(String path) async {
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
       items.add(FileSystemItem(
         path: parent.path,
         name: '..',
         size: 0,
         modified: DateTime.now(), // dummy
         isDirectory: true,
         isParentDetails: true,
       ));
    }

    try {
      final entities = await dir.list().toList();
      for (final entity in entities) {
        try {
          final stat = await entity.stat();
          final name = p.basename(entity.path);
          // Skip hidden files if likely intended, but request didn't specify.
          // keeping all files for now.

          items.add(FileSystemItem(
            path: entity.path,
            name: name,
            size: stat.size,
            modified: stat.modified,
            isDirectory: entity is Directory,
          ));
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
       return directory.parent.path; // Often documents is ~/Documents, so parent is ~
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
}
