import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'package:fima/domain/utils/fima_path.dart';
import 'package:fima/infrastructure/service/metadata/item_metadata_models.dart';

/// Background isolate workers for recursive directory size/count walks,
/// ZIP stats inspection, and image dimension decoding.
class DirectoryStatsCalculator {
  const DirectoryStatsCalculator._();

  static const int maxImageDimensionCheckBytes = 30 * 1024 * 1024;

  static const Set<String> imageExtensions = {
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.bmp',
    '.webp',
    '.ico',
    '.tiff',
    '.tif',
  };

  static Future<(int, int)?> readImageDimensions(String path) =>
      compute(_readImageDimensionsSync, path);

  static Future<(int, int, int)?> readZipStats(
    String zipFilePath,
    String innerPath,
  ) => compute(_readZipStatsSync, (zipFilePath, innerPath));

  static Future<DirectoryStatsHandle> calculateDirectoryStats({
    required List<String> paths,
    required void Function(int files, int folders, int totalBytes, bool isDone)
    onProgress,
  }) async {
    final receivePort = ReceivePort();
    Isolate? isolate;
    bool cancelled = false;

    receivePort.listen((message) {
      if (cancelled) return;
      if (message is Map<String, dynamic>) {
        final files = message['files'] as int;
        final folders = message['folders'] as int;
        final totalBytes = message['totalBytes'] as int;
        final isDone = message['isDone'] as bool;
        onProgress(files, folders, totalBytes, isDone);
        if (isDone) {
          receivePort.close();
        }
      }
    });

    try {
      isolate = await Isolate.spawn(_isolateCalculateStats, {
        'sendPort': receivePort.sendPort,
        'paths': paths,
      });
    } catch (e) {
      debugPrint('Failed to spawn stats isolate: $e');
      receivePort.close();
      onProgress(0, 0, 0, true);
    }

    return DirectoryStatsHandle(() {
      cancelled = true;
      isolate?.kill(priority: Isolate.immediate);
      receivePort.close();
    });
  }

  static Future<int> calculateSingleDirectorySize(String path) async {
    if (FimaPath.isSshPath(path)) return 0;
    final split = FimaPath.extractZipParts(path);
    if (split != null) {
      final zipStats = await readZipStats(split.$1, split.$2);
      return zipStats?.$3 ?? 0;
    }
    return compute(_calculateLocalDirectorySize, path);
  }
}

(int, int)? _readImageDimensionsSync(String path) {
  try {
    final decoder = img.findDecoderForNamedImage(path);
    if (decoder == null) return null;
    final bytes = File(path).readAsBytesSync();
    final info = decoder.startDecode(bytes);
    if (info == null) return null;
    return (info.width, info.height);
  } catch (_) {
    return null;
  }
}

/// Returns (fileCount, folderCount, totalUncompressedBytes) for a ZIP file or
/// an inner path inside a ZIP file.
(int, int, int)? _readZipStatsSync((String, String) args) {
  final zipFilePath = args.$1;
  final innerPath = args.$2;
  InputFileStream? input;
  try {
    input = InputFileStream(zipFilePath);
    final archive = ZipDecoder().decodeStream(input);
    final normalizedPrefix = innerPath.isEmpty
        ? ''
        : (innerPath.endsWith('/') ? innerPath : '$innerPath/');

    int files = 0;
    final Set<String> folders = {};
    int uncompressed = 0;

    for (final entry in archive) {
      if (normalizedPrefix.isNotEmpty) {
        if (!entry.name.startsWith(normalizedPrefix) &&
            entry.name != innerPath) {
          continue;
        }
      }

      if (entry.isFile && !entry.name.endsWith('/')) {
        files++;
        uncompressed += entry.size;
      } else {
        final trimmed = entry.name.endsWith('/')
            ? entry.name.substring(0, entry.name.length - 1)
            : entry.name;
        if (trimmed.isNotEmpty && trimmed != innerPath) {
          folders.add(trimmed);
        }
      }
    }

    return (files, folders.length, uncompressed);
  } catch (_) {
    return null;
  } finally {
    input?.closeSync();
  }
}

void _isolateCalculateStats(Map<String, dynamic> args) {
  final sendPort = args['sendPort'] as SendPort;
  final paths = List<String>.from(args['paths'] as List);

  int files = 0;
  int folders = 0;
  int totalBytes = 0;
  int counter = 0;

  void sendUpdate({required bool isDone}) {
    sendPort.send({
      'files': files,
      'folders': folders,
      'totalBytes': totalBytes,
      'isDone': isDone,
    });
  }

  for (final rootPath in paths) {
    try {
      final type = FileSystemEntity.typeSync(rootPath, followLinks: false);
      if (type == FileSystemEntityType.file) {
        files++;
        totalBytes += File(rootPath).lengthSync();
      } else if (type == FileSystemEntityType.directory) {
        if (paths.length > 1) {
          folders++;
        }
        final stack = <Directory>[Directory(rootPath)];
        while (stack.isNotEmpty) {
          final dir = stack.removeLast();
          try {
            for (final entity in dir.listSync(followLinks: false)) {
              counter++;
              if (entity is File) {
                files++;
                try {
                  totalBytes += entity.lengthSync();
                } catch (_) {}
              } else if (entity is Directory) {
                folders++;
                stack.add(entity);
              }
              if (counter % 150 == 0) {
                sendUpdate(isDone: false);
              }
            }
          } catch (_) {
            // Skip unreadable subdirectories
          }
        }
      }
    } catch (_) {}
  }

  sendUpdate(isDone: true);
}

int _calculateLocalDirectorySize(String rootPath) {
  int totalBytes = 0;
  try {
    final type = FileSystemEntity.typeSync(rootPath, followLinks: false);
    if (type == FileSystemEntityType.file) {
      return File(rootPath).lengthSync();
    }
    if (type != FileSystemEntityType.directory) return 0;
    final stack = <Directory>[Directory(rootPath)];
    while (stack.isNotEmpty) {
      final dir = stack.removeLast();
      try {
        for (final entity in dir.listSync(followLinks: false)) {
          if (entity is File) {
            try {
              totalBytes += entity.lengthSync();
            } catch (_) {}
          } else if (entity is Directory) {
            stack.add(entity);
          }
        }
      } catch (_) {
        // Skip unreadable subdirectories
      }
    }
  } catch (_) {}
  return totalBytes;
}
