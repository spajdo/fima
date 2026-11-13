import 'package:flutter/material.dart';

import 'package:fima/domain/entity/app_theme.dart';
import 'package:fima/infrastructure/service/item_metadata_service.dart';
import 'package:fima/presentation/widgets/popups/info/info_section_card.dart';
import 'package:fima/presentation/widgets/popups/permissions_dialog.dart';

/// Displays POSIX permissions (with inline editor), owner IDs, and attributes.
class InfoPermissionsSection extends StatelessWidget {
  final ItemMetadata metadata;
  final FimaTheme fimaTheme;
  final bool showPermissionsEditor;
  final VoidCallback onToggleEditor;
  final ValueChanged<int> onPermissionsApplied;

  const InfoPermissionsSection({
    super.key,
    required this.metadata,
    required this.fimaTheme,
    required this.showPermissionsEditor,
    required this.onToggleEditor,
    required this.onPermissionsApplied,
  });

  List<String> _buildAttributeLabels() {
    final labels = <String>[];
    if (metadata.isSymlink) labels.add('Symbolic Link');
    if (metadata.isHidden) labels.add('Hidden');
    if (metadata.isReadOnly) labels.add('Read-only');
    if (metadata.isInsideZip) labels.add('Inside ZIP');
    if (metadata.isRemote) labels.add('Remote (SFTP)');
    if (labels.isEmpty) labels.add('Normal');
    return labels;
  }

  @override
  Widget build(BuildContext context) {
    final attributes = _buildAttributeLabels();

    return InfoSectionCard(
      title: 'PERMISSIONS & ATTRIBUTES',
      theme: fimaTheme,
      children: [
        if (metadata.permissions != null)
          InfoRowWidget(
            label: 'Permissions',
            theme: fimaTheme,
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    metadata.permissions!,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontFamily: 'monospace',
                      color: fimaTheme.textColor,
                    ),
                  ),
                ),
                if (metadata.canEditPermissions && metadata.modeBits != null)
                  TextButton(
                    onPressed: onToggleEditor,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      showPermissionsEditor ? 'Hide Editor' : 'Edit...',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: fimaTheme.accentColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (showPermissionsEditor &&
            metadata.canEditPermissions &&
            metadata.modeBits != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: fimaTheme.backgroundColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: fimaTheme.borderColor),
            ),
            child: PosixPermissionsEditor(
              itemPath: metadata.path,
              initialModeBits: metadata.modeBits!,
              onApplied: onPermissionsApplied,
            ),
          ),
          const SizedBox(height: 6),
        ],
        if (metadata.ownerUid != null || metadata.ownerGid != null)
          InfoRow(
            label: 'Owner',
            value:
                'UID ${metadata.ownerUid ?? '-'} / GID ${metadata.ownerGid ?? '-'}',
            theme: fimaTheme,
          ),
        InfoRow(
          label: 'Attributes',
          value: attributes.join(' · '),
          theme: fimaTheme,
        ),
      ],
    );
  }
}
