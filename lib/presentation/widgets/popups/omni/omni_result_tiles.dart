import 'package:flutter/material.dart';

import 'package:fima/domain/entity/app_theme.dart';
import 'package:fima/presentation/widgets/popups/omni/omni_models.dart';

/// Standard single-line row used for path and action search results.
class OmniSimpleTile extends StatelessWidget {
  final String label;
  final String? shortcut;
  final bool isSelected;
  final FimaTheme fimaTheme;
  final VoidCallback onTap;

  const OmniSimpleTile({
    super.key,
    required this.label,
    this.shortcut,
    required this.isSelected,
    required this.fimaTheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: isSelected ? fimaTheme.accentColor.withValues(alpha: 0.1) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: fimaTheme.textColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (shortcut != null)
              Text(
                shortcut!,
                style: TextStyle(
                  fontSize: 12,
                  color: fimaTheme.secondaryTextColor,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Reusable result row with inline Edit and Delete actions (used by workspaces,
/// bookmarks, and remote connections).
class OmniManageableTile extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final Color iconColor;
  final String title;
  final double titleFontSize;
  final String? subtitle;
  final String editTooltip;
  final bool isSelected;
  final WorkspaceAction focusedAction;
  final FimaTheme fimaTheme;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const OmniManageableTile({
    super.key,
    required this.icon,
    this.iconSize = 24,
    required this.iconColor,
    required this.title,
    this.titleFontSize = 14,
    this.subtitle,
    this.editTooltip = 'Rename',
    required this.isSelected,
    required this.focusedAction,
    required this.fimaTheme,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: isSelected ? fimaTheme.accentColor.withValues(alpha: 0.1) : null,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: iconSize, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: subtitle == null
                  ? Text(
                      title,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: titleFontSize,
                        color: fimaTheme.textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: titleFontSize,
                            color: fimaTheme.textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 11,
                            color: fimaTheme.secondaryTextColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _OmniActionButton(
                  icon: Icons.edit,
                  tooltip: editTooltip,
                  isFocused: focusedAction == WorkspaceAction.edit,
                  fimaTheme: fimaTheme,
                  onTap: onEdit,
                ),
                const SizedBox(width: 8),
                _OmniActionButton(
                  icon: Icons.delete,
                  tooltip: 'Delete',
                  isFocused: focusedAction == WorkspaceAction.delete,
                  fimaTheme: fimaTheme,
                  onTap: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OmniActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isFocused;
  final FimaTheme fimaTheme;
  final VoidCallback onTap;

  const _OmniActionButton({
    required this.icon,
    required this.tooltip,
    required this.isFocused,
    required this.fimaTheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isFocused ? fimaTheme.accentColor : Colors.transparent,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 20,
            color: isFocused ? Colors.white : fimaTheme.secondaryTextColor,
          ),
        ),
      ),
    );
  }
}
