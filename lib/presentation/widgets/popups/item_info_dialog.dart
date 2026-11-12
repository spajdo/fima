import 'package:file_icon/file_icon.dart';
import 'package:fima/domain/entity/app_theme.dart';
import 'package:fima/domain/entity/file_system_item.dart';
import 'package:fima/infrastructure/service/item_metadata_service.dart';
import 'package:fima/presentation/providers/file_system_provider.dart';
import 'package:fima/presentation/providers/overlay_provider.dart';
import 'package:fima/presentation/providers/theme_provider.dart';
import 'package:fima/presentation/widgets/popups/permissions_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

Future<void> showItemInfoDialog(
  BuildContext context, {
  required List<FileSystemItem> items,
  required String currentPath,
}) {
  if (items.isEmpty) return Future.value();
  return showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (context) =>
        ItemInfoDialog(items: items, currentPath: currentPath),
  );
}

class ItemInfoDialog extends ConsumerStatefulWidget {
  final List<FileSystemItem> items;
  final String currentPath;

  const ItemInfoDialog({
    super.key,
    required this.items,
    required this.currentPath,
  });

  @override
  ConsumerState<ItemInfoDialog> createState() => _ItemInfoDialogState();
}

class _ItemInfoDialogState extends ConsumerState<ItemInfoDialog> {
  static final DateFormat _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  static final NumberFormat _intFormat = NumberFormat('#,###');

  late ItemMetadata _metadata;
  DirectoryStatsHandle? _statsHandle;
  DirectoryStatsHandle? _checksumHandle;
  FileChecksums? _checksums;
  bool _isCalculatingChecksums = false;
  String? _checksumError;
  late final TextEditingController _verifyHashController;
  String _verifyHashInput = '';
  bool _showPermissionsEditor = false;

  @override
  void initState() {
    super.initState();
    _verifyHashController = TextEditingController();
    _metadata = ItemMetadataService.buildInitialMetadata(
      items: widget.items,
      currentPath: widget.currentPath,
    );
    _loadMetadata();
  }

  @override
  void dispose() {
    _statsHandle?.cancel();
    _checksumHandle?.cancel();
    _verifyHashController.dispose();
    super.dispose();
  }

  Future<void> _calculateChecksums() async {
    if (_isCalculatingChecksums) return;
    setState(() {
      _isCalculatingChecksums = true;
      _checksumError = null;
    });

    _checksumHandle?.cancel();
    _checksumHandle = await ItemMetadataService.startChecksumCalculation(
      filePath: _metadata.path,
      onDone: (result, error) {
        if (!mounted) return;
        setState(() {
          _isCalculatingChecksums = false;
          _checksums = result;
          _checksumError = error;
        });
      },
    );
  }

  void _copyHash(String label, String hashValue) {
    Clipboard.setData(ClipboardData(text: hashValue));
    ref.read(overlayProvider.notifier).showToast('$label copied');
  }

  Future<void> _loadMetadata() async {
    final repository = ref.read(fileSystemRepositoryProvider);
    final detailed = await ItemMetadataService.loadDetails(
      items: widget.items,
      currentPath: widget.currentPath,
      repository: repository,
    );
    if (!mounted) return;

    setState(() {
      _metadata = detailed;
    });

    final shouldScanDirs =
        !detailed.isRemote &&
        !detailed.isInsideZip &&
        ((detailed.isMultiSelection && detailed.isCalculatingStats) ||
            (!detailed.isMultiSelection && detailed.isDirectory));

    if (shouldScanDirs) {
      final pathsToScan = widget.items.map((item) => item.path).toList();
      _statsHandle = await ItemMetadataService.calculateDirectoryStats(
        paths: pathsToScan,
        onProgress: (files, folders, totalBytes, isDone) {
          if (!mounted) return;
          setState(() {
            _metadata = _metadata.copyWith(
              fileCount: files,
              folderCount: folders,
              totalSizeBytes: totalBytes,
              sizeBytes: detailed.isMultiSelection ? totalBytes : 0,
              isCalculatingStats: !isDone,
            );
          });
        },
      );
    }
  }

