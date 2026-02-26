import 'dart:convert';
import 'dart:io';

import 'package:fima/presentation/providers/focus_provider.dart';
import 'package:fima/presentation/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';

class BuiltInTerminalWidget extends ConsumerStatefulWidget {
  final double width;
  final double height;
  final String initialPath;
  final bool isLeftPanel;
  final VoidCallback onClose;

  const BuiltInTerminalWidget({
    super.key,
    required this.width,
    required this.height,
    required this.initialPath,
    required this.isLeftPanel,
    required this.onClose,
  });

  @override
  ConsumerState<BuiltInTerminalWidget> createState() =>
      _BuiltInTerminalWidgetState();
}

class _BuiltInTerminalWidgetState extends ConsumerState<BuiltInTerminalWidget> {
  late final Terminal _terminal;
  late final FocusNode _focusNode;
  late final FocusNode _keyListenerFocusNode;
  Pty? _pty;
  bool _ptyStarted = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _keyListenerFocusNode = FocusNode();
    _terminal = Terminal(maxLines: 10000);
    _startPty();

    // Grab Flutter focus initially (on first frame after build)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  String _shellExecutable() {
    if (Platform.isWindows) return 'cmd.exe';
    return Platform.environment['SHELL'] ?? 'bash';
  }

  void _startPty() {
    try {
      _pty = Pty.start(
        _shellExecutable(),
        columns: 220,
        rows: 50,
        environment: {
          ...Platform.environment,
          'TERM': 'xterm-256color',
          'LANG': 'en_US.UTF-8',
          'LC_ALL': 'en_US.UTF-8',
        },
        workingDirectory: widget.initialPath,
      );

      _pty!.output.cast<List<int>>().listen(
        (data) => _terminal.write(utf8.decode(data, allowMalformed: true)),
      );

      _pty!.exitCode.then((_) {
        if (mounted) widget.onClose();
      });

      _terminal.onOutput = (data) =>
          _pty!.write(Uint8List.fromList(utf8.encode(data)));
      _terminal.onResize = (w, h, pw, ph) => _pty!.resize(h, w);

      setState(() => _ptyStarted = true);
    } catch (e) {
      _terminal.write('Error starting terminal: $e\r\n');
      setState(() => _ptyStarted = true);
    }
  }

  // Returns true when the active Riverpod panel matches this terminal's panel.
  bool _terminalPanelIsActive(FocusState focusState) {
    return widget.isLeftPanel
        ? focusState.activePanel == ActivePanel.left
        : focusState.activePanel == ActivePanel.right;
  }

  @override
  void dispose() {
    _pty?.kill();
    _focusNode.dispose();
    _keyListenerFocusNode.dispose();
    super.dispose();
  }

  /// Show a confirmation dialog; close terminal only on OK.
  Future<void> _confirmClose() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Close terminal?'),
          content: const Text('The terminal session will be terminated.'),
          actions: [
            FilledButton(
              autofocus: true,
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      widget.onClose();
    } else if (mounted) {
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fimaTheme = ref.watch(themeProvider);
    final theme = Theme.of(context);

    // ── Focus management ───────────────────────────────────────────────────
    // Listen to panel focus changes so that switching to the opposite panel
    // explicitly moves Flutter focus away from TerminalView.  Without this
    // TerminalView would keep consuming ALL key events regardless of which
    // Riverpod panel is considered "active".
    ref.listen<FocusState>(focusProvider, (previous, next) {
      if (!mounted) return;
      if (_terminalPanelIsActive(next)) {
        // User switched back to our panel → grab focus.
        _focusNode.requestFocus();
      } else {
        // User switched to the opposite panel → release focus so the
        // KeyboardHandler's Focus widget can handle key events.
        _focusNode.unfocus();
      }
    });

    return KeyboardListener(
      focusNode: _keyListenerFocusNode,
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _confirmClose();
        }
      },
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: fimaTheme.backgroundColor,
          border: Border.all(color: fimaTheme.accentColor, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Toolbar ──────────────────────────────────────────────────
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: fimaTheme.surfaceColor,
                border: Border(
                  bottom: BorderSide(color: fimaTheme.borderColor),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.terminal, size: 14, color: fimaTheme.accentColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Terminal — ${widget.initialPath}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: fimaTheme.textColor,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: _confirmClose,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        size: 14,
                        color: fimaTheme.textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── Terminal view ─────────────────────────────────────────────
            Expanded(
              child: _ptyStarted
                  ? TerminalView(
                      _terminal,
                      focusNode: _focusNode,
                      autofocus: false,
                      backgroundOpacity: 1.0,
                      theme: TerminalTheme(
                        cursor: fimaTheme.accentColor,
                        selection: fimaTheme.accentColor.withValues(alpha: 0.4),
                        foreground: fimaTheme.textColor,
                        background: fimaTheme.backgroundColor,
                        black: Colors.black,
                        red: Colors.red,
                        green: Colors.green,
                        yellow: Colors.yellow,
                        blue: Colors.blue,
                        magenta: Colors.purple,
                        cyan: Colors.cyan,
                        white: Colors.white,
                        brightBlack: Colors.grey,
                        brightRed: Colors.redAccent,
                        brightGreen: Colors.greenAccent,
                        brightYellow: Colors.yellowAccent,
                        brightBlue: Colors.blueAccent,
                        brightMagenta: Colors.purpleAccent,
                        brightCyan: Colors.cyanAccent,
                        brightWhite: Colors.white,
                        searchHitBackground: Colors.orangeAccent,
                        searchHitBackgroundCurrent: Colors.orange,
                        searchHitForeground: Colors.black,
                      ),
                    )
                  : Center(
                      child: CircularProgressIndicator(
                        color: fimaTheme.accentColor,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
