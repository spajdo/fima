import 'package:flutter/foundation.dart';
import 'package:pasteboard/pasteboard.dart';

enum ClipboardOperation { copy, cut }

class SystemClipboard {
  static Future<void> setFilePaths(
    List<String> paths,
    ClipboardOperation operation,
  ) async {
    try {
      await Pasteboard.writeFiles(paths);
    } catch (e) {
      debugPrint('SystemClipboard.setFilePaths error: $e');
    }
  }

  static Future<(List<String> paths, ClipboardOperation operation)?>
  getFilePaths() async {
    try {
      final files = await Pasteboard.files();

      if (files.isEmpty) return null;

      return (files, ClipboardOperation.copy);
    } catch (e) {
      debugPrint('SystemClipboard.getFilePaths error: $e');
      return null;
    }
  }

  static Future<bool> hasFilePaths() async {
    try {
      final files = await Pasteboard.files();
      return files.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
