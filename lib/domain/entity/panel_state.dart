import 'package:fima/domain/entity/file_system_item.dart';

enum SortColumn {
  name,
  size,
  modified,
}

class PanelState {
  final String currentPath;
  final List<FileSystemItem> items;
  final SortColumn sortColumn;
  final bool sortAscending;
  final Set<String> selectedItems;
  final int focusedIndex; // Index of focused item for keyboard navigation
  final String? editingPath; // Path of the item currently being edited

  const PanelState({
    this.currentPath = '',
    this.items = const [],
    this.sortColumn = SortColumn.name,
    this.sortAscending = true,
    this.selectedItems = const {},
    this.focusedIndex = -1, // -1 means no focus
    this.editingPath,
  });

  PanelState copyWith({
    String? currentPath,
    List<FileSystemItem>? items,
    SortColumn? sortColumn,
    bool? sortAscending,
    Set<String>? selectedItems,
    int? focusedIndex,
    String? editingPath,
  }) {
    return PanelState(
      currentPath: currentPath ?? this.currentPath,
      items: items ?? this.items,
      sortColumn: sortColumn ?? this.sortColumn,
      sortAscending: sortAscending ?? this.sortAscending,
      selectedItems: selectedItems ?? this.selectedItems,
      focusedIndex: focusedIndex ?? this.focusedIndex,
      // If editingPath is passed as null explicitly (to clear it), we might need a different approach
      // or just assume if it's passed it overrides.
      // Standard copyWith pattern:
      editingPath: editingPath ?? this.editingPath,
    );
  }

  // Helper to clear editing path
  PanelState clearEditing() {
      return PanelState(
      currentPath: currentPath,
      items: items,
      sortColumn: sortColumn,
      sortAscending: sortAscending,
      selectedItems: selectedItems,
      focusedIndex: focusedIndex,
      editingPath: null,
    );
  }
}
