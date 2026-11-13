import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:fima/domain/entity/app_theme.dart';
import 'package:fima/domain/entity/file_system_item.dart';
import 'package:fima/infrastructure/service/item_metadata_service.dart';
import 'package:fima/presentation/providers/file_system_provider.dart';
import 'package:fima/presentation/providers/overlay_provider.dart';
import 'package:fima/presentation/providers/theme_provider.dart';
import 'package:fima/presentation/widgets/popups/info/info_checksums_section.dart';
import 'package:fima/presentation/widgets/popups/info/info_general_section.dart';
import 'package:fima/presentation/widgets/popups/info/info_permissions_section.dart';
import 'package:fima/presentation/widgets/popups/info/info_section_card.dart';
import 'package:fima/presentation/widgets/popups/info/info_summary_header.dart';

/// Opens a modal dialog displaying metadata, stats, checksums, and permissions.
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
  late final ScrollController _scrollController;
  String _verifyHashInput = '';
  bool _showPermissionsEditor = false;

  @override
  void initState() {
    super.initState();
    _verifyHashController = TextEditingController();
    _scrollController = ScrollController();
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
    _scrollController.dispose();
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

    setState(() => _metadata = detailed);

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

  void _onPermissionsApplied(int newBits) {
    final formatted = ItemMetadataService.formatPermissionsFromBits(newBits);
    setState(() {
      _metadata = _metadata.copyWith(
        modeBits: newBits,
        permissions: formatted,
        isReadOnly: (newBits & 0x92) == 0,
      );
    });
    ref
        .read(overlayProvider.notifier)
        .showToast('Permissions updated: $formatted');
  }

  Widget _buildTitleBar(FimaTheme fimaTheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: fimaTheme.surfaceColor,
        border: Border(bottom: BorderSide(color: fimaTheme.borderColor)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 17, color: fimaTheme.accentColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _metadata.isMultiSelection
                  ? 'Info — ${_metadata.selectedCount} Items'
                  : 'Info — ${_metadata.name}',
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
    );
  }

  Widget _buildTimestampsSection(FimaTheme fimaTheme) {
    return InfoSectionCard(
      title: 'TIMESTAMPS',
      theme: fimaTheme,
      children: [
        if (_metadata.modified != null)
          InfoRow(
            label: 'Modified',
            value: _dateTimeFormat.format(_metadata.modified!),
            theme: fimaTheme,
          ),
        if (_metadata.accessed != null)
          InfoRow(
            label: 'Accessed',
            value: _dateTimeFormat.format(_metadata.accessed!),
            theme: fimaTheme,
          ),
        if (_metadata.changed != null)
          InfoRow(
            label: 'Changed',
            value: _dateTimeFormat.format(_metadata.changed!),
            theme: fimaTheme,
          ),
      ],
    );
  }

  Widget _buildFooter(FimaTheme fimaTheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: fimaTheme.surfaceColor,
        border: Border(top: BorderSide(color: fimaTheme.borderColor)),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(9)),
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
              style: TextStyle(fontSize: 12.5, color: fimaTheme.textColor),
            ),
          ),
          const Spacer(),
          FilledButton(
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: fimaTheme.accentColor,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text(
              'Close',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fimaTheme = ref.watch(themeProvider);
    final meta = _metadata;
    final hasDates =
        meta.modified != null || meta.accessed != null || meta.changed != null;
    final hasPermissionsOrOwner =
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
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Container(
          width: 580,
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
              _buildTitleBar(fimaTheme),
              Flexible(
                child: Scrollbar(
                  controller: _scrollController,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InfoSummaryHeader(metadata: meta, fimaTheme: fimaTheme),
                        const SizedBox(height: 16),
                        InfoGeneralSection(
                          metadata: meta,
                          fimaTheme: fimaTheme,
                          intFormat: _intFormat,
                        ),
                        if (hasDates) ...[
                          const SizedBox(height: 12),
                          _buildTimestampsSection(fimaTheme),
                        ],
                        if (!meta.isMultiSelection &&
                            !meta.isDirectory &&
                            !meta.isRemote &&
                            !meta.isInsideZip) ...[
                          const SizedBox(height: 12),
                          InfoChecksumsSection(
                            fimaTheme: fimaTheme,
                            checksums: _checksums,
                            isCalculating: _isCalculatingChecksums,
                            error: _checksumError,
                            verifyHashController: _verifyHashController,
                            verifyHashInput: _verifyHashInput,
                            onCalculate: _calculateChecksums,
                            onCopyHash: _copyHash,
                            onVerifyInputChanged: (value) =>
                                setState(() => _verifyHashInput = value),
                          ),
                        ],
                        if (hasPermissionsOrOwner) ...[
                          const SizedBox(height: 12),
                          InfoPermissionsSection(
                            metadata: meta,
                            fimaTheme: fimaTheme,
                            showPermissionsEditor: _showPermissionsEditor,
                            onToggleEditor: () => setState(
                              () => _showPermissionsEditor =
                                  !_showPermissionsEditor,
                            ),
                            onPermissionsApplied: _onPermissionsApplied,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              _buildFooter(fimaTheme),
            ],
          ),
        ),
      ),
    );
  }
}
