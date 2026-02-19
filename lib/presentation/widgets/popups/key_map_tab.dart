import 'package:fima/domain/entity/key_map_action.dart';
import 'package:fima/presentation/providers/settings_provider.dart';
import 'package:fima/presentation/widgets/popups/shortcut_recorder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class KeyMapTab extends ConsumerWidget {
  final VoidCallback? onShortcutChanged;

  const KeyMapTab({super.key, this.onShortcutChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settingsController = ref.read(userSettingsProvider.notifier);

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: KeyMapActionDefs.all.length,
            itemBuilder: (context, index) {
              final action = KeyMapActionDefs.all[index];
              final effectiveShortcut = settingsController.getEffectiveShortcut(
                action.id,
              );
              final hasCustom = settingsController.hasCustomShortcut(action.id);

              return _KeyMapRow(
                action: action,
                shortcut: effectiveShortcut ?? '',
                isCustom: hasCustom,
                onShortcutChanged: (newShortcut) async {
                  if (newShortcut.isEmpty) {
                    settingsController.removeKeyMapShortcut(action.id);
                    onShortcutChanged?.call();
                    return;
                  }

                  final conflicts = settingsController.findConflictingActions(
                    newShortcut,
                    excludeActionId: action.id,
                  );

                  if (conflicts.isNotEmpty) {
                    final confirmed = await _showConflictDialog(
                      context,
                      newShortcut,
                      action.label,
                      conflicts,
                    );
                    if (confirmed == true) {
                      for (final conflictLabel in conflicts) {
                        final conflictAction = KeyMapActionDefs.all.firstWhere(
                          (a) => a.label == conflictLabel,
                        );
                        settingsController.removeKeyMapShortcut(
                          conflictAction.id,
                        );
                      }
                      settingsController.setKeyMapShortcut(
                        action.id,
                        newShortcut,
                      );
                      onShortcutChanged?.call();
                    }
                  } else {
                    settingsController.setKeyMapShortcut(
                      action.id,
                      newShortcut,
                    );
                    onShortcutChanged?.call();
                  }
                },
                onClearShortcut: () {
                  settingsController.removeKeyMapShortcut(action.id);
                  onShortcutChanged?.call();
                },
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => _showResetDialog(context, ref),
                icon: const Icon(Icons.restore),
                label: const Text('Reset to Default'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<bool?> _showConflictDialog(
    BuildContext context,
    String shortcut,
    String actionLabel,
    List<String> conflicts,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Shortcut Conflict'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Shortcut '$shortcut' is already used by '${conflicts.join(', ')}'.",
            ),
            const SizedBox(height: 8),
            const Text('It will be removed from the conflicting action(s).'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
  }

  Future<void> _showResetDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Key Map'),
        content: const Text(
          'Are you sure you want to reset all keyboard shortcuts to defaults?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(userSettingsProvider.notifier).resetKeyMapToDefault();
      onShortcutChanged?.call();
    }
  }
}

class _KeyMapRow extends StatelessWidget {
  final KeyMapAction action;
  final String shortcut;
  final bool isCustom;
  final Function(String) onShortcutChanged;
  final VoidCallback onClearShortcut;

  const _KeyMapRow({
    required this.action,
    required this.shortcut,
    required this.isCustom,
    required this.onShortcutChanged,
    required this.onClearShortcut,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(action.label, style: theme.textTheme.bodyMedium),
          ),
          Expanded(
            flex: 2,
            child: _ShortcutBadge(
              shortcut: shortcut,
              isCustom: isCustom,
              isEditable: action.isEditable,
              onTap: action.isEditable
                  ? () => _showShortcutRecorder(context)
                  : null,
              onClear: isCustom ? onClearShortcut : null,
            ),
          ),
        ],
      ),
    );
  }

  void _showShortcutRecorder(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => ShortcutRecorder(
        initialShortcut: shortcut,
        actionLabel: action.label,
        actionIdToExclude: action.id,
        onSave: (newShortcut) {
          onShortcutChanged(newShortcut);
        },
      ),
    );
  }
}

class _ShortcutBadge extends StatelessWidget {
  final String shortcut;
  final bool isCustom;
  final bool isEditable;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  const _ShortcutBadge({
    required this.shortcut,
    required this.isCustom,
    required this.isEditable,
    this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!isEditable) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              shortcut,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isCustom
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isCustom
                    ? theme.colorScheme.primary
                    : theme.dividerColor,
              ),
            ),
            child: Text(
              shortcut.isEmpty ? 'Click to set' : shortcut,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isCustom
                    ? theme.colorScheme.onPrimaryContainer
                    : shortcut.isEmpty
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onSurface,
                fontWeight: isCustom ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ),
        if (isCustom && onClear != null) ...[
          const SizedBox(width: 8),
          InkWell(
            onTap: onClear,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
