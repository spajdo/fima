import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fima/presentation/widgets/popups/about_dialog.dart';
import 'package:fima/presentation/widgets/popups/shortcuts_dialog.dart';

void main() {
  testWidgets(
    'ShortcutsDialog opens FimaAboutDialog with version, build, and repo link',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const ShortcutsDialog(),
                  ),
                  child: const Text('Open Shortcuts'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Shortcuts'));
      await tester.pumpAndSettle();

      expect(find.byType(ShortcutsDialog), findsOneWidget);
      expect(find.text('About fima'), findsWidgets);

      await tester.tap(find.widgetWithText(OutlinedButton, 'About fima'));
      await tester.pumpAndSettle();

      expect(find.byType(FimaAboutDialog), findsOneWidget);
      expect(find.text('Version 1.0.0 (1)'), findsOneWidget);
      expect(find.text('1.0.0 (1)'), findsOneWidget);
      expect(find.text('https://github.com/spajdo/fima'), findsOneWidget);
      expect(find.text('Open-Source Licenses'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Close'));
      await tester.pumpAndSettle();

      expect(find.byType(FimaAboutDialog), findsNothing);
      expect(find.byType(ShortcutsDialog), findsOneWidget);
    },
  );
}

