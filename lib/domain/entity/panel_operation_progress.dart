class PanelOperationProgress {
  final String operationName; // e.g. 'Compressing', 'Extracting'
  final double progress; // 0.0 to 1.0
  final String currentItem;

  const PanelOperationProgress({
    required this.operationName,
    required this.progress,
    required this.currentItem,
  });

  PanelOperationProgress copyWith({
    String? operationName,
    double? progress,
    String? currentItem,
  }) {
    return PanelOperationProgress(
      operationName: operationName ?? this.operationName,
      progress: progress ?? this.progress,
      currentItem: currentItem ?? this.currentItem,
    );
  }
}
