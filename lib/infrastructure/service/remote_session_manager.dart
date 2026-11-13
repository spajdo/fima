import 'package:fima/domain/entity/remote_connection.dart';
import 'package:fima/infrastructure/repository/ssh_file_system_repository.dart';
import 'package:fima/infrastructure/service/secure_password_service.dart';
import 'package:flutter/foundation.dart';

enum SshConnectionStatus {
  alreadyConnected,
  reconnected,
  connectionNotFound,
  needsPassword,
}

class SshConnectionResult {
  final SshConnectionStatus status;
  final String connectionId;
  final RemoteConnection? connection;

  const SshConnectionResult({
    required this.status,
    required this.connectionId,
    this.connection,
  });
}

/// Manages SSH session resolution and silent reconnection using stored
/// credentials.
class RemoteSessionManager {
  final SecurePasswordService _passwordService;

  RemoteSessionManager([SecurePasswordService? passwordService])
    : _passwordService = passwordService ?? SecurePasswordService();

  Future<SshConnectionResult> ensureConnected({
    required SshFileSystemRepository sshRepository,
    required String sshUrl,
    required List<RemoteConnection> savedConnections,
  }) async {
    final connId = RemoteConnection.connectionIdFromSshUrl(sshUrl);
    if (sshRepository.isConnected(connId)) {
      return SshConnectionResult(
        status: SshConnectionStatus.alreadyConnected,
        connectionId: connId,
      );
    }

    final connection = savedConnections.cast<RemoteConnection?>().firstWhere(
      (c) => c?.id == connId,
      orElse: () => null,
    );

    if (connection == null) {
      return SshConnectionResult(
        status: SshConnectionStatus.connectionNotFound,
        connectionId: connId,
      );
    }

    if (connection.rememberPassword) {
      final savedPassword = await _passwordService.getPassword(connection.id);
      if (savedPassword != null && savedPassword.isNotEmpty) {
        try {
          await sshRepository.connect(connection, savedPassword);
          return SshConnectionResult(
            status: SshConnectionStatus.reconnected,
            connectionId: connId,
            connection: connection,
          );
        } catch (e) {
          debugPrint('Auto-reconnect SSH failed for ${connection.name}: $e');
        }
      }
    }

    return SshConnectionResult(
      status: SshConnectionStatus.needsPassword,
      connectionId: connId,
      connection: connection,
    );
  }
}
