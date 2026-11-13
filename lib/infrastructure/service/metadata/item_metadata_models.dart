import 'dart:io';

import 'package:flutter/foundation.dart';

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
