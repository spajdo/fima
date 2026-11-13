import 'package:path/path.dart' as p;

/// Maps file extensions and filesystem attributes into human-readable labels.
class FileKindDescriptor {
  const FileKindDescriptor._();

  static const Map<String, String> _knownKinds = {
    '.zip': 'ZIP Archive',
    '.tar': 'TAR Archive',
    '.gz': 'Gzip Archive',
    '.bz2': 'Bzip2 Archive',
    '.xz': 'XZ Archive',
    '.7z': '7-Zip Archive',
    '.rar': 'RAR Archive',
    '.png': 'PNG Image',
    '.jpg': 'JPEG Image',
    '.jpeg': 'JPEG Image',
    '.gif': 'GIF Image',
    '.svg': 'SVG Vector Image',
    '.ico': 'Icon File',
    '.webp': 'WebP Image',
    '.bmp': 'Bitmap Image',
    '.tiff': 'TIFF Image',
    '.tif': 'TIFF Image',
    '.pdf': 'PDF Document',
    '.md': 'Markdown Document',
    '.markdown': 'Markdown Document',
    '.txt': 'Plain Text Document',
    '.log': 'Log File',
    '.json': 'JSON Document',
    '.xml': 'XML Document',
    '.yaml': 'YAML Document',
    '.yml': 'YAML Document',
    '.toml': 'TOML Document',
    '.csv': 'CSV Spreadsheet',
    '.html': 'HTML Document',
    '.htm': 'HTML Document',
    '.css': 'CSS Stylesheet',
    '.js': 'JavaScript Source',
    '.ts': 'TypeScript Source',
    '.dart': 'Dart Source',
    '.py': 'Python Script',
    '.sh': 'Shell Script',
    '.zsh': 'Zsh Script',
    '.bash': 'Bash Script',
    '.rs': 'Rust Source',
    '.go': 'Go Source',
    '.java': 'Java Source',
    '.kt': 'Kotlin Source',
    '.swift': 'Swift Source',
    '.c': 'C Source',
    '.cpp': 'C++ Source',
    '.h': 'C/C++ Header',
    '.mp3': 'MP3 Audio',
    '.wav': 'WAV Audio',
    '.flac': 'FLAC Audio',
    '.aac': 'AAC Audio',
    '.mp4': 'MP4 Video',
    '.mov': 'QuickTime Movie',
    '.mkv': 'Matroska Video',
    '.avi': 'AVI Video',
    '.dmg': 'macOS Disk Image',
    '.app': 'macOS Application',
    '.exe': 'Windows Executable',
    '.deb': 'Debian Package',
    '.rpm': 'RPM Package',
  };

  static String describeKind(
    String name, {
    required bool isDirectory,
    bool isSymlink = false,
    bool isRemote = false,
    bool isInsideZip = false,
  }) {
    if (isSymlink) return 'Symbolic Link';
    if (isDirectory) {
      if (isRemote) return 'Remote Folder';
      if (isInsideZip) return 'Folder (in ZIP Archive)';
      return 'Folder';
    }
    final ext = p.extension(name).toLowerCase();
    final baseKind =
        _knownKinds[ext] ??
        (ext.length > 1 ? '${ext.substring(1).toUpperCase()} File' : 'File');
    if (isRemote) return 'Remote $baseKind';
    if (isInsideZip) return '$baseKind (in ZIP Archive)';
    return baseKind;
  }
}
