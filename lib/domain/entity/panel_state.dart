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

  const PanelState({
    this.currentPath = '',
    this.items = const [],
    this.sortColumn = SortColumn.name,
    this.sortAscending = true,
    this.selectedItems = const {},
    this.focusedIndex = -1, // -1 means no focus
  });

  PanelState copyWith({
    String? currentPath,
    List<FileSystemItem>? items,
    SortColumn? sortColumn,
    bool? sortAscending,
    Set<String>? selectedItems,
    int? focusedIndex,
  }) {
    return PanelState(
      currentPath: currentPath ?? this.currentPath,
      items: items ?? this.items,
      sortColumn: sortColumn ?? this.sortColumn,
      sortAscending: sortAscending ?? this.sortAscending,
      selectedItems: selectedItems ?? this.selectedItems,
      focusedIndex: focusedIndex ?? this.focusedIndex,
    );
  }
}
