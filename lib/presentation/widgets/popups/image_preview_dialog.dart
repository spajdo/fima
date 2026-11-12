import 'dart:io';
import 'dart:math' as math;

import 'package:fima/domain/entity/file_system_item.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

const int _maxImageFileSizeBytes = 50 * 1024 * 1024;
const double _minZoomScale = 0.1;
const double _maxZoomScale = 10.0;
const double _zoomButtonFactor = 1.25;

class _DecodedImagePayload {
  final Uint8List? bytes;
  final String? error;

  const _DecodedImagePayload({this.bytes, this.error});
}

Future<_DecodedImagePayload> _loadSpecialImageInBackground(
  Map<String, String> args,
) async {
  final path = args['path'] ?? '';
  final ext = args['ext'] ?? '';

  final file = File(path);
  if (!file.existsSync()) {
    return const _DecodedImagePayload(error: 'File does not exist.');
  }

  final length = file.lengthSync();
  if (length > _maxImageFileSizeBytes) {
    return const _DecodedImagePayload(
      error: 'Image is too large to preview (limit 50MB).',
    );
  }

  final bytes = file.readAsBytesSync();
  if (bytes.isEmpty) {
    return const _DecodedImagePayload(error: 'Image file is empty.');
  }

  if (ext == '.ico') {
    final decoded = img.decodeIco(bytes);
    if (decoded == null || decoded.frames.isEmpty) {
      return const _DecodedImagePayload(error: 'Cannot decode ICO image.');
    }

    // Pick the highest-resolution frame inside the ICO container.
    var bestFrame = decoded.frames.first;
    for (final frame in decoded.frames) {
      if (frame.width * frame.height > bestFrame.width * bestFrame.height) {
        bestFrame = frame;
      }
    }

    final pngBytes = img.encodePng(bestFrame, singleFrame: true);
    return _DecodedImagePayload(bytes: pngBytes);
  }

  return _DecodedImagePayload(bytes: bytes);
}

/// Modal dialog for previewing image files with Cmd/Ctrl + scroll zoom and
/// left-mouse drag panning.
class ImagePreviewDialog extends StatefulWidget {
  final FileSystemItem fileItem;

  const ImagePreviewDialog({super.key, required this.fileItem});

  static const Set<String> supportedExtensions = {
    '.png',
    '.jpg',
    '.jpeg',
    '.ico',
    '.svg',
    '.gif',
  };

  /// Returns true when [fileName] has a supported image extension.
  static bool isSupportedImageFile(String fileName) {
    return supportedExtensions.contains(p.extension(fileName).toLowerCase());
  }

  @override
  State<ImagePreviewDialog> createState() => _ImagePreviewDialogState();
}

class _ImagePreviewDialogState extends State<ImagePreviewDialog> {
  final TransformationController _transformationController =
      TransformationController();
  final GlobalKey _viewportKey = GlobalKey();

