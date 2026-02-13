import 'package:pasteboard/pasteboard.dart';

enum ClipboardOperation { copy, cut }

class SystemClipboard {
  static Future<void> setFilePaths(
    List<String> paths,
    ClipboardOperation operation,
  ) async {
    await Pasteboard.writeFiles(paths);
  }

  static Future<(List<String> paths, ClipboardOperation operation)?>
  getFilePaths() async {
    final files = await Pasteboard.files();

    if (files.isEmpty) return null;

    return (files, ClipboardOperation.copy);
  }

  static Future<bool> hasFilePaths() async {
    final files = await Pasteboard.files();
    return files.isNotEmpty;
  }
}
