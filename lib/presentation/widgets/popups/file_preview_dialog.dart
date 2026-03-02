import 'dart:convert';
import 'dart:io';
import 'package:fima/domain/entity/file_system_item.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

class _PreviewResult {
  final String rawText;
  final String? previewText;

  _PreviewResult(this.rawText, this.previewText);
}

// Top-level function required by compute() — runs in a background isolate
Future<dynamic> _readFileInBackground(Map<String, dynamic> args) async {
  final path = args['path'] as String;
  final isJson = args['isJson'] as bool;
  final isXml = args['isXml'] as bool;

  final file = File(path);
  if (!file.existsSync()) return null;

  final length = file.lengthSync();
  if (length > 1024 * 100) return '__TOO_LARGE__';

  final bytes = file.readAsBytesSync();

  // Binary check: look for null bytes in first 1KB
  final checkLen = bytes.length < 1024 ? bytes.length : 1024;
  for (int i = 0; i < checkLen; i++) {
    if (bytes[i] == 0) return '__BINARY__';
  }

  final rawText = utf8.decode(bytes, allowMalformed: true);
  String? previewText;

  if (isJson) {
    try {
      final decodedResponse = jsonDecode(rawText);
      previewText = const JsonEncoder.withIndent('  ').convert(decodedResponse);
    } catch (_) {
      // Ignore parse errors, fallback to raw
    }
  } else if (isXml) {
    try {
      final document = XmlDocument.parse(rawText);
      previewText = document.toXmlString(pretty: true, indent: '  ');
    } catch (_) {
      // Ignore parse errors, fallback to raw
    }
  }

  return _PreviewResult(rawText, previewText);
}

class FilePreviewDialog extends StatefulWidget {
  final FileSystemItem fileItem;

  const FilePreviewDialog({super.key, required this.fileItem});

  @override
  State<FilePreviewDialog> createState() => _FilePreviewDialogState();
}

enum _PreviewMode { preview, raw }

class _FilePreviewDialogState extends State<FilePreviewDialog> {
  String? _error;
  bool _isLoading = true;
  List<String> _lines = [];
  String _rawText = '';
  late final ScrollController _scrollController;

  _PreviewMode _mode = _PreviewMode.preview;
  bool _isMarkdown = false;
  bool _isHtml = false;
  bool _isJson = false;
  bool _isXml = false;
  List<String> _previewLines = [];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    final ext = p.extension(widget.fileItem.name).toLowerCase();
    _isMarkdown = ext == '.md' || ext == '.markdown';
    _isHtml = ext == '.html' || ext == '.htm';
    _isJson = ext == '.json';
    _isXml = ext == '.xml';

    // Default to raw if not supported
    if (!_isMarkdown && !_isHtml && !_isJson && !_isXml) {
      _mode = _PreviewMode.raw;
    }

    _loadFileContent();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFileContent() async {
    try {
      final result = await compute(_readFileInBackground, {
        'path': widget.fileItem.path,
        'isJson': _isJson,
        'isXml': _isXml,
      });

      if (!mounted) return;

      if (result == null) {
        setState(() {
          _error = 'File does not exist.';
          _isLoading = false;
        });
      } else if (result == '__TOO_LARGE__') {
        setState(() {
          _error = 'File is too large to preview (limit 100KB).';
          _isLoading = false;
        });
      } else if (result == '__BINARY__') {
        setState(() {
          _error = 'Binary file format is not supported for preview.';
          _isLoading = false;
        });
      } else if (result is _PreviewResult) {
        setState(() {
          _rawText = result.rawText;
          _lines = result.rawText.split('\n');
          _previewLines = result.previewText?.split('\n') ?? _lines;

          if ((_isJson || _isXml) && result.previewText == null) {
            _mode = _PreviewMode.raw;
            _isJson = false;
            _isXml = false;
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Cannot read file: $e';
        _isLoading = false;
      });
    }
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
      );
    }

    if (_mode == _PreviewMode.preview) {
      if (_isMarkdown) {
        return Markdown(
          data: _rawText,
          selectable: true,
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            p: const TextStyle(color: Color(0xFFD4D4D4), fontSize: 14),
            h1: const TextStyle(color: Colors.white),
            h2: const TextStyle(color: Colors.white),
            h3: const TextStyle(color: Colors.white),
            h4: const TextStyle(color: Colors.white),
            h5: const TextStyle(color: Colors.white),
            h6: const TextStyle(color: Colors.white),
          ),
        );
      } else if (_isHtml) {
        return SingleChildScrollView(
          child: Html(
            data: _rawText,
            style: {
              "body": Style(
                color: const Color(0xFFD4D4D4),
                fontSize: FontSize(14.0),
              ),
              "h1": Style(color: Colors.white),
              "h2": Style(color: Colors.white),
              "h3": Style(color: Colors.white),
              "h4": Style(color: Colors.white),
              "h5": Style(color: Colors.white),
              "h6": Style(color: Colors.white),
            },
          ),
        );
      }
    }

    // Default Raw view OR Formatted Code (JSON/XML)
    final displayLines = (_mode == _PreviewMode.preview && (_isJson || _isXml))
        ? _previewLines
        : _lines;

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: SelectionArea(
        child: ListView.builder(
          controller: _scrollController,
          itemCount: displayLines.length,
          itemBuilder: (context, index) {
            return Text(
              displayLines[index],
              style: const TextStyle(
                fontFamily: 'monospace',
                color: Color(0xFFD4D4D4),
                fontSize: 13,
                height: 1.5,
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFF333333)),
      ),
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop();
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
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  if (_isMarkdown || _isHtml || _isJson || _isXml)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: SegmentedButton<_PreviewMode>(
                        segments: const [
                          ButtonSegment(
                            value: _PreviewMode.preview,
                            label: Text('Preview'),
                          ),
                          ButtonSegment(
                            value: _PreviewMode.raw,
                            label: Text('Raw'),
                          ),
                        ],
                        selected: <_PreviewMode>{_mode},
                        onSelectionChanged: (Set<_PreviewMode> newSelection) {
                          setState(() {
                            _mode = newSelection.first;
                          });
                        },
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          backgroundColor:
                              WidgetStateProperty.resolveWith<Color>((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return Theme.of(
                                    context,
                                  ).primaryColor.withValues(alpha: 0.3);
                                }
                                return Colors.transparent;
                              }),
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close (Esc)',
                  ),
                ],
              ),
              const Divider(color: Color(0xFF333333)),
              // Body
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }
}
