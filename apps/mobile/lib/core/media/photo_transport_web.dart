import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'photo_transport.dart';

Future<Uint8List> downloadPhoto(Uri uri, PhotoCancellation cancellation) async {
  final client = http.Client();
  final aborted = Completer<void>();
  void abort() {
    if (!aborted.isCompleted) aborted.complete();
    client.close();
  }

  cancellation.listen(abort);
  try {
    cancellation.check();
    final response = await client.send(
      http.AbortableRequest('GET', uri, abortTrigger: aborted.future),
    );
    if (response.statusCode != 200) {
      throw PhotoHttpFailure(response.statusCode);
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.stream) {
      cancellation.check();
      bytes.add(chunk);
      if (bytes.length > photoDownloadLimit) {
        throw const FormatException('photo_too_large');
      }
    }
    cancellation.check();
    if (response.contentLength != null &&
        response.contentLength != bytes.length) {
      throw const FormatException('photo_truncated');
    }
    return bytes.takeBytes();
  } finally {
    cancellation.unlisten(abort);
    client.close();
  }
}
