import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:fima/domain/entity/file_system_item.dart';
import 'package:fima/domain/entity/remote_connection.dart';
import 'package:fima/domain/repository/file_system_repository.dart';
import 'package:fima/domain/utils/fima_path.dart';
import 'package:fima/infrastructure/repository/compound_file_system_repository.dart';
import 'package:fima/infrastructure/service/metadata/directory_stats_calculator.dart';
import 'package:fima/infrastructure/service/metadata/file_checksum_service.dart';
import 'package:fima/infrastructure/service/metadata/file_kind_descriptor.dart';
import 'package:fima/infrastructure/service/metadata/item_metadata_models.dart';
import 'package:fima/infrastructure/service/metadata/posix_permissions_service.dart';

export 'package:fima/infrastructure/service/metadata/item_metadata_models.dart';

/// Facade coordinating metadata inspection, directory size calculation,
/// POSIX permissions updates, and checksum verification across local,
/// ZIP, and SSH items.
class ItemMetadataService {
  static bool isZipPath(String path) => FimaPath.isZipPath(path);

  static (String, String)? splitZipPath(String path) =>
      FimaPath.extractZipParts(path);

  static String describeKind(
    String name, {
    required bool isDirectory,
    bool isSymlink = false,
    bool isRemote = false,
    bool isInsideZip = false,
  }) => FileKindDescriptor.describeKind(
    name,
    isDirectory: isDirectory,
    isSymlink: isSymlink,
    isRemote: isRemote,
    isInsideZip: isInsideZip,
  );

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
      final isRemote = FimaPath.isSshPath(currentPath);
      final isInsideZip = !isRemote && FimaPath.isZipPath(currentPath);
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
    final isRemote = FimaPath.isSshPath(item.path);
    final zipSplit = !isRemote ? FimaPath.extractZipParts(item.path) : null;
    final isZipArchive =
        !isRemote &&
        !item.isDirectory &&
        item.name.toLowerCase().endsWith('.zip') &&
        (zipSplit == null || zipSplit.$2.isEmpty);
    final isInsideZip = zipSplit != null && zipSplit.$2.isNotEmpty;

    return ItemMetadata(
      name: item.name,
      path: item.path,
      parentPath: FimaPath.dirname(item.path),
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

    if (items.length > 1) return base;

    final item = items.first;
    if (base.isRemote) return _loadRemoteDetails(base, item, repository);
    if (base.isInsideZip) return _loadInsideZipDetails(base, item);
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
      final permissions = PosixPermissionsService.formatLocal(stat);
      final isReadOnly = !Platform.isWindows && (stat.mode & 0x92) == 0;

      (int, int)? imageDims;
      final ext = p.extension(item.name).toLowerCase();
      if (!isDir &&
          DirectoryStatsCalculator.imageExtensions.contains(ext) &&
          stat.size > 0 &&
          stat.size <= DirectoryStatsCalculator.maxImageDimensionCheckBytes) {
        imageDims = await DirectoryStatsCalculator.readImageDimensions(
          item.path,
        );
      }

      int? zipFiles;
      int? zipFolders;
      int? zipUncompressed;
      if (base.isZipArchive) {
        final zipStats = await DirectoryStatsCalculator.readZipStats(
          item.path,
          '',
        );
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
    final split = FimaPath.extractZipParts(item.path);
    if (split == null) return base.copyWith(isCalculatingStats: false);

    final zipStats = await DirectoryStatsCalculator.readZipStats(
      split.$1,
      split.$2,
    );
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
            ? PosixPermissionsService.formatSftp(attrs.mode!)
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

  static Future<DirectoryStatsHandle> calculateDirectoryStats({
    required List<String> paths,
    required void Function(int files, int folders, int totalBytes, bool isDone)
    onProgress,
  }) => DirectoryStatsCalculator.calculateDirectoryStats(
    paths: paths,
    onProgress: onProgress,
  );

  static String formatPermissionsFromBits(int bits) =>
      PosixPermissionsService.formatFromBits(bits);

  static Future<void> setPermissions({
    required String path,
    required int modeBits,
    FileSystemRepository? repository,
  }) => PosixPermissionsService.setPermissions(
    path: path,
    modeBits: modeBits,
    repository: repository,
  );

  static Future<int> calculateSingleDirectorySize(String path) =>
      DirectoryStatsCalculator.calculateSingleDirectorySize(path);

  static Future<DirectoryStatsHandle> startChecksumCalculation({
    required String filePath,
    required void Function(FileChecksums? result, String? error) onDone,
  }) =>
      FileChecksumService.startCalculation(filePath: filePath, onDone: onDone);
}
