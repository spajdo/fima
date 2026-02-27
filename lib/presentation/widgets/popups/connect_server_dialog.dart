import 'package:fima/domain/entity/remote_connection.dart';
import 'package:fima/infrastructure/repository/compound_file_system_repository.dart';
import 'package:fima/infrastructure/service/secure_password_service.dart';
import 'package:fima/presentation/providers/file_system_provider.dart';
import 'package:fima/presentation/providers/focus_provider.dart';
import 'package:fima/presentation/providers/settings_provider.dart';
import 'package:fima/presentation/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectServerDialog extends ConsumerStatefulWidget {
  /// If provided, pre-fills the dialog for editing an existing connection.
  final RemoteConnection? existingConnection;

  const ConnectServerDialog({super.key, this.existingConnection});

  @override
  ConsumerState<ConnectServerDialog> createState() =>
      _ConnectServerDialogState();
}

class _ConnectServerDialogState extends ConsumerState<ConnectServerDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _hostCtrl;
  late TextEditingController _portCtrl;
  late TextEditingController _usernameCtrl;
  late TextEditingController _passwordCtrl;
  bool _rememberPassword = true;
  bool _connecting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingConnection;
    _nameCtrl = TextEditingController(text: existing?.name ?? '');
    _hostCtrl = TextEditingController(text: existing?.host ?? '');
    _portCtrl = TextEditingController(text: existing?.port.toString() ?? '22');
    _usernameCtrl = TextEditingController(text: existing?.username ?? '');
    _passwordCtrl = TextEditingController();
    _rememberPassword = existing?.rememberPassword ?? true;

    // Load remembered password if editing
    if (existing != null && existing.rememberPassword) {
      SecurePasswordService().getPassword(existing.id).then((pw) {
        if (pw != null && mounted) {
          setState(() => _passwordCtrl.text = pw);
        }
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final name = _nameCtrl.text.trim();
    final host = _hostCtrl.text.trim();
    final portText = _portCtrl.text.trim();
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (name.isEmpty || host.isEmpty || username.isEmpty) {
      setState(() => _errorMessage = 'Name, host and username are required.');
      return;
    }

    final port = int.tryParse(portText) ?? 22;

    setState(() {
      _connecting = true;
      _errorMessage = null;
    });

    try {
      // Build or update the connection object.
      final existing = widget.existingConnection;
      final connection = existing != null
          ? existing.copyWith(
              name: name,
              host: host,
              port: port,
              username: username,
              rememberPassword: _rememberPassword,
            )
          : RemoteConnection.create(
              name: name,
              host: host,
              port: port,
              username: username,
              rememberPassword: _rememberPassword,
            );

      // Get the SSH repository from the compound repo.
      final compoundRepo =
          ref.read(fileSystemRepositoryProvider)
              as CompoundFileSystemRepository;
      final sshRepo = compoundRepo.sshRepository;

      // Attempt connection.
      await sshRepo.connect(connection, password);

      // Store password securely if user wants to remember it.
      final pwService = SecurePasswordService();
      if (_rememberPassword) {
        await pwService.savePassword(connection.id, password);
      } else {
        await pwService.deletePassword(connection.id);
      }

      // Persist connection to settings.
      if (existing != null) {
        ref
            .read(userSettingsProvider.notifier)
            .updateRemoteConnection(existing.id, connection);
      } else {
        ref.read(userSettingsProvider.notifier).addRemoteConnection(connection);
      }

      if (!mounted) return;
      Navigator.of(context).pop();

      // Navigate the active panel to the SSH path.
      final focusController = ref.read(focusProvider.notifier);
      final activePanelId = focusController.getActivePanelId();
      ref
          .read(panelStateProvider(activePanelId).notifier)
          .loadSshPath(connection);
    } catch (e) {
      setState(() {
        _connecting = false;
        _errorMessage = 'Connection failed: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fimaTheme = ref.watch(themeProvider);
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: fimaTheme.backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.dns, color: fimaTheme.accentColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    widget.existingConnection != null
                        ? 'Edit Connection'
                        : 'Connect to Server',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: fimaTheme.textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildField(
                label: 'Name',
                controller: _nameCtrl,
                hint: 'My Server',
                fimaTheme: fimaTheme,
                theme: theme,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildField(
                      label: 'Host',
                      controller: _hostCtrl,
                      hint: '192.168.1.1',
                      fimaTheme: fimaTheme,
                      theme: theme,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildField(
                      label: 'Port',
                      controller: _portCtrl,
                      hint: '22',
                      keyboardType: TextInputType.number,
                      fimaTheme: fimaTheme,
                      theme: theme,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildField(
                label: 'Username',
                controller: _usernameCtrl,
                hint: 'root',
                fimaTheme: fimaTheme,
                theme: theme,
              ),
              const SizedBox(height: 12),
              _buildField(
                label: 'Password',
                controller: _passwordCtrl,
                obscureText: true,
                fimaTheme: fimaTheme,
                theme: theme,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: _rememberPassword,
                    activeColor: fimaTheme.accentColor,
                    onChanged: (v) =>
                        setState(() => _rememberPassword = v ?? true),
                  ),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _rememberPassword = !_rememberPassword),
                    child: Text(
                      'Remember password',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: fimaTheme.textColor,
                      ),
                    ),
                  ),
                ],
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.red),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _connecting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: fimaTheme.secondaryTextColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _connecting ? null : _connect,
                    icon: _connecting
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.link, size: 16),
                    label: Text(
                      widget.existingConnection != null
                          ? 'Save & Reconnect'
                          : 'OK',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: fimaTheme.accentColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    String? hint,
    bool obscureText = false,
    TextInputType? keyboardType,
    required dynamic fimaTheme,
    required ThemeData theme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: fimaTheme.secondaryTextColor,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: TextStyle(color: fimaTheme.textColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: fimaTheme.secondaryTextColor),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: fimaTheme.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: fimaTheme.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: fimaTheme.accentColor),
            ),
            fillColor: fimaTheme.surfaceColor,
            filled: true,
          ),
        ),
      ],
    );
  }
}
