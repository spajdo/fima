import 'package:fima/domain/entity/file_system_item.dart';
import 'package:fima/domain/entity/panel_operation_progress.dart';

enum SortColumn { name, size, modified }

class PanelState {
  final String currentPath;
  final List<FileSystemItem> items;
  final SortColumn sortColumn;
  final bool sortAscending;
  final Set<String> selectedItems;
  final int focusedIndex;
  final String? editingPath;
  final List<String> visitedPaths;
  final String quickFilterText;
  final PanelOperationProgress? operationProgress;

  const PanelState({
    this.currentPath = '',
    this.items = const [],
    this.sortColumn = SortColumn.name,
    this.sortAscending = true,
    this.selectedItems = const {},
    this.focusedIndex = -1,
    this.editingPath,
    this.visitedPaths = const [],
    this.quickFilterText = '',
    this.operationProgress,
  });

  PanelState copyWith({
    String? currentPath,
    List<FileSystemItem>? items,
    SortColumn? sortColumn,
    bool? sortAscending,
    Set<String>? selectedItems,
    int? focusedIndex,
    String? editingPath,
    List<String>? visitedPaths,
    String? quickFilterText,
    PanelOperationProgress? operationProgress,
    bool clearOperationProgress = false,
  }) {
    return PanelState(
      currentPath: currentPath ?? this.currentPath,
      items: items ?? this.items,
      sortColumn: sortColumn ?? this.sortColumn,
      sortAscending: sortAscending ?? this.sortAscending,
      selectedItems: selectedItems ?? this.selectedItems,
      focusedIndex: focusedIndex ?? this.focusedIndex,
      editingPath: editingPath ?? this.editingPath,
      visitedPaths: visitedPaths ?? this.visitedPaths,
      quickFilterText: quickFilterText ?? this.quickFilterText,
      operationProgress: clearOperationProgress
          ? null
          : (operationProgress ?? this.operationProgress),
    );
  }

  PanelState clearEditing() {
    return PanelState(
      currentPath: currentPath,
      items: items,
      sortColumn: sortColumn,
      sortAscending: sortAscending,
      selectedItems: selectedItems,
      focusedIndex: focusedIndex,
      editingPath: null,
      visitedPaths: visitedPaths,
      quickFilterText: quickFilterText,
      operationProgress: operationProgress,
    );
  }
}
