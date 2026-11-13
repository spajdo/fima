import 'dart:io';

import 'package:fima/domain/entity/desktop_application.dart';
import 'package:fima/domain/utils/fima_path.dart';
import 'package:flutter/foundation.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;

/// Cross-platform OS integration service for opening files, terminals,
/// external applications, and the system file manager.
class DesktopIntegrationService {
  const DesktopIntegrationService();

  Future<void> openFile(String path) async {
    await OpenFile.open(path);
  }

  Future<void> openTerminal(String path) async {
    if (path.isEmpty || FimaPath.isSshPath(path) || FimaPath.isZipPath(path)) {
      return;
    }

    if (Platform.isLinux) {
      try {
        await Process.run('x-terminal-emulator', [], workingDirectory: path);
        return;
      } catch (_) {
        const fallbackTerminals = [
          'gnome-terminal',
          'konsole',
          'xfce4-terminal',
          'mate-terminal',
          'terminator',
          'xterm',
        ];
        for (final terminal in fallbackTerminals) {
          try {
            await Process.run(terminal, [], workingDirectory: path);
            return;
          } catch (_) {
            // Try next terminal emulator.
          }
        }
        debugPrint('Could not find a supported terminal to open.');
      }
    } else if (Platform.isMacOS) {
      try {
        await Process.run('open', ['-a', 'Terminal', path]);
      } catch (e) {
        debugPrint('Error opening Mac terminal: $e');
      }
    } else if (Platform.isWindows) {
      try {
        await Process.run('cmd', [
          '/K',
          'start',
          'cd',
          '/d',
          path,
        ], runInShell: true);
      } catch (e) {
        debugPrint('Error opening Windows terminal: $e');
      }
    }
  }

  Future<void> openFileManager(String path) async {
    if (path.isEmpty || FimaPath.isSshPath(path) || FimaPath.isZipPath(path)) {
      return;
    }

    if (Platform.isLinux) {
      try {
        await Process.run('xdg-open', [path]);
      } catch (e) {
        debugPrint('Error opening file manager on Linux: $e');
      }
    } else if (Platform.isMacOS) {
      try {
        await Process.run('open', [path]);
      } catch (e) {
        debugPrint('Error opening file manager on macOS: $e');
      }
    } else if (Platform.isWindows) {
      try {
        await Process.run('explorer', [path]);
      } catch (e) {
        debugPrint('Error opening file manager on Windows: $e');
      }
    }
  }

  Future<void> revealInFileManager(
    String path, {
    required bool isDirectory,
  }) async {
    if (path.isEmpty || FimaPath.isSshPath(path) || FimaPath.isZipPath(path)) {
      return;
    }

    if (isDirectory) {
      await openFileManager(path);
      return;
    }

    if (Platform.isMacOS) {
      try {
        await Process.run('open', ['-R', path]);
      } catch (e) {
        debugPrint('Error revealing in Finder on macOS: $e');
      }
    } else if (Platform.isWindows) {
      try {
        await Process.run('explorer', ['/select,$path']);
      } catch (e) {
        debugPrint('Error revealing in Explorer on Windows: $e');
      }
    } else {
      await openFileManager(p.dirname(path));
    }
  }

  Future<void> openWithApplication(DesktopApplication app, String path) async {
    if (path.isEmpty) return;

    if (Platform.isLinux || Platform.isWindows) {
      try {
        final command = _buildCommand(app.exec, path);
        await Process.start(command[0], command.sublist(1), runInShell: true);
      } catch (e) {
        debugPrint('Error opening with application: $e');
      }
    } else if (Platform.isMacOS) {
      try {
        await Process.run('open', ['-a', app.exec, path]);
      } catch (e) {
        debugPrint('Error opening with application on macOS: $e');
      }
    }
  }

  List<String> _buildCommand(String exec, String path) {
    final parts = exec.split(' ');
    final result = <String>[];
    bool pathSubstituted = false;
    for (final part in parts) {
      if (part.isEmpty) continue;
      final replaced = _replaceExecParams(part, path);
      if (replaced != part) pathSubstituted = true;
      result.add(replaced);
    }
    if (!pathSubstituted) {
      result.add(path);
    }
    return result;
  }

  String _replaceExecParams(String exec, String path) {
    const params = ['%F', '%f', '%U', '%u', '%D', '%d', '%N', '%n'];
    String result = exec;
    for (final param in params) {
      result = result.replaceAll(param, path);
    }
    return result;
  }
}
