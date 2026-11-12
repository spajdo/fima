import 'dart:io';

import 'package:fima/domain/entity/file_system_item.dart';
import 'package:fima/presentation/widgets/popups/file_preview_dialog.dart';
import 'package:fima/presentation/widgets/popups/image_preview_dialog.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

FileSystemItem _makeFileItem(File file) {
  final stat = file.statSync();
  return FileSystemItem(
    path: file.path,
    name: p.basename(file.path),
    size: stat.size,
    modified: stat.modified,
    isDirectory: false,
  );
}

Future<void> _pumpUntilLoaded(WidgetTester tester) async {
  await tester.pump();
  for (int i = 0; i < 40; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      break;
    }
  }
  await tester.pumpAndSettle();
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('fima_preview_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('FilePreviewDialog 5MB limit', () {
    testWidgets('previews text files larger than 100KB (e.g. 250KB)', (
      tester,
    ) async {
      final file = File(p.join(tempDir.path, 'large_note.txt'));
      final content = 'Hello Fima preview!\n' * 13000; // ~260 KB
      file.writeAsStringSync(content);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilePreviewDialog(fileItem: _makeFileItem(file)),
          ),
        ),
      );

      await _pumpUntilLoaded(tester);

      expect(
        find.text('File is too large to preview (limit 5MB).'),
        findsNothing,
      );
      expect(find.text('Hello Fima preview!'), findsWidgets);
    });

    testWidgets('rejects text files larger than 5MB', (tester) async {
      final file = File(p.join(tempDir.path, 'huge.txt'));
      final raf = file.openSync(mode: FileMode.write);
      raf.setPositionSync(5 * 1024 * 1024 + 10);
      raf.writeByteSync(65);
      raf.closeSync();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilePreviewDialog(fileItem: _makeFileItem(file)),
          ),
        ),
      );

      await _pumpUntilLoaded(tester);

      expect(
        find.text('File is too large to preview (limit 5MB).'),
        findsOneWidget,
      );
    });
  });

  group('ImagePreviewDialog', () {
    test('recognizes supported image extensions case-insensitively', () {
      for (final ext in ['png', 'PNG', 'jpg', 'jpeg', 'ico', 'svg', 'gif']) {
        expect(ImagePreviewDialog.isSupportedImageFile('photo.$ext'), isTrue);
      }
      for (final ext in ['txt', 'md', 'json', 'xml', 'pdf']) {
        expect(ImagePreviewDialog.isSupportedImageFile('doc.$ext'), isFalse);
      }
    });

    testWidgets('renders PNG image and zooms only with Cmd/Ctrl + scroll', (
      tester,
    ) async {
      final image = img.Image(width: 64, height: 64);
      img.fill(image, color: img.ColorRgb8(0, 128, 255));
      final pngFile = File(p.join(tempDir.path, 'sample.png'));
      pngFile.writeAsBytesSync(img.encodePng(image));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImagePreviewDialog(fileItem: _makeFileItem(pngFile)),
          ),
        ),
      );

      await _pumpUntilLoaded(tester);

      expect(find.byType(Image), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);

      final viewerCenter = tester.getCenter(find.byType(InteractiveViewer));

      // Bare scroll without Cmd/Ctrl must NOT zoom.
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(viewerCenter));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -100)));
      await tester.pumpAndSettle();
      expect(find.text('100%'), findsOneWidget);

      // Scroll WITH Ctrl pressed MUST zoom in.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -100)));
      await tester.pumpAndSettle();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      expect(find.text('100%'), findsNothing);

      // Reset button brings scale back to 100%.
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('decodes and renders ICO image', (tester) async {
      final image = img.Image(width: 32, height: 32);
      img.fill(image, color: img.ColorRgb8(255, 64, 64));
      final icoFile = File(p.join(tempDir.path, 'favicon.ico'));
      icoFile.writeAsBytesSync(img.encodeIco(image));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImagePreviewDialog(fileItem: _makeFileItem(icoFile)),
          ),
        ),
      );

      await _pumpUntilLoaded(tester);

      expect(find.byType(Image), findsOneWidget);
      expect(find.textContaining('Cannot'), findsNothing);
    });

    testWidgets('renders SVG image', (tester) async {
      final svgFile = File(p.join(tempDir.path, 'icon.svg'));
      svgFile.writeAsStringSync(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
        '<circle cx="12" cy="12" r="10" fill="red"/>'
        '</svg>',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImagePreviewDialog(fileItem: _makeFileItem(svgFile)),
          ),
        ),
      );

      await _pumpUntilLoaded(tester);

      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.textContaining('Cannot'), findsNothing);
    });

    testWidgets('supports panning via left mouse drag', (tester) async {
      final image = img.Image(width: 64, height: 64);
      img.fill(image, color: img.ColorRgb8(32, 200, 96));
      final pngFile = File(p.join(tempDir.path, 'pan.png'));
      pngFile.writeAsBytesSync(img.encodePng(image));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImagePreviewDialog(fileItem: _makeFileItem(pngFile)),
          ),
        ),
      );

      await _pumpUntilLoaded(tester);

      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      final controller = viewer.transformationController!;
      expect(controller.value, equals(Matrix4.identity()));

      final center = tester.getCenter(find.byType(InteractiveViewer));
      await tester.dragFrom(center, const Offset(80, 40));
      await tester.pumpAndSettle();

      final translation = controller.value.getTranslation();
      expect(translation.x, greaterThan(40.0));
      expect(translation.y, greaterThan(15.0));
    });
  });
}
