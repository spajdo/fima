import 'dart:async';
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

  /// Called whenever the terminal's current working directory changes.
  /// Receives the new absolute path as a [String].
  final void Function(String path)? onDirectoryChanged;

  const BuiltInTerminalWidget({
    super.key,
    required this.width,
    required this.height,
    required this.initialPath,
    required this.isLeftPanel,
    required this.onClose,
    this.onDirectoryChanged,
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

  /// The last CWD we reported to [widget.onDirectoryChanged].
  String _lastKnownCwd = '';

  /// Fallback polling timer for shells that do not emit OSC 7.
  Timer? _cwdPollTimer;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _keyListenerFocusNode = FocusNode();
    _lastKnownCwd = widget.initialPath;

    // Create terminal with OSC 7 handler (primary CWD detection).
    _terminal = Terminal(maxLines: 10000, onPrivateOSC: _handleOsc);

    _startPty();

    // Grab Flutter focus initially (on first frame after build).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  // ── OSC 7 handler ─────────────────────────────────────────────────────────

  /// Called by xterm for every unrecognized / private OSC sequence.
  /// OSC 7 format: `ESC ] 7 ; file:///path BEL`
  void _handleOsc(String code, List<String> args) {
    if (code != '7' || args.isEmpty) return;
    final uri = Uri.tryParse(args.first);
    if (uri == null) return;
    try {
      final path = uri.toFilePath();
      _onCwdChanged(path);
    } catch (_) {
      // Ignore malformed URIs.
    }
  }

  // ── Polling fallback ───────────────────────────────────────────────────────

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

      // Start fallback polling after the PTY is ready.
      _startCwdPolling();
    } catch (e) {
      _terminal.write('Error starting terminal: $e\r\n');
      setState(() => _ptyStarted = true);
    }
  }

  /// Starts a 1-second timer that polls the OS for the PTY child's CWD.
  /// On shells that emit OSC 7 (zsh, fish, bash 5.1+, pwsh) this timer
  /// fires but immediately returns because [_lastKnownCwd] is already
  /// up to date, so it has virtually zero overhead in practice.
  void _startCwdPolling() {
    _cwdPollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _pollCwd();
    });
  }

  /// Queries the OS for the current working directory of the PTY process.
  Future<void> _pollCwd() async {
    if (_pty == null) return;
    final pid = _pty!.pid;

    try {
      String? resolved;

      if (Platform.isLinux) {
        // Fast path: read the /proc symlink — no subprocess required.
        resolved = await Link('/proc/$pid/cwd').resolveSymbolicLinks();
      } else if (Platform.isMacOS) {
        // lsof reports the CWD of the child shell process.
        final result = await Process.run('/bin/sh', [
          '-c',
          'lsof -a -p $pid -d cwd -Fn 2>/dev/null | grep "^n" | head -1',
        ]);
        final stdout = (result.stdout as String).trim();
        if (stdout.startsWith('n')) {
          resolved = stdout.substring(1);
        }
      } else if (Platform.isWindows) {
        // wmic reliably returns the WorkingDirectory for any process.
        final result = await Process.run('wmic', [
          'process',
          'where',
          'processid=$pid',
          'get',
          'WorkingDirectory',
          '/format:list',
        ], runInShell: true);
        final stdout = result.stdout as String;
        for (final line in stdout.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.startsWith('WorkingDirectory=')) {
            resolved = trimmed.substring('WorkingDirectory='.length).trim();
            // Remove trailing backslash except for drive roots (e.g. C:\).
            if (resolved.length > 3 && resolved.endsWith('\\')) {
              resolved = resolved.substring(0, resolved.length - 1);
            }
            break;
          }
        }
      }

      if (resolved != null && resolved.isNotEmpty) {
        _onCwdChanged(resolved);
      }
    } catch (_) {
      // Polling is best-effort; ignore errors silently.
    }
  }

  // ── Common CWD change handler ──────────────────────────────────────────────

  /// Called from both OSC 7 and the polling fallback.
  /// De-duplicates changes and notifies the parent widget.
  void _onCwdChanged(String newPath) {
    if (newPath == _lastKnownCwd) return;
    _lastKnownCwd = newPath;

    // Update the toolbar label.
    if (mounted) setState(() {});

    widget.onDirectoryChanged?.call(newPath);
  }

  // ── Focus helpers ──────────────────────────────────────────────────────────

  /// Returns true when the active Riverpod panel matches this terminal's panel.
  bool _terminalPanelIsActive(FocusState focusState) {
    return widget.isLeftPanel
        ? focusState.activePanel == ActivePanel.left
        : focusState.activePanel == ActivePanel.right;
  }

  @override
  void dispose() {
    _cwdPollTimer?.cancel();
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
    // When the user switches to the opposite panel we must hand focus
    // explicitly to the KeyboardHandler's Focus node.  Simply calling
    // _focusNode.unfocus() is not enough — Flutter's unfocus() can fire
    // one frame *after* FilePanel's requestFocus(), overwriting it and
    // leaving no focused node (which manifests as the first keypress being
    // swallowed).  By calling requestFocus() on the shared KeyboardHandler
    // node we guarantee a clean, race-free handoff.
    final keyboardFocusNode = ref.read(keyboardHandlerFocusNodeProvider);
    ref.listen<FocusState>(focusProvider, (previous, next) {
      if (!mounted) return;
      if (_terminalPanelIsActive(next)) {
        // User switched back to our panel → grab focus.
        _focusNode.requestFocus();
      } else {
        // User switched to the opposite panel → hand focus directly to the
        // KeyboardHandler so there is no focus gap.
        keyboardFocusNode.requestFocus();
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
                      // Show the live CWD rather than the static initial path.
                      'Terminal — $_lastKnownCwd',
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
