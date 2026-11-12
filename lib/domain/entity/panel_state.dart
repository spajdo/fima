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
  final bool isEditingPath;
  final List<String> visitedPaths;
  final String quickFilterText;
  final PanelOperationProgress? operationProgress;
  final Map<String, int> directorySizes;
  final Set<String> calculatingDirectories;

  const PanelState({
    this.currentPath = '',
    this.items = const [],
    this.sortColumn = SortColumn.name,
    this.sortAscending = true,
    this.selectedItems = const {},
    this.focusedIndex = -1,
    this.editingPath,
    this.isEditingPath = false,
    this.visitedPaths = const [],
    this.quickFilterText = '',
    this.operationProgress,
    this.directorySizes = const {},
    this.calculatingDirectories = const {},
  });

  PanelState copyWith({
    String? currentPath,
    List<FileSystemItem>? items,
    SortColumn? sortColumn,
    bool? sortAscending,
    Set<String>? selectedItems,
    int? focusedIndex,
    String? editingPath,
    bool? isEditingPath,
    List<String>? visitedPaths,
    String? quickFilterText,
    PanelOperationProgress? operationProgress,
    bool clearOperationProgress = false,
    Map<String, int>? directorySizes,
    Set<String>? calculatingDirectories,
  }) {
    return PanelState(
      currentPath: currentPath ?? this.currentPath,
      items: items ?? this.items,
      sortColumn: sortColumn ?? this.sortColumn,
      sortAscending: sortAscending ?? this.sortAscending,
      selectedItems: selectedItems ?? this.selectedItems,
      focusedIndex: focusedIndex ?? this.focusedIndex,
      editingPath: editingPath ?? this.editingPath,
      isEditingPath: isEditingPath ?? this.isEditingPath,
      visitedPaths: visitedPaths ?? this.visitedPaths,
      quickFilterText: quickFilterText ?? this.quickFilterText,
      operationProgress: clearOperationProgress
          ? null
          : (operationProgress ?? this.operationProgress),
      directorySizes: directorySizes ?? this.directorySizes,
      calculatingDirectories:
          calculatingDirectories ?? this.calculatingDirectories,
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
      isEditingPath: isEditingPath,
      visitedPaths: visitedPaths,
      quickFilterText: quickFilterText,
      operationProgress: operationProgress,
      directorySizes: directorySizes,
      calculatingDirectories: calculatingDirectories,
    );
  }
}