  bool _isLoading = true;
  String? _error;
  Uint8List? _memoryBytes;
  late final String _ext;
  double _currentScale = 1.0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _ext = p.extension(widget.fileItem.name).toLowerCase();
    _transformationController.addListener(_onTransformChanged);
    _loadImage();
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformChanged);
    _transformationController.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final nextScale = _transformationController.value.getMaxScaleOnAxis();
    if ((nextScale - _currentScale).abs() > 0.001 && mounted) {
      setState(() => _currentScale = nextScale);
    }
  }

  Future<void> _loadImage() async {
    try {
      if (_ext == '.ico' || _ext == '.svg') {
        final payload = await compute(_loadSpecialImageInBackground, {
          'path': widget.fileItem.path,
          'ext': _ext,
        });
        if (!mounted) return;
        setState(() {
          _memoryBytes = payload.bytes;
          _error = payload.error;
          _isLoading = false;
        });
        return;
      }

      final file = File(widget.fileItem.path);
      if (!await file.exists()) {
        if (!mounted) return;
        setState(() {
          _error = 'File does not exist.';
          _isLoading = false;
        });
        return;
      }

      final length = await file.length();
      if (length > _maxImageFileSizeBytes) {
        if (!mounted) return;
        setState(() {
          _error = 'Image is too large to preview (limit 50MB).';
          _isLoading = false;
        });
        return;
      }

      if (length == 0) {
        if (!mounted) return;
        setState(() {
          _error = 'Image file is empty.';
          _isLoading = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Cannot load image: $e';
        _isLoading = false;
      });
    }
  }

  void _zoomAtPoint(Offset viewportFocalPoint, double scaleChange) {
    final matrix = _transformationController.value;
    final currentScale = matrix.getMaxScaleOnAxis();
    final targetScale = (currentScale * scaleChange).clamp(
      _minZoomScale,
      _maxZoomScale,
    );
    final effectiveScaleChange = targetScale / currentScale;
    if ((effectiveScaleChange - 1.0).abs() < 1e-6) return;

    final focalPointScene = _transformationController.toScene(
      viewportFocalPoint,
    );
    final updated = matrix.clone()
      ..scaleByDouble(
        effectiveScaleChange,
        effectiveScaleChange,
        effectiveScaleChange,
        1.0,
      );
    final focalPointSceneScaled = TransformationController(
      updated,
    ).toScene(viewportFocalPoint);
    final delta = focalPointSceneScaled - focalPointScene;
    updated.translateByDouble(delta.dx, delta.dy, 0.0, 1.0);

    _transformationController.value = updated;
  }

  void _zoomCentered(double scaleChange) {
    final renderBox =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final center = renderBox.size.center(Offset.zero);
    _zoomAtPoint(center, scaleChange);
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;

    final keyboard = HardwareKeyboard.instance;
    final isModifierPressed =
        keyboard.isMetaPressed || keyboard.isControlPressed;
    if (!isModifierPressed || event.scrollDelta.dy == 0.0) return;

    final scaleChange = math.exp(-event.scrollDelta.dy / 250.0);
    _zoomAtPoint(event.localPosition, scaleChange);
  }

  Widget _buildImageWidget() {
    if (_ext == '.svg') {
      final bytes = _memoryBytes;
      if (bytes == null) {
        return const Text(
          'Cannot load SVG image.',
          style: TextStyle(color: Colors.redAccent),
        );
      }
      return SvgPicture.memory(
        bytes,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Text(
          'Cannot render SVG image: $error',
          style: const TextStyle(color: Colors.redAccent),
        ),
      );
    }

    if (_ext == '.ico') {
      final bytes = _memoryBytes;
      if (bytes == null) {
        return const Text(
          'Cannot decode ICO image.',
          style: TextStyle(color: Colors.redAccent),
        );
      }
      return Image.memory(
        bytes,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) => Text(
          'Cannot render ICO image: $error',
          style: const TextStyle(color: Colors.redAccent),
        ),
      );
    }

    return Image.file(
      File(widget.fileItem.path),
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) => Text(
        'Cannot render image: $error',
        style: const TextStyle(color: Colors.redAccent),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
      );
    }

    return ClipRect(
      child: CustomPaint(
        painter: const _CheckerboardPainter(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return MouseRegion(
              cursor: _isDragging
                  ? SystemMouseCursors.grabbing
                  : SystemMouseCursors.grab,
              child: Listener(
                key: _viewportKey,
                behavior: HitTestBehavior.opaque,
                onPointerDown: (event) {
                  if (event.buttons == kPrimaryMouseButton && !_isDragging) {
                    setState(() => _isDragging = true);
                  }
                },
                onPointerUp: (_) {
                  if (_isDragging) setState(() => _isDragging = false);
                },
                onPointerCancel: (_) {
                  if (_isDragging) setState(() => _isDragging = false);
                },
                onPointerSignal: _handlePointerSignal,
                child: GestureDetector(
                  onDoubleTap: _resetZoom,
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    panEnabled: true,
                    // Scale via InteractiveViewer is disabled so bare mouse-wheel
                    // scroll does not zoom; Cmd/Ctrl + scroll is handled above.
                    scaleEnabled: false,
                    boundaryMargin: const EdgeInsets.all(double.infinity),
                    minScale: _minZoomScale,
                    maxScale: _maxZoomScale,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _buildImageWidget(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zoomPercent = (_currentScale * 100).round();

    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFF333333)),
      ),
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;

          if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          }

          final keyboard = HardwareKeyboard.instance;
          final isModifierPressed =
              keyboard.isMetaPressed || keyboard.isControlPressed;
          if (!isModifierPressed) return KeyEventResult.ignored;

          if (event.logicalKey == LogicalKeyboardKey.digit0 ||
              event.logicalKey == LogicalKeyboardKey.numpad0) {
            _resetZoom();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.equal ||
              event.logicalKey == LogicalKeyboardKey.add ||
              event.logicalKey == LogicalKeyboardKey.numpadAdd) {
            _zoomCentered(_zoomButtonFactor);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.minus ||
              event.logicalKey == LogicalKeyboardKey.numpadSubtract) {
            _zoomCentered(1 / _zoomButtonFactor);
            return KeyEventResult.handled;
          }

          return KeyEventResult.ignored;
        },
        child: Container(
          width: MediaQuery.of(context).size.width * 0.92,
          height: MediaQuery.of(context).size.height * 0.92,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.fileItem.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!_isLoading && _error == null) ...[
                    IconButton(
                      icon: const Icon(
                        Icons.zoom_out,
                        color: Colors.grey,
                        size: 20,
                      ),
                      onPressed: () => _zoomCentered(1 / _zoomButtonFactor),
                      tooltip: 'Zoom out',
                    ),
                    Text(
                      '$zoomPercent%',
                      style: const TextStyle(
                        color: Color(0xFFD4D4D4),
                        fontSize: 13,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.zoom_in,
                        color: Colors.grey,
                        size: 20,
                      ),
                      onPressed: () => _zoomCentered(_zoomButtonFactor),
                      tooltip: 'Zoom in',
                    ),
                    TextButton(
                      onPressed: _resetZoom,
                      child: const Text('Reset'),
                    ),
                  ],
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close (Esc)',
                  ),
                ],
              ),
              const Divider(color: Color(0xFF333333)),
              Expanded(child: _buildBody()),
              if (!_isLoading && _error == null) ...[
                const SizedBox(height: 8),
                Text(
                  'Cmd/Ctrl + Scroll to zoom  •  Left-drag to pan  •  Double-click to reset',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckerboardPainter extends CustomPainter {
  const _CheckerboardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const tileSize = 16.0;
    final lightPaint = Paint()..color = const Color(0xFF252526);
    final darkPaint = Paint()..color = const Color(0xFF1E1E1E);

    canvas.drawRect(Offset.zero & size, darkPaint);

    final cols = (size.width / tileSize).ceil();
    final rows = (size.height / tileSize).ceil();

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if ((r + c).isEven) {
          canvas.drawRect(
            Rect.fromLTWH(c * tileSize, r * tileSize, tileSize, tileSize),
            lightPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
