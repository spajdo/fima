import 'dart:io';

import 'package:fima/domain/entity/remote_connection.dart';
import 'package:path/path.dart' as p;

int _nextTabIdCounter = 0;

class PanelTab {
  final String id;
  final String path;
  final int sortColumn;
  final bool sortAscending;

  const PanelTab({
    required this.id,
    this.path = '',
    this.sortColumn = 0,
    this.sortAscending = true,
  });

  static String generateId() {
    _nextTabIdCounter++;
    return 'tab_$_nextTabIdCounter';
  }

  factory PanelTab.create({
    String path = '',
    int sortColumn = 0,
    bool sortAscending = true,
  }) {
    return PanelTab(
      id: generateId(),
      path: path,
      sortColumn: sortColumn,
      sortAscending: sortAscending,
    );
  }

  factory PanelTab.fromJson(Map<String, dynamic> json) {
    return PanelTab(
      id: generateId(),
      path: json['path'] as String? ?? '',
      sortColumn: json['sortColumn'] as int? ?? 0,
      sortAscending: json['sortAscending'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'sortColumn': sortColumn,
      'sortAscending': sortAscending,
    };
  }

  PanelTab copyWith({
    String? id,
    String? path,
    int? sortColumn,
    bool? sortAscending,
  }) {
    return PanelTab(
      id: id ?? this.id,
      path: path ?? this.path,
      sortColumn: sortColumn ?? this.sortColumn,
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }

  /// Creates a copy with a fresh runtime [id] (e.g. when applying a workspace).
  PanelTab withFreshId() {
    return PanelTab(
      id: generateId(),
      path: path,
      sortColumn: sortColumn,
      sortAscending: sortAscending,
    );
  }

  /// Returns a concise folder name suitable for displaying in a tab header.
  static String displayNameForPath(
    String path, {
    List<RemoteConnection> remoteConnections = const [],
  }) {
    if (path.isEmpty) {
      return 'Home';
    }

    if (path.startsWith('ssh://')) {
      final connId = RemoteConnection.connectionIdFromSshUrl(path);
      final remotePath = RemoteConnection.remotePathFromSshUrl(path);
      if (remotePath == '/' || remotePath.isEmpty) {
        final match = remoteConnections.cast<RemoteConnection?>().firstWhere(
          (c) => c?.id == connId,
          orElse: () => null,
        );
        return match?.name ?? connId;
      }
      final base = p.posix.basename(remotePath);
      return base.isEmpty ? remotePath : base;
    }

    var normalized = path;
    while (normalized.length > 1 &&
        (normalized.endsWith('/') || normalized.endsWith('\\'))) {
      // Preserve Windows drive roots like "C:\"
      if (Platform.isWindows &&
          normalized.length == 3 &&
          normalized[1] == ':') {
        break;
      }
      normalized = normalized.substring(0, normalized.length - 1);
    }

    final base = p.basename(normalized);
    return base.isEmpty ? normalized : base;
  }
}
