import 'package:fima/presentation/providers/operation_status_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BottomStatusBar extends ConsumerWidget {
  const BottomStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final operationState = ref.watch(operationStatusProvider);

    if (!operationState.isRunning || operationState.status == null) {
      return const SizedBox.shrink(); // Hidden when idle
    }

    final status = operationState.status!;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surfaceContainer,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${operationState.operationType}: ${status.currentItem}',
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.cancel, size: 20),
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
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(status.progress * 100).toStringAsFixed(1)}%',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
