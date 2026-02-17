import 'package:flutter/material.dart';

class PanelOverlay extends StatelessWidget {
  final Widget child;
  final VoidCallback? onOk;
  final VoidCallback? onCancel;
  final VoidCallback? onApply;
  final bool hasChanges;
  final double width;
  final double height;

  const PanelOverlay({
    super.key,
    required this.child,
    required this.width,
    required this.height,
    this.onOk,
    this.onCancel,
    this.onApply,
    this.hasChanges = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          border: Border.all(color: theme.colorScheme.primary, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          children: [
            Expanded(child: child),
            _buildFooter(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FilledButton(
            onPressed: hasChanges ? onOk : null,
            child: const Text('OK'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: onCancel, child: const Text('Cancel')),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: hasChanges ? onApply : null,
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
