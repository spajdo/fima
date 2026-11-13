/// Pure byte-size formatting utilities shared across presentation widgets.
class FileSizeFormatter {
  FileSizeFormatter._();

  static const int _kb = 1024;
  static const int _mb = 1024 * 1024;
  static const int _gb = 1024 * 1024 * 1024;

  /// Formats [bytes] into a human-readable string (`B`, `KB`, `MB`, `GB`).
  static String format(int bytes, {int kbDecimals = 1, int largeDecimals = 1}) {
    if (bytes < 0) return 'N/A';
    if (bytes < _kb) return '$bytes B';
    if (bytes < _mb) return '${(bytes / _kb).toStringAsFixed(kbDecimals)} KB';
    if (bytes < _gb) {
      return '${(bytes / _mb).toStringAsFixed(largeDecimals)} MB';
    }
    return '${(bytes / _gb).toStringAsFixed(largeDecimals)} GB';
  }

  /// Formats [bytes] alongside exact byte count for detailed inspection views.
  static String formatWithExact(
    int bytes, {
    int kbDecimals = 1,
    int largeDecimals = 2,
    String Function(int)? exactFormatter,
  }) {
    final human = format(
      bytes,
      kbDecimals: kbDecimals,
      largeDecimals: largeDecimals,
    );
    if (bytes < _kb) return human;
    final exact = exactFormatter != null ? exactFormatter(bytes) : '$bytes';
    return '$human ($exact bytes)';
  }
}
