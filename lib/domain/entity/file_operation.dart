class OperationStatus {
  final int totalBytes;
  final int processedBytes;
  final int totalItems;
  final int processedItems;
  final String currentItem;

  const OperationStatus({
    required this.totalBytes,
    required this.processedBytes,
    required this.totalItems,
    required this.processedItems,
    required this.currentItem,
  });

  double get progress {
    if (totalBytes > 0) {
      return processedBytes / totalBytes;
    }
    if (totalItems > 0) {
      return processedItems / totalItems;
    }
    return 0.0;
  }
  
  OperationStatus copyWith({
    int? totalBytes,
    int? processedBytes,
    int? totalItems,
    int? processedItems,
    String? currentItem,
  }) {
    return OperationStatus(
      totalBytes: totalBytes ?? this.totalBytes,
      processedBytes: processedBytes ?? this.processedBytes,
      totalItems: totalItems ?? this.totalItems,
      processedItems: processedItems ?? this.processedItems,
      currentItem: currentItem ?? this.currentItem,
    );
  }
}

class CancellationToken {
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}
