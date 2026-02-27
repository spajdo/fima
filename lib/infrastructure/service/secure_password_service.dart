import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service to securely store SSH connection passwords using flutter_secure_storage.
class SecurePasswordService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    mOptions: MacOsOptions(useDataProtectionKeyChain: false),
  );

  static const String _keyPrefix = 'ssh_connection_password_';

  /// Saves a password for the given connection ID.
  Future<void> savePassword(String connectionId, String password) async {
    await _storage.write(key: '$_keyPrefix$connectionId', value: password);
  }

  /// Retrieves the password for the given connection ID, or null if not found.
  Future<String?> getPassword(String connectionId) async {
    return _storage.read(key: '$_keyPrefix$connectionId');
  }

  /// Deletes the stored password for the given connection ID.
  Future<void> deletePassword(String connectionId) async {
    await _storage.delete(key: '$_keyPrefix$connectionId');
  }
}
