import 'package:fima/domain/entity/app_theme.dart';
import 'package:fima/domain/entity/file_system_item.dart';
import 'package:fima/infrastructure/service/item_metadata_service.dart';
import 'package:fima/presentation/providers/file_system_provider.dart';
import 'package:fima/presentation/providers/overlay_provider.dart';
import 'package:fima/presentation/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> showPermissionsDialog(
  BuildContext context, {
  required FileSystemItem item,
  required String currentPath,
}) {
  return showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (context) =>
        PermissionsDialog(item: item, currentPath: currentPath),
  );
}

class PermissionsDialog extends ConsumerStatefulWidget {
  final FileSystemItem item;
  final String currentPath;

  const PermissionsDialog({
    super.key,
    required this.item,
    required this.currentPath,
  });

  @override
  ConsumerState<PermissionsDialog> createState() => _PermissionsDialogState();
}

class _PermissionsDialogState extends ConsumerState<PermissionsDialog> {
  int? _initialModeBits;
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadCurrentPermissions();
  }

  Future<void> _loadCurrentPermissions() async {
    try {
      final repository = ref.read(fileSystemRepositoryProvider);
      final meta = await ItemMetadataService.loadDetails(
        items: [widget.item],
        currentPath: widget.currentPath,
        repository: repository,
      );
      if (!mounted) return;
      setState(() {
        _initialModeBits = meta.modeBits;
        _loading = false;
        if (!meta.canEditPermissions || meta.modeBits == null) {
          _loadError =
              'POSIX permissions cannot be modified for this item on the current platform.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fimaTheme = ref.watch(themeProvider);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          width: 420,
          decoration: BoxDecoration(
            color: fimaTheme.backgroundColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: fimaTheme.borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: fimaTheme.surfaceColor,
                  border: Border(
                    bottom: BorderSide(color: fimaTheme.borderColor),
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(9),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 17,
                      color: fimaTheme.accentColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Permissions — ${widget.item.name}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: fimaTheme.textColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 16,
                        color: fimaTheme.secondaryTextColor,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 16,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: _loading
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: fimaTheme.accentColor,
                          ),
                        ),
                      )
                    : _loadError != null
                    ? Text(
                        _loadError!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12.5,
                        ),
                      )
                    : PosixPermissionsEditor(
                        itemPath: widget.item.path,
                        initialModeBits: _initialModeBits!,
                        onApplied: (newBits) {
                          ref
                              .read(overlayProvider.notifier)
                              .showToast(
                                'Permissions updated: ${ItemMetadataService.formatPermissionsFromBits(newBits)}',
                              );
                          Navigator.of(context).pop();
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Interactive POSIX permission editor (Owner / Group / Others matrix + octal).
class PosixPermissionsEditor extends ConsumerStatefulWidget {
  final String itemPath;
  final int initialModeBits;
  final ValueChanged<int>? onApplied;

  const PosixPermissionsEditor({
    super.key,
    required this.itemPath,
    required this.initialModeBits,
    this.onApplied,
  });

  @override
  ConsumerState<PosixPermissionsEditor> createState() =>
      _PosixPermissionsEditorState();
}

class _PosixPermissionsEditorState
    extends ConsumerState<PosixPermissionsEditor> {
  late int _savedBits;
  late int _editedBits;
  late TextEditingController _octalController;
  bool _applying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _savedBits = widget.initialModeBits & 0xFFF;
    _editedBits = _savedBits;
    _octalController = TextEditingController(
      text: (_editedBits & 0xFFF).toRadixString(8).padLeft(4, '0'),
    );
  }

  @override
  void didUpdateWidget(covariant PosixPermissionsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialModeBits != widget.initialModeBits &&
        !_applying &&
        _editedBits == _savedBits) {
      _savedBits = widget.initialModeBits & 0xFFF;
      _editedBits = _savedBits;
      _octalController.text = _savedBits.toRadixString(8).padLeft(4, '0');
    }
  }

  @override
  void dispose() {
    _octalController.dispose();
    super.dispose();
  }

  void _toggleBit(int mask) {
    setState(() {
      _error = null;
      _editedBits ^= mask;
      _octalController.text = _editedBits.toRadixString(8).padLeft(4, '0');
    });
  }

  void _onOctalChanged(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed.length > 4) return;
    final parsed = int.tryParse(trimmed, radix: 8);
    if (parsed == null || parsed < 0 || parsed > 0xFFF) return;
    setState(() {
      _error = null;
      _editedBits = parsed;
    });
  }

  Future<void> _applyPermissions() async {
    setState(() {
      _applying = true;
      _error = null;
    });

    try {
      final repository = ref.read(fileSystemRepositoryProvider);
      await ItemMetadataService.setPermissions(
        path: widget.itemPath,
        modeBits: _editedBits,
        repository: repository,
      );
      if (!mounted) return;
      setState(() {
        _applying = false;
        _savedBits = _editedBits;
      });
      widget.onApplied?.call(_editedBits);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _applying = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fimaTheme = ref.watch(themeProvider);
    final isDirty = _editedBits != _savedBits;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const SizedBox(width: 72),
            _columnTitle('Read', fimaTheme),
            _columnTitle('Write', fimaTheme),
            _columnTitle('Execute', fimaTheme),
          ],
        ),
        const SizedBox(height: 4),
        _buildRoleRow('Owner', 0x100, 0x080, 0x040, fimaTheme),
        _buildRoleRow('Group', 0x020, 0x010, 0x008, fimaTheme),
        _buildRoleRow('Others', 0x004, 0x002, 0x001, fimaTheme),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              'Octal:',
              style: TextStyle(
                fontSize: 12,
                color: fimaTheme.secondaryTextColor,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 68,
              child: TextField(
                controller: _octalController,
                onChanged: _onOctalChanged,
                maxLength: 4,
                style: TextStyle(
                  fontSize: 12.5,
                  fontFamily: 'monospace',
                  color: fimaTheme.textColor,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-7]')),
                ],
                decoration: InputDecoration(
                  counterText: '',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  filled: true,
                  fillColor: fimaTheme.surfaceColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                    borderSide: BorderSide(color: fimaTheme.borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                    borderSide: BorderSide(color: fimaTheme.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                    borderSide: BorderSide(color: fimaTheme.accentColor),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                ItemMetadataService.formatPermissionsFromBits(_editedBits),
                style: TextStyle(
                  fontSize: 11.5,
                  fontFamily: 'monospace',
                  color: fimaTheme.secondaryTextColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            FilledButton(
              onPressed: (isDirty && !_applying) ? _applyPermissions : null,
              style: FilledButton.styleFrom(
                backgroundColor: fimaTheme.accentColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                minimumSize: const Size(0, 30),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: _applying
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Apply',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 6),
          Text(
            _error!,
            style: const TextStyle(fontSize: 11.5, color: Colors.redAccent),
          ),
        ],
      ],
    );
  }

  Widget _columnTitle(String label, FimaTheme fimaTheme) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: fimaTheme.secondaryTextColor,
          ),
        ),
      ),
    );
  }

  Widget _buildRoleRow(
    String roleLabel,
    int readMask,
    int writeMask,
    int execMask,
    FimaTheme fimaTheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              roleLabel,
              style: TextStyle(fontSize: 12.5, color: fimaTheme.textColor),
            ),
          ),
          _permCheck(readMask, fimaTheme),
          _permCheck(writeMask, fimaTheme),
          _permCheck(execMask, fimaTheme),
        ],
      ),
    );
  }

  Widget _permCheck(int mask, FimaTheme fimaTheme) {
    final checked = (_editedBits & mask) != 0;
    return Expanded(
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: checked,
            activeColor: fimaTheme.accentColor,
            side: BorderSide(color: fimaTheme.secondaryTextColor),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: _applying ? null : (_) => _toggleBit(mask),
          ),
        ),
      ),
    );
  }
}