  String _formatBytesWithExact(int bytes) {
    final human = _formatBytes(bytes);
    if (bytes < 1024) return human;
    return '$human (${_intFormat.format(bytes)} bytes)';
  }

  String _formatBytes(int bytes) {
    if (bytes < 0) return 'N/A';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _formatContains(ItemMetadata meta) {
    final files = meta.fileCount ?? 0;
    final folders = meta.folderCount ?? 0;
    final fileWord = files == 1 ? 'file' : 'files';
    final folderWord = folders == 1 ? 'folder' : 'folders';
    return '${_intFormat.format(files)} $fileWord, ${_intFormat.format(folders)} $folderWord';
  }

  String _formatCompressionRatio(int compressed, int uncompressed) {
    if (uncompressed <= 0) return '0%';
    final saved = ((1 - (compressed / uncompressed)) * 100).clamp(-999, 100);
    return '${saved.toStringAsFixed(1)}% saved';
  }

  void _copyPath() {
    final text = widget.items.length > 1
        ? widget.items.map((item) => item.path).join('\n')
        : _metadata.path;
    Clipboard.setData(ClipboardData(text: text));
    ref
        .read(overlayProvider.notifier)
        .showToast(
          widget.items.length > 1
              ? 'Copied ${widget.items.length} paths'
              : 'Path copied: $text',
        );
  }

  Widget _buildHeaderIcon(FimaTheme fimaTheme) {
    if (_metadata.isMultiSelection) {
      return Icon(
        Icons.library_books_outlined,
        size: 34,
        color: fimaTheme.accentColor,
      );
    }
    if (_metadata.isRemote && _metadata.isDirectory) {
      return Icon(Icons.folder_shared_outlined, size: 36, color: Colors.amber);
    }
    if (_metadata.isDirectory) {
      return const FaIcon(
        FontAwesomeIcons.solidFolder,
        size: 34,
        color: Colors.amber,
      );
    }
    if (_metadata.isZipArchive) {
      return FaIcon(
        FontAwesomeIcons.fileZipper,
        size: 34,
        color: fimaTheme.accentColor,
      );
    }
    return FileIcon(_metadata.name, size: 36);
  }

  List<String> _buildAttributeLabels(ItemMetadata meta) {
    final labels = <String>[];
    if (meta.isSymlink) labels.add('Symbolic Link');
    if (meta.isHidden) labels.add('Hidden');
    if (meta.isReadOnly) labels.add('Read-only');
    if (meta.isInsideZip) labels.add('Inside ZIP');
    if (meta.isRemote) labels.add('Remote (SFTP)');
    if (labels.isEmpty) labels.add('Normal');
    return labels;
  }

  @override
  Widget build(BuildContext context) {
    final fimaTheme = ref.watch(themeProvider);
    final meta = _metadata;
    final attributes = _buildAttributeLabels(meta);

    final bool hasDates =
        meta.modified != null || meta.accessed != null || meta.changed != null;
    final bool hasPermissionsOrOwner =
        meta.permissions != null ||
        meta.ownerUid != null ||
        !meta.isMultiSelection;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          width: 520,
          constraints: const BoxConstraints(maxHeight: 680),
          decoration: BoxDecoration(
            color: fimaTheme.backgroundColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: fimaTheme.borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: fimaTheme.surfaceColor,
                  border: Border(
                    bottom: BorderSide(color: fimaTheme.borderColor),
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(9),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 17,
                      color: fimaTheme.accentColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        meta.isMultiSelection
                            ? 'Info — ${meta.selectedCount} Items'
                            : 'Info — ${meta.name}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: fimaTheme.textColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 16,
                        color: fimaTheme.secondaryTextColor,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 16,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Hero summary row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: Center(child: _buildHeaderIcon(fimaTheme)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SelectableText(
                                  meta.name,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: fimaTheme.textColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  meta.kind,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: fimaTheme.secondaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // General section
                      _SectionCard(
                        title: 'GENERAL',
                        theme: fimaTheme,
                        children: [
                          _InfoRow(
                            label: 'Kind',
                            value: meta.kind,
                            theme: fimaTheme,
                          ),
                          _buildSizeRow(meta, fimaTheme),
                          if (meta.fileCount != null ||
                              meta.folderCount != null ||
                              meta.isDirectory ||
                              meta.isZipArchive ||
                              meta.isMultiSelection)
                            _buildContainsRow(meta, fimaTheme),
                          if (meta.isZipArchive &&
                              meta.zipUncompressedSize != null)
                            _InfoRow(
                              label: 'Uncompressed',
                              value:
                                  '${_formatBytesWithExact(meta.zipUncompressedSize!)} '
                                  '(${_formatCompressionRatio(meta.sizeBytes, meta.zipUncompressedSize!)})',
                              theme: fimaTheme,
                            ),
                          if (meta.imageDimensions != null)
                            _InfoRow(
                              label: 'Dimensions',
                              value:
                                  '${meta.imageDimensions!.$1} × ${meta.imageDimensions!.$2} px',
                              theme: fimaTheme,
                            ),
                          _InfoRow(
                            label: 'Location',
                            value: meta.parentPath,
                            theme: fimaTheme,
                          ),
                          if (!meta.isMultiSelection)
                            _InfoRow(
                              label: 'Path',
                              value: meta.path,
                              theme: fimaTheme,
                            ),
                          if (meta.symlinkTarget != null)
                            _InfoRow(
                              label: 'Target',
                              value: meta.symlinkTarget!,
                              theme: fimaTheme,
                            ),
                        ],
                      ),

                      if (hasDates) ...[
                        const SizedBox(height: 12),
                        _SectionCard(
                          title: 'TIMESTAMPS',
                          theme: fimaTheme,
                          children: [
                            if (meta.modified != null)
                              _InfoRow(
                                label: 'Modified',
                                value: _dateTimeFormat.format(meta.modified!),
                                theme: fimaTheme,
                              ),
                            if (meta.accessed != null)
                              _InfoRow(
                                label: 'Accessed',
                                value: _dateTimeFormat.format(meta.accessed!),
                                theme: fimaTheme,
                              ),
                            if (meta.changed != null)
                              _InfoRow(
                                label: 'Changed',
                                value: _dateTimeFormat.format(meta.changed!),
                                theme: fimaTheme,
                              ),
                          ],
                        ),
                      ],

                      if (!meta.isMultiSelection &&
                          !meta.isDirectory &&
                          !meta.isRemote &&
                          !meta.isInsideZip) ...[
                        const SizedBox(height: 12),
                        _buildChecksumsSection(fimaTheme),
                      ],

                      if (hasPermissionsOrOwner) ...[
                        const SizedBox(height: 12),
                        _SectionCard(
                          title: 'PERMISSIONS & ATTRIBUTES',
                          theme: fimaTheme,
                          children: [
                            if (meta.permissions != null)
                              _InfoRowWidget(
                                label: 'Permissions',
                                theme: fimaTheme,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: SelectableText(
                                        meta.permissions!,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontFamily: 'monospace',
                                          color: fimaTheme.textColor,
                                        ),
                                      ),
                                    ),
                                    if (meta.canEditPermissions &&
                                        meta.modeBits != null)
                                      TextButton(
                                        onPressed: () {
                                          setState(() {
                                            _showPermissionsEditor =
                                                !_showPermissionsEditor;
                                          });
                                        },
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: Text(
                                          _showPermissionsEditor
                                              ? 'Hide Editor'
                                              : 'Edit...',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: fimaTheme.accentColor,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            if (_showPermissionsEditor &&
                                meta.canEditPermissions &&
                                meta.modeBits != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: fimaTheme.backgroundColor,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: fimaTheme.borderColor,
                                  ),
                                ),
                                child: PosixPermissionsEditor(
                                  itemPath: meta.path,
                                  initialModeBits: meta.modeBits!,
                                  onApplied: (newBits) {
                                    setState(() {
                                      _metadata = _metadata.copyWith(
                                        modeBits: newBits,
                                        permissions:
                                            ItemMetadataService.formatPermissionsFromBits(
                                              newBits,
                                            ),
                                        isReadOnly: (newBits & 0x92) == 0,
                                      );
                                    });
                                    ref
                                        .read(overlayProvider.notifier)
                                        .showToast(
                                          'Permissions updated: ${ItemMetadataService.formatPermissionsFromBits(newBits)}',
                                        );
                                  },
                                ),
                              ),
                              const SizedBox(height: 6),
                            ],
                            if (meta.ownerUid != null || meta.ownerGid != null)
                              _InfoRow(
                                label: 'Owner',
                                value:
                                    'UID ${meta.ownerUid ?? '-'} / GID ${meta.ownerGid ?? '-'}',
                                theme: fimaTheme,
                              ),
                            _InfoRow(
                              label: 'Attributes',
                              value: attributes.join(' · '),
                              theme: fimaTheme,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: fimaTheme.surfaceColor,
                  border: Border(top: BorderSide(color: fimaTheme.borderColor)),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(9),
                  ),
                ),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: _copyPath,
                      icon: Icon(
                        Icons.copy,
                        size: 14,
                        color: fimaTheme.secondaryTextColor,
                      ),
                      label: Text(
                        widget.items.length > 1 ? 'Copy Paths' : 'Copy Path',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: fimaTheme.textColor,
                        ),
                      ),
                    ),
                    const Spacer(),
                    FilledButton(
                      autofocus: true,
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: fimaTheme.accentColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSizeRow(ItemMetadata meta, FimaTheme fimaTheme) {
    final int? effectiveSize = (meta.isDirectory || meta.isMultiSelection)
        ? meta.totalSizeBytes
        : meta.sizeBytes;

    if (effectiveSize == null && meta.isCalculatingStats) {
      return _InfoRowWidget(
        label: 'Size',
        theme: fimaTheme,
        child: Row(
          children: [
            SizedBox(
              width: 11,
              height: 11,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                color: fimaTheme.accentColor,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Calculating...',
              style: TextStyle(
                fontSize: 12.5,
                color: fimaTheme.secondaryTextColor,
              ),
            ),
          ],
        ),
      );
    }

    if (effectiveSize == null) {
      return _InfoRow(label: 'Size', value: '—', theme: fimaTheme);
    }

    final valueText = meta.isCalculatingStats
        ? '${_formatBytesWithExact(effectiveSize)} (calculating...)'
        : _formatBytesWithExact(effectiveSize);

    return _InfoRow(label: 'Size', value: valueText, theme: fimaTheme);
  }

  Widget _buildContainsRow(ItemMetadata meta, FimaTheme fimaTheme) {
    if (meta.fileCount == null && meta.folderCount == null) {
      if (meta.isCalculatingStats) {
        return _InfoRow(
          label: 'Contains',
          value: 'Scanning...',
          theme: fimaTheme,
        );
      }
      return const SizedBox.shrink();
    }
    return _InfoRow(
      label: 'Contains',
      value: _formatContains(meta),
      theme: fimaTheme,
    );
  }

  Widget _buildChecksumsSection(FimaTheme fimaTheme) {
    final checksums = _checksums;
    final verifyQuery = _verifyHashInput.trim().toLowerCase();
    String? verifyStatusText;
    Color? verifyStatusColor;
    if (checksums != null && verifyQuery.isNotEmpty) {
      if (verifyQuery == checksums.md5Hex.toLowerCase()) {
        verifyStatusText = 'Matches MD5';
        verifyStatusColor = Colors.green;
      } else if (verifyQuery == checksums.sha256Hex.toLowerCase()) {
        verifyStatusText = 'Matches SHA-256';
        verifyStatusColor = Colors.green;
      } else {
        verifyStatusText = 'Does not match';
        verifyStatusColor = Colors.redAccent;
      }
    }

    return _SectionCard(
      title: 'CHECKSUMS',
      theme: fimaTheme,
      children: [
        if (checksums == null && !_isCalculatingChecksums)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _calculateChecksums,
              icon: Icon(
                Icons.fingerprint,
                size: 15,
                color: fimaTheme.accentColor,
              ),
              label: Text(
                'Calculate MD5 & SHA-256',
                style: TextStyle(fontSize: 12, color: fimaTheme.textColor),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: fimaTheme.borderColor),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                minimumSize: const Size(0, 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        if (_isCalculatingChecksums)
          Row(
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: fimaTheme.accentColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Calculating MD5 & SHA-256...',
                style: TextStyle(
                  fontSize: 12.5,
                  color: fimaTheme.secondaryTextColor,
                ),
              ),
            ],
          ),
        if (_checksumError != null) ...[
          const SizedBox(height: 6),
          Text(
            _checksumError!,
            style: const TextStyle(fontSize: 12, color: Colors.redAccent),
          ),
        ],
        if (checksums != null) ...[
          _buildHashRow('MD5', checksums.md5Hex, fimaTheme),
          _buildHashRow('SHA-256', checksums.sha256Hex, fimaTheme),
          const SizedBox(height: 8),
          _InfoRowWidget(
            label: 'Verify Hash',
            theme: fimaTheme,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _verifyHashController,
                  onChanged: (value) {
                    setState(() {
                      _verifyHashInput = value;
                    });
                  },
                  style: TextStyle(
                    fontSize: 11.5,
                    fontFamily: 'monospace',
                    color: fimaTheme.textColor,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Paste expected MD5 or SHA-256 hash...',
                    hintStyle: TextStyle(
                      fontSize: 11.5,
                      fontFamily: null,
                      color: fimaTheme.secondaryTextColor,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 7,
                    ),
                    filled: true,
                    fillColor: fimaTheme.backgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: BorderSide(color: fimaTheme.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: BorderSide(
                        color: verifyStatusColor ?? fimaTheme.borderColor,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: BorderSide(
                        color: verifyStatusColor ?? fimaTheme.accentColor,
                      ),
                    ),
                  ),
                ),
                if (verifyStatusText != null && verifyStatusColor != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        verifyStatusColor == Colors.green
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        size: 13,
                        color: verifyStatusColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        verifyStatusText,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: verifyStatusColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHashRow(String label, String hashValue, FimaTheme fimaTheme) {
    return _InfoRowWidget(
      label: label,
      theme: fimaTheme,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SelectableText(
              hashValue,
              style: TextStyle(
                fontSize: 11.5,
                fontFamily: 'monospace',
                color: fimaTheme.textColor,
              ),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: () => _copyHash(label, hashValue),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                Icons.copy,
                size: 13,
                color: fimaTheme.secondaryTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final FimaTheme theme;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.theme,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.borderColor.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
              color: theme.secondaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final FimaTheme theme;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return _InfoRowWidget(
      label: label,
      theme: theme,
      child: SelectableText(
        value,
        style: TextStyle(fontSize: 12.5, color: theme.textColor),
      ),
    );
  }
}

class _InfoRowWidget extends StatelessWidget {
  final String label;
  final FimaTheme theme;
  final Widget child;

  const _InfoRowWidget({
    required this.label,
    required this.theme,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: theme.secondaryTextColor),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}
