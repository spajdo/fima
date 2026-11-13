import 'dart:io';

import 'package:dartssh2/dartssh2.dart';

import 'package:fima/domain/entity/remote_connection.dart';
import 'package:fima/domain/repository/file_system_repository.dart';
import 'package:fima/domain/utils/fima_path.dart';
import 'package:fima/infrastructure/repository/compound_file_system_repository.dart';

/// Formats and updates POSIX file/directory permission bits locally and via SFTP.
class PosixPermissionsService {
  const PosixPermissionsService._();

  static String formatFromBits(int bits) {
    final perms = bits & 0xFFF;
    String bitChar(int mask, String ch) => (perms & mask) != 0 ? ch : '-';
    final rwx = [
      bitChar(0x100, 'r'),
      bitChar(0x080, 'w'),
      bitChar(0x040, 'x'),
      bitChar(0x020, 'r'),
      bitChar(0x010, 'w'),
      bitChar(0x008, 'x'),
      bitChar(0x004, 'r'),
      bitChar(0x002, 'w'),
      bitChar(0x001, 'x'),
    ].join();
    final octal = perms.toRadixString(8).padLeft(4, '0');
    return '$rwx ($octal)';
  }

  static String formatLocal(FileStat stat) {
    final modeStr = stat.modeString();
    final octal = (stat.mode & 0xFFF).toRadixString(8).padLeft(4, '0');
    return '$modeStr ($octal)';
  }

  static String formatSftp(SftpFileMode mode) {
    final chars = [
      mode.userRead ? 'r' : '-',
      mode.userWrite ? 'w' : '-',
      mode.userExecute ? 'x' : '-',
      mode.groupRead ? 'r' : '-',
      mode.groupWrite ? 'w' : '-',
      mode.groupExecute ? 'x' : '-',
      mode.otherRead ? 'r' : '-',
      mode.otherWrite ? 'w' : '-',
      mode.otherExecute ? 'x' : '-',
    ].join();
    final octal = (mode.value & 0xFFF).toRadixString(8).padLeft(4, '0');
    return '$chars ($octal)';
  }

  static Future<void> setPermissions({
    required String path,
    required int modeBits,
    FileSystemRepository? repository,
  }) async {
    final masked = modeBits & 0xFFF;
    if (FimaPath.isSshPath(path)) {
      if (repository is! CompoundFileSystemRepository) {
        throw StateError('SSH repository not available');
      }
      final connId = RemoteConnection.connectionIdFromSshUrl(path);
      final remotePath = RemoteConnection.remotePathFromSshUrl(path);
      final sftp = repository.sshRepository.getSftpClientFor(connId);
      if (sftp == null) {
        throw StateError('SSH session is not connected: $connId');
      }
      await sftp.setStat(
        remotePath,
        SftpFileAttrs(mode: SftpFileMode.value(masked)),
      );
      return;
    }

    if (Platform.isWindows) {
      throw UnsupportedError('chmod is not supported on Windows');
    }

    final octal = masked.toRadixString(8).padLeft(4, '0');
    final result = await Process.run('chmod', [octal, path]);
    if (result.exitCode != 0) {
      final err = result.stderr.toString().trim();
      throw FileSystemException(
        err.isNotEmpty ? err : 'chmod failed with exit code ${result.exitCode}',
        path,
      );
    }
  }
}
