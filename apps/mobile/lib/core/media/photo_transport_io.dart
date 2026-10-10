import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';

import 'photo_transport.dart';

Future<Uint8List> downloadPhoto(Uri uri, PhotoCancellation cancellation) async {
  cancellation.check();
  // Preserve Flutter's documented network-image test seam for pixel fixtures.
  final client = debugNetworkImageHttpClientProvider?.call() ?? HttpClient();
  void abort() => client.close(force: true);
  cancellation.listen(abort);
  try {
    final request = await client.getUrl(uri);
    cancellation.check();
    final response = await request.close();
    if (response.statusCode != 200) {
      throw PhotoHttpFailure(response.statusCode);
    }
    if (response.contentLength > photoDownloadLimit) {
      throw const FormatException('photo_too_large');
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response) {
      cancellation.check();
      bytes.add(chunk);
      if (bytes.length > photoDownloadLimit) {
        throw const FormatException('photo_too_large');
      }
    }
    cancellation.check();
    if (response.contentLength >= 0 && bytes.length != response.contentLength) {
      throw const FormatException('photo_truncated');
    }
    return bytes.takeBytes();
  } finally {
    cancellation.unlisten(abort);
    client.close(force: true);
  }
}
