import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:fima/domain/entity/file_system_item.dart';
import 'package:fima/domain/entity/remote_connection.dart';
import 'package:fima/domain/repository/file_system_repository.dart';
import 'package:fima/infrastructure/repository/compound_file_system_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

class ItemMetadata {
  final String name;
  final String path;
  final String parentPath;
  final String kind;
  final bool isDirectory;
  final bool isSymlink;
  final bool isZipArchive;
  final bool isInsideZip;
  final bool isRemote;
  final bool isHidden;
  final bool isReadOnly;
  final bool isMultiSelection;
  final int selectedCount;
  final int sizeBytes;
  final DateTime? modified;
  final DateTime? accessed;
  final DateTime? changed;
  final String? permissions;
  final int? modeBits;
  final String? symlinkTarget;
  final (int, int)? imageDimensions;
  final int? ownerUid;
  final int? ownerGid;
  final int? fileCount;
  final int? folderCount;
  final int? totalSizeBytes;
  final int? zipUncompressedSize;
  final bool isCalculatingStats;

  const ItemMetadata({
    required this.name,
    required this.path,
    required this.parentPath,
    required this.kind,
    required this.isDirectory,
    this.isSymlink = false,
    this.isZipArchive = false,
    this.isInsideZip = false,
    this.isRemote = false,
    this.isHidden = false,
    this.isReadOnly = false,
    this.isMultiSelection = false,
    this.selectedCount = 1,
    required this.sizeBytes,
    this.modified,
    this.accessed,
    this.changed,
    this.permissions,
    this.modeBits,
    this.symlinkTarget,
    this.imageDimensions,
    this.ownerUid,
    this.ownerGid,
    this.fileCount,
    this.folderCount,
    this.totalSizeBytes,
    this.zipUncompressedSize,
    this.isCalculatingStats = false,
  });

  bool get canEditPermissions =>
      !isMultiSelection && !isInsideZip && (isRemote || !Platform.isWindows);

  ItemMetadata copyWith({
    String? name,
    String? path,
    String? parentPath,
    String? kind,
    bool? isDirectory,
    bool? isSymlink,
    bool? isZipArchive,
    bool? isInsideZip,
    bool? isRemote,
    bool? isHidden,
    bool? isReadOnly,
    bool? isMultiSelection,
    int? selectedCount,
    int? sizeBytes,
    DateTime? modified,
    DateTime? accessed,
    DateTime? changed,
    String? permissions,
    int? modeBits,
    String? symlinkTarget,
    (int, int)? imageDimensions,
    int? ownerUid,
    int? ownerGid,
    int? fileCount,
    int? folderCount,
    int? totalSizeBytes,
    int? zipUncompressedSize,
    bool? isCalculatingStats,
  }) {
    return ItemMetadata(
      name: name ?? this.name,
      path: path ?? this.path,
      parentPath: parentPath ?? this.parentPath,
      kind: kind ?? this.kind,
      isDirectory: isDirectory ?? this.isDirectory,
      isSymlink: isSymlink ?? this.isSymlink,
      isZipArchive: isZipArchive ?? this.isZipArchive,
      isInsideZip: isInsideZip ?? this.isInsideZip,
      isRemote: isRemote ?? this.isRemote,
      isHidden: isHidden ?? this.isHidden,
      isReadOnly: isReadOnly ?? this.isReadOnly,
      isMultiSelection: isMultiSelection ?? this.isMultiSelection,
      selectedCount: selectedCount ?? this.selectedCount,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      modified: modified ?? this.modified,
      accessed: accessed ?? this.accessed,
      changed: changed ?? this.changed,
      permissions: permissions ?? this.permissions,
      modeBits: modeBits ?? this.modeBits,
      symlinkTarget: symlinkTarget ?? this.symlinkTarget,
      imageDimensions: imageDimensions ?? this.imageDimensions,
      ownerUid: ownerUid ?? this.ownerUid,
      ownerGid: ownerGid ?? this.ownerGid,
      fileCount: fileCount ?? this.fileCount,
      folderCount: folderCount ?? this.folderCount,
      totalSizeBytes: totalSizeBytes ?? this.totalSizeBytes,
      zipUncompressedSize: zipUncompressedSize ?? this.zipUncompressedSize,
      isCalculatingStats: isCalculatingStats ?? this.isCalculatingStats,
    );
  }
}

class FileChecksums {
  final String md5Hex;
  final String sha256Hex;

  const FileChecksums({required this.md5Hex, required this.sha256Hex});
}

class DirectoryStatsHandle {
  final VoidCallback cancel;
  const DirectoryStatsHandle(this.cancel);
}

