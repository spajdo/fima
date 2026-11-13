import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:fima/domain/entity/panel_operation_progress.dart';
import 'package:fima/domain/utils/fima_path.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Handles archive extraction and compression in background isolates,
/// emitting progress updates via streams.
class ArchiveService {
  const ArchiveService();

  Stream<PanelOperationProgress> extractArchive(
    String zipPath,
    String destinationPath,
  ) async* {
    if (FimaPath.isSshPath(zipPath) ||
        FimaPath.isSshPath(destinationPath) ||
        FimaPath.isZipPath(destinationPath)) {
      return;
    }

    yield* _runIsolateTask(_isolateExtractArchive, {
      'zipPath': zipPath,
      'destinationPath': destinationPath,
    });
  }

  Stream<PanelOperationProgress> compressItems(
    List<String> paths,
    String zipPath,
    String basePath,
  ) async* {
    if (paths.isEmpty ||
        FimaPath.isSshPath(basePath) ||
        FimaPath.isZipPath(basePath) ||
        paths.any(
          (item) => FimaPath.isSshPath(item) || FimaPath.isZipPath(item),
        )) {
      return;
    }

    yield* _runIsolateTask(_isolateCompressItems, {
      'paths': paths,
      'zipPath': zipPath,
      'basePath': basePath,
    });
  }

  Stream<PanelOperationProgress> _runIsolateTask(
    void Function(Map<String, dynamic>) entryPoint,
    Map<String, dynamic> args,
  ) async* {
    final receivePort = ReceivePort();
    try {
      await Isolate.spawn(entryPoint, {
        ...args,
        'sendPort': receivePort.sendPort,
      });

      await for (final message in receivePort) {
        if (message == null) break;
        if (message is Map<String, dynamic>) {
          if (message.containsKey('error')) {
            debugPrint('Archive isolate error: ${message['error']}');
            break;
          }
          yield PanelOperationProgress(
            operationName: message['operationName'] as String,
            progress: (message['progress'] as num).toDouble(),
            currentItem: message['currentItem'] as String,
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching archive isolate: $e');
    } finally {
      receivePort.close();
    }
  }
}

class _ArchiveEntry {
  final String absolutePath;
  final String archivePath;

  const _ArchiveEntry(this.absolutePath, this.archivePath);
}

void _isolateExtractArchive(Map<String, dynamic> args) {
  final sendPort = args['sendPort'] as SendPort;
  final zipPath = args['zipPath'] as String;
  final destinationPath = args['destinationPath'] as String;

  try {
    final bytes = File(zipPath).readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);

    final totalFiles = archive.length;
    if (totalFiles == 0) {
      sendPort.send(null);
      return;
    }

    int processedFiles = 0;
    for (final file in archive) {
      final destPath = p.join(destinationPath, file.name);
      if (!FimaPath.isStrictlyWithin(destinationPath, destPath)) {
        processedFiles++;
        continue;
      }

      if (file.isFile) {
        final data = file.content as List<int>;
        final destFile = File(destPath);
        destFile.createSync(recursive: true);
        destFile.writeAsBytesSync(data);
      } else {
        Directory(destPath).createSync(recursive: true);
      }

      processedFiles++;
      sendPort.send({
        'operationName': 'Extracting',
        'progress': processedFiles / totalFiles,
        'currentItem': p.basename(file.name),
      });
    }
    sendPort.send(null);
  } catch (e) {
    sendPort.send({'error': e.toString()});
  }
}

void _isolateCompressItems(Map<String, dynamic> args) {
  final sendPort = args['sendPort'] as SendPort;
  _isolateCompressItemsAsync(args).catchError((e) {
    sendPort.send({'error': e.toString()});
  });
}

Future<void> _isolateCompressItemsAsync(Map<String, dynamic> args) async {
  final sendPort = args['sendPort'] as SendPort;
  final paths = args['paths'] as List<String>;
  final zipPath = args['zipPath'] as String;
  final basePath = args['basePath'] as String;

  final fileEntries = <_ArchiveEntry>[];

  for (final path in paths) {
    final stat = FileStat.statSync(path);
    if (stat.type == FileSystemEntityType.directory) {
      final dir = Directory(path);
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is File) {
          final archivePath = p.relative(entity.path, from: basePath);
          fileEntries.add(_ArchiveEntry(entity.path, archivePath));
        }
      }
    } else if (stat.type == FileSystemEntityType.file) {
      final archivePath = p.relative(path, from: basePath);
      fileEntries.add(_ArchiveEntry(path, archivePath));
    }
  }

  final encoder = ZipFileEncoder();
  encoder.create(zipPath);

  final totalFiles = fileEntries.length;
  if (totalFiles == 0) {
    await encoder.close();
    sendPort.send(null);
    return;
  }

  int processedFiles = 0;
  for (final entry in fileEntries) {
    await encoder.addFile(File(entry.absolutePath), entry.archivePath);
    processedFiles++;
    sendPort.send({
      'operationName': 'Compressing',
      'progress': processedFiles / totalFiles,
      'currentItem': p.basename(entry.absolutePath),
    });
  }

  await encoder.close();
  sendPort.send(null);
}
