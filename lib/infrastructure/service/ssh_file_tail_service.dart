import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';

/// Manages active SSH file tail sessions.
/// Each session polls the remote file for new bytes and appends them to
/// a local temp file that the system default app (e.g. VS Code) is watching.
class SshFileTailService {
  final Map<String, _TailWorker> _workers = {};

  /// Starts polling [sshPath] (and appending to [localPath]).
  /// The [initialSize] should be the size at the time the file was first
  /// downloaded, so the first poll doesn't re-copy existing content.
  void startTailing({
    required SftpClient sftp,
    required String sshPath,
    required String remotePath,
    required String localPath,
    required int initialSize,
    int intervalSeconds = 2,
  }) {
    stopTailing(sshPath); // Cancel any previous worker for this path.
    final worker = _TailWorker(
      sftp: sftp,
      remotePath: remotePath,
      localPath: localPath,
      initialSize: initialSize,
    );
    _workers[sshPath] = worker;
    worker.start(intervalSeconds);
  }

  /// Stops tailing a specific SSH path.
  void stopTailing(String sshPath) {
    _workers.remove(sshPath)?.stop();
  }

  /// Stops all tail workers for a given connection (used on disconnect).
  void stopAllForConnection(String connectionId) {
    final keysToRemove = _workers.keys
        .where((k) => k.startsWith('ssh://$connectionId/'))
        .toList();
    for (final key in keysToRemove) {
      _workers.remove(key)?.stop();
    }
  }

  bool isTailing(String sshPath) => _workers.containsKey(sshPath);

  void stopAll() {
    for (final w in _workers.values) {
      w.stop();
    }
    _workers.clear();
  }
}

class _TailWorker {
  final SftpClient sftp;
  final String remotePath;
  final String localPath;

  Timer? _timer;
  int _lastSize;
  bool _polling = false;

  _TailWorker({
    required this.sftp,
    required this.remotePath,
    required this.localPath,
    required int initialSize,
  }) : _lastSize = initialSize;

  void start(int intervalSeconds) {
    _timer = Timer.periodic(Duration(seconds: intervalSeconds), (_) => _poll());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _poll() async {
    if (_polling) return; // Skip overlapping polls.
    _polling = true;

    try {
      final stat = await sftp.stat(remotePath);
      final currentSize = stat.size?.toInt() ?? 0;

      if (currentSize > _lastSize) {
        // Read only the new bytes starting at _lastSize.
        final file = await sftp.open(remotePath, mode: SftpFileOpenMode.read);
        try {
          final newBytes = <int>[];
          await for (final chunk in file.read(
            offset: _lastSize,
            length: currentSize - _lastSize,
          )) {
            newBytes.addAll(chunk);
          }
          if (newBytes.isNotEmpty) {
            await File(
              localPath,
            ).writeAsBytes(Uint8List.fromList(newBytes), mode: FileMode.append);
          }
          _lastSize = currentSize;
        } finally {
          await file.close();
        }
      } else if (currentSize < _lastSize) {
        // File was truncated or rotated — re-download from scratch.
        final file = await sftp.open(remotePath, mode: SftpFileOpenMode.read);
        try {
          final data = <int>[];
          await for (final chunk in file.read()) {
            data.addAll(chunk);
          }
          await File(localPath).writeAsBytes(Uint8List.fromList(data));
          _lastSize = currentSize;
        } finally {
          await file.close();
        }
      }
    } catch (e) {
      debugPrint('SshFileTail poll error ($remotePath): $e');
    } finally {
      _polling = false;
    }
  }
}