class ItemMetadataService {
  static const int _maxImageDimensionCheckBytes = 30 * 1024 * 1024;

  static const Set<String> _imageExtensions = {
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

  static const Map<String, String> _knownKinds = {
    '.zip': 'ZIP Archive',
    '.tar': 'TAR Archive',
    '.gz': 'Gzip Archive',
    '.bz2': 'Bzip2 Archive',
    '.xz': 'XZ Archive',
    '.7z': '7-Zip Archive',
    '.rar': 'RAR Archive',
    '.png': 'PNG Image',
    '.jpg': 'JPEG Image',
    '.jpeg': 'JPEG Image',
    '.gif': 'GIF Image',
    '.svg': 'SVG Vector Image',
    '.ico': 'Icon File',
    '.webp': 'WebP Image',
    '.bmp': 'Bitmap Image',
    '.tiff': 'TIFF Image',
    '.tif': 'TIFF Image',
    '.pdf': 'PDF Document',
    '.md': 'Markdown Document',
    '.markdown': 'Markdown Document',
    '.txt': 'Plain Text Document',
    '.log': 'Log File',
    '.json': 'JSON Document',
    '.xml': 'XML Document',
    '.yaml': 'YAML Document',
    '.yml': 'YAML Document',
    '.toml': 'TOML Document',
    '.csv': 'CSV Spreadsheet',
    '.html': 'HTML Document',
    '.htm': 'HTML Document',
    '.css': 'CSS Stylesheet',
    '.js': 'JavaScript Source',
    '.ts': 'TypeScript Source',
    '.dart': 'Dart Source',
    '.py': 'Python Script',
    '.sh': 'Shell Script',
    '.zsh': 'Zsh Script',
    '.bash': 'Bash Script',
    '.rs': 'Rust Source',
    '.go': 'Go Source',
    '.java': 'Java Source',
    '.kt': 'Kotlin Source',
    '.swift': 'Swift Source',
    '.c': 'C Source',
    '.cpp': 'C++ Source',
    '.h': 'C/C++ Header',
    '.mp3': 'MP3 Audio',
    '.wav': 'WAV Audio',
    '.flac': 'FLAC Audio',
    '.aac': 'AAC Audio',
    '.mp4': 'MP4 Video',
    '.mov': 'QuickTime Movie',
    '.mkv': 'Matroska Video',
    '.avi': 'AVI Video',
    '.dmg': 'macOS Disk Image',
    '.app': 'macOS Application',
    '.exe': 'Windows Executable',
    '.deb': 'Debian Package',
    '.rpm': 'RPM Package',
  };

  static bool isZipPath(String path) {
    final lower = path.toLowerCase();
    final idx = lower.indexOf('.zip');
    if (idx == -1) return false;
    final end = idx + 4;
    return end == path.length ||
        path[end] == Platform.pathSeparator ||
        path[end] == '/';
  }

  static (String, String)? splitZipPath(String path) {
    if (!isZipPath(path)) return null;
    final lower = path.toLowerCase();
    final idx = lower.indexOf('.zip');
    final end = idx + 4;
    final zipFile = path.substring(0, end);
    final inner = end < path.length
        ? path.substring(end + 1).replaceAll(Platform.pathSeparator, '/')
        : '';
    return (zipFile, inner);
  }

  static String describeKind(
    String name, {
    required bool isDirectory,
    bool isSymlink = false,
    bool isRemote = false,
    bool isInsideZip = false,
  }) {
    if (isSymlink) return 'Symbolic Link';
    if (isDirectory) {
      if (isRemote) return 'Remote Folder';
      if (isInsideZip) return 'Folder (in ZIP Archive)';
      return 'Folder';
    }
    final ext = p.extension(name).toLowerCase();
    final baseKind =
        _knownKinds[ext] ??
        (ext.length > 1 ? '${ext.substring(1).toUpperCase()} File' : 'File');
    if (isRemote) return 'Remote $baseKind';
    if (isInsideZip) return '$baseKind (in ZIP Archive)';
    return baseKind;
  }

  /// Builds immediate metadata synchronously/quickly before async deep scans.
  static ItemMetadata buildInitialMetadata({
    required List<FileSystemItem> items,
    required String currentPath,
  }) {
    if (items.length > 1) {
      int files = 0;
      int folders = 0;
      int immediateSize = 0;
      for (final item in items) {
        if (item.isDirectory) {
          folders++;
        } else {
          files++;
          immediateSize += item.size;
        }
      }
      final isRemote = currentPath.startsWith('ssh://');
      final isInsideZip = !isRemote && isZipPath(currentPath);
      return ItemMetadata(
        name: '${items.length} items selected',
        path: currentPath,
        parentPath: currentPath,
        kind: '$files files, $folders folders',
        isDirectory: folders > 0 && files == 0,
        isRemote: isRemote,
        isInsideZip: isInsideZip,
        isReadOnly: isInsideZip,
        isMultiSelection: true,
        selectedCount: items.length,
        sizeBytes: immediateSize,
        fileCount: files,
        folderCount: folders,
        totalSizeBytes: folders == 0 ? immediateSize : null,
        isCalculatingStats: !isRemote && !isInsideZip && folders > 0,
      );
    }

    final item = items.first;
    final isRemote = item.path.startsWith('ssh://');
    final zipSplit = !isRemote ? splitZipPath(item.path) : null;
    final isZipArchive =
        !isRemote &&
        !item.isDirectory &&
        item.name.toLowerCase().endsWith('.zip') &&
        (zipSplit == null || zipSplit.$2.isEmpty);
    final isInsideZip = zipSplit != null && zipSplit.$2.isNotEmpty;

    final parent = isRemote ? _sshParent(item.path) : p.dirname(item.path);

    return ItemMetadata(
      name: item.name,
      path: item.path,
      parentPath: parent,
      kind: describeKind(
        item.name,
        isDirectory: item.isDirectory,
        isRemote: isRemote,
        isInsideZip: isInsideZip,
      ),
      isDirectory: item.isDirectory,
      isZipArchive: isZipArchive,
      isInsideZip: isInsideZip,
      isRemote: isRemote,
      isHidden: item.name.startsWith('.'),
      isReadOnly: isInsideZip,
      sizeBytes: item.size,
      modified: item.modified,
      isCalculatingStats:
          (!isRemote && (item.isDirectory || isZipArchive || isInsideZip)),
    );
  }

  /// Loads detailed metadata (FileStat, symlink target, permissions, image
  /// dimensions, SSH stat, ZIP summary) without recursive folder walk.
  static Future<ItemMetadata> loadDetails({
    required List<FileSystemItem> items,
    required String currentPath,
    required FileSystemRepository repository,
  }) async {
    final base = buildInitialMetadata(items: items, currentPath: currentPath);

    if (items.length > 1) {
      return base;
    }

    final item = items.first;

    if (base.isRemote) {
      return _loadRemoteDetails(base, item, repository);
    }

    if (base.isInsideZip) {
      return _loadInsideZipDetails(base, item);
    }

    return _loadLocalDetails(base, item);
  }

  static Future<ItemMetadata> _loadLocalDetails(
    ItemMetadata base,
    FileSystemItem item,
  ) async {
    try {
      final linkType = await FileSystemEntity.type(
        item.path,
        followLinks: false,
      );
      final isSymlink = linkType == FileSystemEntityType.link;
      String? symlinkTarget;
      if (isSymlink) {
        try {
          symlinkTarget = await Link(item.path).target();
        } catch (_) {}
      }

      final stat = await FileStat.stat(item.path);
      final isDir =
          stat.type == FileSystemEntityType.directory || item.isDirectory;
      final permissions = _formatLocalPermissions(stat);
      final isReadOnly = !Platform.isWindows && (stat.mode & 0x92) == 0;

      (int, int)? imageDims;
      final ext = p.extension(item.name).toLowerCase();
      if (!isDir &&
          _imageExtensions.contains(ext) &&
          stat.size > 0 &&
          stat.size <= _maxImageDimensionCheckBytes) {
        imageDims = await compute(_readImageDimensions, item.path);
      }

      int? zipFiles;
      int? zipFolders;
      int? zipUncompressed;
      if (base.isZipArchive) {
        final zipStats = await compute(_readZipStats, (item.path, ''));
        if (zipStats != null) {
          zipFiles = zipStats.$1;
          zipFolders = zipStats.$2;
          zipUncompressed = zipStats.$3;
        }
      }

      return base.copyWith(
        kind: describeKind(item.name, isDirectory: isDir, isSymlink: isSymlink),
        isDirectory: isDir,
        isSymlink: isSymlink,
        symlinkTarget: symlinkTarget,
        sizeBytes: isDir ? 0 : stat.size,
        modified: stat.modified,
        accessed: stat.accessed,
        changed: stat.changed,
        permissions: permissions,
        modeBits: !Platform.isWindows ? (stat.mode & 0xFFF) : null,
        isReadOnly: isReadOnly,
        imageDimensions: imageDims,
        fileCount: zipFiles ?? base.fileCount,
        folderCount: zipFolders ?? base.folderCount,
        zipUncompressedSize: zipUncompressed,
        isCalculatingStats: isDir,
      );
    } catch (e) {
      debugPrint('Error loading metadata for ${item.path}: $e');
      return base.copyWith(isCalculatingStats: false);
    }
  }

  static Future<ItemMetadata> _loadInsideZipDetails(
    ItemMetadata base,
    FileSystemItem item,
  ) async {
    final split = splitZipPath(item.path);
    if (split == null) return base.copyWith(isCalculatingStats: false);

    final zipStats = await compute(_readZipStats, (split.$1, split.$2));
    if (zipStats == null) {
      return base.copyWith(isCalculatingStats: false);
    }

    return base.copyWith(
      fileCount: item.isDirectory ? zipStats.$1 : null,
      folderCount: item.isDirectory ? zipStats.$2 : null,
      totalSizeBytes: zipStats.$3,
      zipUncompressedSize: zipStats.$3,
      isCalculatingStats: false,
    );
  }

  static Future<ItemMetadata> _loadRemoteDetails(
    ItemMetadata base,
    FileSystemItem item,
    FileSystemRepository repository,
  ) async {
    if (repository is! CompoundFileSystemRepository) {
      return base.copyWith(isCalculatingStats: false);
    }

    try {
      final connId = RemoteConnection.connectionIdFromSshUrl(item.path);
      final remotePath = RemoteConnection.remotePathFromSshUrl(item.path);
      final sftp = repository.sshRepository.getSftpClientFor(connId);
      if (sftp == null) return base.copyWith(isCalculatingStats: false);

      final attrs = await sftp.stat(remotePath);
      final isSymlink = attrs.mode?.type == SftpFileType.symbolicLink;

      return base.copyWith(
        kind: describeKind(
          item.name,
          isDirectory: item.isDirectory,
          isSymlink: isSymlink,
          isRemote: true,
        ),
        isSymlink: isSymlink,
        sizeBytes: item.isDirectory ? 0 : (attrs.size?.toInt() ?? item.size),
        modified: attrs.modifyTime != null
            ? DateTime.fromMillisecondsSinceEpoch(attrs.modifyTime! * 1000)
            : item.modified,
        accessed: attrs.accessTime != null
            ? DateTime.fromMillisecondsSinceEpoch(attrs.accessTime! * 1000)
            : null,
        permissions: attrs.mode != null
            ? _formatSftpPermissions(attrs.mode!)
            : null,
        modeBits: attrs.mode != null ? (attrs.mode!.value & 0xFFF) : null,
        ownerUid: attrs.userID,
        ownerGid: attrs.groupID,
        isCalculatingStats: false,
      );
    } catch (e) {
      debugPrint('Error loading remote metadata for ${item.path}: $e');
      return base.copyWith(isCalculatingStats: false);
    }
  }

  /// Starts recursive size & item-count calculation in a background isolate.
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

  static String formatPermissionsFromBits(int bits) {
    final perms = bits & 0xFFF;
    String bitChar(int mask, String ch) => (perms & mask) != 0 ? ch : '-';
    final rwx = [
      bitChar(0x100, 'r'),
      bitChar(0x080, 'w'),
      bitChar(0x040, 'x'),
      bitChar(0x020, 'r'),
      bitChar(0x010, 'w'),
      bitChar(0x008, 'x'),
      bitChar(0x004, 'r'),
      bitChar(0x002, 'w'),
      bitChar(0x001, 'x'),
    ].join();
    final octal = perms.toRadixString(8).padLeft(4, '0');
    return '$rwx ($octal)';
  }

  /// Applies POSIX permission bits (e.g. `0755`) to a local file/directory or
  /// remote SSH SFTP item.
  static Future<void> setPermissions({
    required String path,
    required int modeBits,
    FileSystemRepository? repository,
  }) async {
    final masked = modeBits & 0xFFF;
    if (path.startsWith('ssh://')) {
      if (repository is! CompoundFileSystemRepository) {
        throw StateError('SSH repository not available');
      }
      final connId = RemoteConnection.connectionIdFromSshUrl(path);
      final remotePath = RemoteConnection.remotePathFromSshUrl(path);
      final sftp = repository.sshRepository.getSftpClientFor(connId);
      if (sftp == null) {
        throw StateError('SSH session is not connected: $connId');
      }
      await sftp.setStat(
        remotePath,
        SftpFileAttrs(mode: SftpFileMode.value(masked)),
      );
      return;
    }

    if (Platform.isWindows) {
      throw UnsupportedError('chmod is not supported on Windows');
    }

    final octal = masked.toRadixString(8).padLeft(4, '0');
    final result = await Process.run('chmod', [octal, path]);
    if (result.exitCode != 0) {
      final err = result.stderr.toString().trim();
      throw FileSystemException(
        err.isNotEmpty ? err : 'chmod failed with exit code ${result.exitCode}',
        path,
      );
    }
  }

  /// Calculates total recursive byte size of a single local or in-ZIP directory.
  static Future<int> calculateSingleDirectorySize(String path) async {
    if (path.startsWith('ssh://')) return 0;
    if (isZipPath(path)) {
      final split = splitZipPath(path);
      if (split == null) return 0;
      final zipStats = await compute(_readZipStats, (split.$1, split.$2));
      return zipStats?.$3 ?? 0;
    }
    return compute(_calculateLocalDirectorySize, path);
  }

  /// Calculates MD5 and SHA-256 digests for [filePath] in a background isolate.
  static Future<DirectoryStatsHandle> startChecksumCalculation({
    required String filePath,
    required void Function(FileChecksums? result, String? error) onDone,
  }) async {
    final receivePort = ReceivePort();
    Isolate? isolate;
    bool cancelled = false;

    receivePort.listen((message) {
      if (cancelled) return;
      if (message is Map<String, dynamic>) {
        final error = message['error'] as String?;
        if (error != null) {
          onDone(null, error);
        } else {
          onDone(
            FileChecksums(
              md5Hex: message['md5'] as String,
              sha256Hex: message['sha256'] as String,
            ),
            null,
          );
        }
        receivePort.close();
      }
    });

    try {
      isolate = await Isolate.spawn(_isolateCalculateChecksums, {
        'sendPort': receivePort.sendPort,
        'filePath': filePath,
      });
    } catch (e) {
      receivePort.close();
      onDone(null, e.toString());
    }

    return DirectoryStatsHandle(() {
      cancelled = true;
      isolate?.kill(priority: Isolate.immediate);
      receivePort.close();
    });
  }

  static String _formatLocalPermissions(FileStat stat) {
    final modeStr = stat.modeString();
    final octal = (stat.mode & 0xFFF).toRadixString(8).padLeft(4, '0');
    return '$modeStr ($octal)';
  }

  static String _formatSftpPermissions(SftpFileMode mode) {
    final chars = [
      mode.userRead ? 'r' : '-',
      mode.userWrite ? 'w' : '-',
      mode.userExecute ? 'x' : '-',
      mode.groupRead ? 'r' : '-',
      mode.groupWrite ? 'w' : '-',
      mode.groupExecute ? 'x' : '-',
      mode.otherRead ? 'r' : '-',
      mode.otherWrite ? 'w' : '-',
      mode.otherExecute ? 'x' : '-',
    ].join();
    final octal = (mode.value & 0xFFF).toRadixString(8).padLeft(4, '0');
    return '$chars ($octal)';
  }

  static String _sshParent(String sshUrl) {
    final connId = RemoteConnection.connectionIdFromSshUrl(sshUrl);
    final remotePath = RemoteConnection.remotePathFromSshUrl(sshUrl);
    if (remotePath == '/') return 'ssh://$connId/';
    final lastSlash = remotePath.lastIndexOf('/');
    final parent = lastSlash <= 0 ? '/' : remotePath.substring(0, lastSlash);
    return 'ssh://$connId$parent';
  }
}

(int, int)? _readImageDimensions(String path) {
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
(int, int, int)? _readZipStats((String, String) args) {
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

class _SingleDigestSink implements Sink<Digest> {
  Digest? digest;

  @override
  void add(Digest data) {
    digest = data;
  }

  @override
  void close() {}
}

Future<void> _isolateCalculateChecksums(Map<String, dynamic> args) async {
  final sendPort = args['sendPort'] as SendPort;
  final filePath = args['filePath'] as String;

  try {
    final md5Sink = _SingleDigestSink();
    final shaSink = _SingleDigestSink();
    final md5Input = md5.startChunkedConversion(md5Sink);
    final shaInput = sha256.startChunkedConversion(shaSink);

    final stream = File(filePath).openRead();
    await for (final chunk in stream) {
      md5Input.add(chunk);
      shaInput.add(chunk);
    }

    md5Input.close();
    shaInput.close();

    sendPort.send({
      'md5': md5Sink.digest.toString(),
      'sha256': shaSink.digest.toString(),
    });
  } catch (e) {
    sendPort.send({'error': e.toString()});
  }
}
