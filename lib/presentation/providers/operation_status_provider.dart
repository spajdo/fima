import 'dart:async';

import 'package:fima/domain/entity/file_operation.dart';
import 'package:fima/presentation/providers/file_system_provider.dart';
import 'package:fima/presentation/providers/focus_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// State to hold current operation status
class OperationState {
  final OperationStatus? status;
  final bool isRunning;
  final String? operationType; // 'Copying' or 'Moving'

  const OperationState({
    this.status,
    this.isRunning = false,
    this.operationType,
  });

  OperationState copyWith({
    OperationStatus? status,
    bool? isRunning,
    String? operationType,
  }) {
    return OperationState(
      status: status ?? this.status,
      isRunning: isRunning ?? this.isRunning,
      operationType: operationType ?? this.operationType,
    );
  }
}

class OperationController extends StateNotifier<OperationState> {
  final Ref _ref;
  CancellationToken? _cancellationToken;
  StreamSubscription<OperationStatus>? _subscription;

  OperationController(this._ref) : super(const OperationState());

  void cancel() {
    _cancellationToken?.cancel();
    _cancellationToken = null;
    state = const OperationState(); // Reset
  }

  Future<void> startCopy() async {
    await _startOperation(isCopy: true);
  }

  Future<void> startMove() async {
    await _startOperation(isCopy: false);
  }

  Future<void> _startOperation({required bool isCopy}) async {
    if (state.isRunning) return; // Prevent concurrent operations for now

    final focusState = _ref.read(focusProvider);
    final activePanel = focusState.activePanel;
    
    // Determine source and destination
    // Source is active panel
    // Destination is the inactive panel
    final sourceId = activePanel == ActivePanel.left ? 'left' : 'right';
    final destId = activePanel == ActivePanel.left ? 'right' : 'left';

    final sourceController = _ref.read(panelStateProvider(sourceId).notifier);
    final destController = _ref.read(panelStateProvider(destId).notifier);

    // Get selected items from source
    // If no selection, use focused item (if valid)
    final sourceState = _ref.read(panelStateProvider(sourceId));
    List<String> sourcePaths = sourceState.selectedItems.toList();
    
    if (sourcePaths.isEmpty) {
        if (sourceState.focusedIndex >= 0 && 
            sourceState.focusedIndex < sourceState.items.length) {
            final item = sourceState.items[sourceState.focusedIndex];
            if (!item.isParentDetails) {
                sourcePaths.add(item.path);
            }
        }
    }

    if (sourcePaths.isEmpty) return; // Nothing to operate on

    final destPath = _ref.read(panelStateProvider(destId)).currentPath;
    if (destPath.isEmpty) return;

    // Start operation
    _cancellationToken = CancellationToken();
    state = OperationState(
      isRunning: true,
      operationType: isCopy ? 'Copying' : 'Moving',
    );

    final repository = _ref.read(fileSystemRepositoryProvider);
    final stream = isCopy
        ? repository.copyItems(sourcePaths, destPath, _cancellationToken!)
        : repository.moveItems(sourcePaths, destPath, _cancellationToken!);

    _subscription = stream.listen(
      (status) {
        state = state.copyWith(status: status);
      },
      onError: (e) {
        debugPrint('Operation error: $e');
        state = const OperationState(); // Reset on error
      },
      onDone: () async {
        state = const OperationState(); // Reset on completion
        // Refresh both panels
        await sourceController.loadPath(sourceState.currentPath);
        await destController.loadPath(destPath);
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final operationStatusProvider =
    StateNotifierProvider<OperationController, OperationState>((ref) {
  return OperationController(ref);
});
