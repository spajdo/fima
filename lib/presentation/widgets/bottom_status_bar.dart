import 'package:fima/presentation/providers/operation_status_provider.dart';
import 'package:fima/presentation/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BottomStatusBar extends ConsumerWidget {
  const BottomStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final operationState = ref.watch(operationStatusProvider);
    final fimaTheme = ref.watch(themeProvider);

    if (!operationState.isRunning || operationState.status == null) {
      return const SizedBox.shrink();
    }

    final status = operationState.status!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: fimaTheme.surfaceColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${operationState.operationType}: ${status.currentItem}',
                  style: TextStyle(fontSize: 12, color: fimaTheme.textColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: Icon(Icons.cancel, size: 20, color: fimaTheme.textColor),
                onPressed: () {
                  ref.read(operationStatusProvider.notifier).cancel();
                },
                tooltip: 'Cancel',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: status.progress,
                  minHeight: 4,
                  backgroundColor: fimaTheme.surfaceColor,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    fimaTheme.accentColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(status.progress * 100).toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 12, color: fimaTheme.textColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
