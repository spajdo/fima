import 'package:fima/presentation/widgets/keyboard_handler.dart';
import 'package:fima/presentation/widgets/main_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: FimaApp()));
}

class FimaApp extends StatelessWidget {
  const FimaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fima - File Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const KeyboardHandler(
        child: MainScreen(),
      ),
    );
  }
}
