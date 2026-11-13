import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';

import 'package:fima/infrastructure/service/metadata/item_metadata_models.dart';

/// Computes MD5 and SHA-256 digests in a background isolate.
class FileChecksumService {
  const FileChecksumService._();

  static Future<DirectoryStatsHandle> startCalculation({
    required String filePath,
    required void Function(FileChecksums? result, String? error) onDone,
  }) async {
    final receivePort = ReceivePort();
    Isolate? isolate;
    bool cancelled = false;

    receivePort.listen((message) {
      if (cancelled) return;
      if (message is Map<String, dynamic>) {
        final error = message['error'] as String?;
        if (error != null) {
          onDone(null, error);
        } else {
          onDone(
            FileChecksums(
              md5Hex: message['md5'] as String,
              sha256Hex: message['sha256'] as String,
            ),
            null,
          );
        }
        receivePort.close();
      }
    });

    try {
      isolate = await Isolate.spawn(_isolateCalculateChecksums, {
        'sendPort': receivePort.sendPort,
        'filePath': filePath,
      });
    } catch (e) {
      receivePort.close();
      onDone(null, e.toString());
    }

    return DirectoryStatsHandle(() {
      cancelled = true;
      isolate?.kill(priority: Isolate.immediate);
      receivePort.close();
    });
  }
}

class _SingleDigestSink implements Sink<Digest> {
  Digest? digest;

  @override
  void add(Digest data) {
    digest = data;
  }

  @override
  void close() {}
}

Future<void> _isolateCalculateChecksums(Map<String, dynamic> args) async {
  final sendPort = args['sendPort'] as SendPort;
  final filePath = args['filePath'] as String;

  try {
    final md5Sink = _SingleDigestSink();
    final shaSink = _SingleDigestSink();
    final md5Input = md5.startChunkedConversion(md5Sink);
    final shaInput = sha256.startChunkedConversion(shaSink);

    final stream = File(filePath).openRead();
    await for (final chunk in stream) {
      md5Input.add(chunk);
      shaInput.add(chunk);
    }

    md5Input.close();
    shaInput.close();

    sendPort.send({
      'md5': md5Sink.digest.toString(),
      'sha256': shaSink.digest.toString(),
    });
  } catch (e) {
    sendPort.send({'error': e.toString()});
  }
}
