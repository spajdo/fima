import 'package:flutter/material.dart';

import 'package:fima/domain/entity/app_theme.dart';

/// Bordered card grouping labeled rows inside the item info dialog.
class InfoSectionCard extends StatelessWidget {
  final String title;
  final FimaTheme theme;
  final List<Widget> children;

  const InfoSectionCard({
    super.key,
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

/// Key-value row displaying selectable text in [InfoSectionCard].
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final FimaTheme theme;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return InfoRowWidget(
      label: label,
      theme: theme,
      child: SelectableText(
        value,
        style: TextStyle(fontSize: 12.5, color: theme.textColor),
      ),
    );
  }
}

/// Key-value row displaying a custom widget child in [InfoSectionCard].
class InfoRowWidget extends StatelessWidget {
  final String label;
  final FimaTheme theme;
  final Widget child;

  const InfoRowWidget({
    super.key,
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
