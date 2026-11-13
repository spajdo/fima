import 'package:file_icon/file_icon.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:fima/domain/entity/app_theme.dart';
import 'package:fima/infrastructure/service/item_metadata_service.dart';

/// Top icon and title summary displayed inside the item info dialog.
class InfoSummaryHeader extends StatelessWidget {
  final ItemMetadata metadata;
  final FimaTheme fimaTheme;

  const InfoSummaryHeader({
    super.key,
    required this.metadata,
    required this.fimaTheme,
  });

  Widget _buildIcon() {
    if (metadata.isMultiSelection) {
      return Icon(
        Icons.library_books_outlined,
        size: 34,
        color: fimaTheme.accentColor,
      );
    }
    if (metadata.isRemote && metadata.isDirectory) {
      return const Icon(
        Icons.folder_shared_outlined,
        size: 36,
        color: Colors.amber,
      );
    }
    if (metadata.isDirectory) {
      return const FaIcon(
        FontAwesomeIcons.solidFolder,
        size: 34,
        color: Colors.amber,
      );
    }
    if (metadata.isZipArchive) {
      return FaIcon(
        FontAwesomeIcons.fileZipper,
        size: 34,
        color: fimaTheme.accentColor,
      );
    }
    return FileIcon(metadata.name, size: 36);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: 44, height: 44, child: Center(child: _buildIcon())),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                metadata.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: fimaTheme.textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                metadata.kind,
                style: TextStyle(
                  fontSize: 12,
                  color: fimaTheme.secondaryTextColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
