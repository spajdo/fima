import 'dart:io';

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

      final currentVersion = await AppVersion.load();

      expect(find.byType(FimaAboutDialog), findsOneWidget);
      expect(find.text('Version ${currentVersion.formatted}'), findsOneWidget);
      expect(find.text(currentVersion.formatted), findsOneWidget);
      expect(find.text('https://github.com/spajdo/fima'), findsOneWidget);
      expect(find.text('Open-Source Licenses'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Close'));
      await tester.pumpAndSettle();

      expect(find.byType(FimaAboutDialog), findsNothing);
      expect(find.byType(ShortcutsDialog), findsOneWidget);
    },
  );

  group('AppVersion', () {
    test('parses version and build number from pubspec content', () {
      const sample = '''
name: fima
description: Two panel file manager
version: 2.3.4+42
environment:
  sdk: ^3.10.0
''';
      final version = AppVersion.parseFromPubspecYaml(sample);
      expect(version, isNotNull);
      expect(version!.buildName, '2.3.4');
      expect(version.buildNumber, '42');
      expect(version.formatted, '2.3.4 (42)');
    });

    test('parses version without build number from pubspec content', () {
      const sample = '''
name: fima
version: 0.9.1
''';
      final version = AppVersion.parseFromPubspecYaml(sample);
      expect(version, isNotNull);
      expect(version!.buildName, '0.9.1');
      expect(version.buildNumber, '');
      expect(version.formatted, '0.9.1');
    });

    testWidgets(
      'AppVersion.load dynamically reads current version from pubspec.yaml',
      (tester) async {
        final expected = AppVersion.parseFromPubspecYaml(
          File('pubspec.yaml').readAsStringSync(),
        );
        final version = await AppVersion.load();
        expect(version.buildName, expected?.buildName);
        expect(version.buildNumber, expected?.buildNumber);
        expect(version.buildName, isNotEmpty);
      },
    );
  });
}
