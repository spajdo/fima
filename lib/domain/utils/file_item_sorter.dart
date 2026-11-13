import 'package:fima/domain/entity/file_system_item.dart';
import 'package:fima/domain/entity/panel_state.dart';

/// Pure sorting and filtering helpers for panel directory listings.
class FileItemSorter {
  const FileItemSorter._();

  /// Sorts [items] keeping parent navigation (`..`) first, then directories,
  /// then files according to [column] and [ascending].
  static List<FileSystemItem> sortItems(
    List<FileSystemItem> items,
    SortColumn column,
    bool ascending, {
    Map<String, int> directorySizes = const {},
  }) {
    final parentItem = items.where((i) => i.isParentDetails).toList();
    final directories = items
        .where((i) => i.isDirectory && !i.isParentDetails)
        .toList();
    final files = items
        .where((i) => !i.isDirectory && !i.isParentDetails)
        .toList();

    int compare(FileSystemItem a, FileSystemItem b) {
      int result;
      switch (column) {
        case SortColumn.name:
          result = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case SortColumn.size:
          final aSize = a.isDirectory ? (directorySizes[a.path] ?? -1) : a.size;
          final bSize = b.isDirectory ? (directorySizes[b.path] ?? -1) : b.size;
          result = aSize.compareTo(bSize);
          break;
        case SortColumn.modified:
          result = a.modified.compareTo(b.modified);
          break;
      }
      return ascending ? result : -result;
    }

    directories.sort(compare);
    files.sort(compare);

    return [...parentItem, ...directories, ...files];
  }

  /// Filters [items] by quick-filter prefix [query], always keeping `..`
  /// visible. Returns `(filteredItems, bestMatchIndex)`.
  static (List<FileSystemItem>, int) filterByPrefix(
    List<FileSystemItem> items,
    String query,
  ) {
    final lowerQuery = query.toLowerCase();
    final filtered = items
        .where(
          (item) =>
              item.isParentDetails ||
              item.name.toLowerCase().startsWith(lowerQuery),
        )
        .toList();

    int bestIndex = -1;
    int bestLength = -1;
    for (int i = 0; i < filtered.length; i++) {
      final item = filtered[i];
      if (item.isParentDetails) continue;
      final lowerName = item.name.toLowerCase();
      if (lowerName == lowerQuery) {
        bestIndex = i;
        break;
      }
      if (bestIndex == -1 || item.name.length < bestLength) {
        bestIndex = i;
        bestLength = item.name.length;
      }
    }

    final resolvedIndex = bestIndex >= 0
        ? bestIndex
        : (filtered.isNotEmpty ? 0 : -1);
    return (filtered, resolvedIndex);
  }
}
