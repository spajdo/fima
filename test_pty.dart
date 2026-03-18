import 'package:flutter_pty/flutter_pty.dart';
import 'dart:io';

void main() async {
  print('Starting Pty...');
  try {
    final shell = Platform.isWindows ? 'powershell.exe' : 'bash';
    final pty = Pty.start(shell, columns: 220, rows: 50);
    print('Pty started: ${pty.pid}');
    pty.exitCode.then((_) => print('Pty exited'));

    Future.delayed(Duration(seconds: 2), () {
      print('Killing pty...');
      pty.kill();
      exit(0);
    });
  } catch (e) {
    print('Error: $e');
  }
}
