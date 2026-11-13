import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:fima/domain/entity/app_theme.dart';
import 'package:fima/domain/utils/file_size_formatter.dart';
import 'package:fima/infrastructure/service/item_metadata_service.dart';
import 'package:fima/presentation/widgets/popups/info/info_section_card.dart';

/// Displays general item properties (kind, size, contents, location, dimensions).
class InfoGeneralSection extends StatelessWidget {
  final ItemMetadata metadata;
  final FimaTheme fimaTheme;
  final NumberFormat intFormat;

  const InfoGeneralSection({
    super.key,
    required this.metadata,
    required this.fimaTheme,
    required this.intFormat,
  });

  String _formatBytesWithExact(int bytes) {
    return FileSizeFormatter.formatWithExact(
      bytes,
      exactFormatter: intFormat.format,
    );
  }

  String _formatContains(ItemMetadata meta) {
    final files = meta.fileCount ?? 0;
    final folders = meta.folderCount ?? 0;
    final fileWord = files == 1 ? 'file' : 'files';
    final folderWord = folders == 1 ? 'folder' : 'folders';
    return '${intFormat.format(files)} $fileWord, ${intFormat.format(folders)} $folderWord';
  }

  String _formatCompressionRatio(int compressed, int uncompressed) {
    if (uncompressed <= 0) return '0%';
    final saved = ((1 - (compressed / uncompressed)) * 100).clamp(-999, 100);
    return '${saved.toStringAsFixed(1)}% saved';
  }

  Widget _buildSizeRow() {
    final int? effectiveSize =
        (metadata.isDirectory || metadata.isMultiSelection)
        ? metadata.totalSizeBytes
        : metadata.sizeBytes;

    if (effectiveSize == null && metadata.isCalculatingStats) {
      return InfoRowWidget(
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
      return InfoRow(label: 'Size', value: '—', theme: fimaTheme);
    }

    final valueText = metadata.isCalculatingStats
        ? '${_formatBytesWithExact(effectiveSize)} (calculating...)'
        : _formatBytesWithExact(effectiveSize);

    return InfoRow(label: 'Size', value: valueText, theme: fimaTheme);
  }

  Widget _buildContainsRow() {
    if (metadata.fileCount == null && metadata.folderCount == null) {
      if (metadata.isCalculatingStats) {
        return InfoRow(
          label: 'Contains',
          value: 'Scanning...',
          theme: fimaTheme,
        );
      }
      return const SizedBox.shrink();
    }
    return InfoRow(
      label: 'Contains',
      value: _formatContains(metadata),
      theme: fimaTheme,
    );
  }

  @override
  Widget build(BuildContext context) {
    return InfoSectionCard(
      title: 'GENERAL',
      theme: fimaTheme,
      children: [
        InfoRow(label: 'Kind', value: metadata.kind, theme: fimaTheme),
        _buildSizeRow(),
        if (metadata.fileCount != null ||
            metadata.folderCount != null ||
            metadata.isDirectory ||
            metadata.isZipArchive ||
            metadata.isMultiSelection)
          _buildContainsRow(),
        if (metadata.isZipArchive && metadata.zipUncompressedSize != null)
          InfoRow(
            label: 'Uncompressed',
            value:
                '${_formatBytesWithExact(metadata.zipUncompressedSize!)} '
                '(${_formatCompressionRatio(metadata.sizeBytes, metadata.zipUncompressedSize!)})',
            theme: fimaTheme,
          ),
        if (metadata.imageDimensions != null)
          InfoRow(
            label: 'Dimensions',
            value:
                '${metadata.imageDimensions!.$1} × ${metadata.imageDimensions!.$2} px',
            theme: fimaTheme,
          ),
        InfoRow(
          label: 'Location',
          value: metadata.parentPath,
          theme: fimaTheme,
        ),
        if (!metadata.isMultiSelection)
          InfoRow(label: 'Path', value: metadata.path, theme: fimaTheme),
        if (metadata.symlinkTarget != null)
          InfoRow(
            label: 'Target',
            value: metadata.symlinkTarget!,
            theme: fimaTheme,
          ),
      ],
    );
  }
}
