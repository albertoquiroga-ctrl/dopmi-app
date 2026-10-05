import 'dart:async';
import 'dart:io';

import 'package:dopmi_mobile/core/media/photo_transport.dart';
import 'package:dopmi_mobile/core/media/photo_transport_io.dart' as transport;
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

class _Client implements HttpClient {
  _Client(this.response);
  final _Response response;
  bool closed = false;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _Request(response);
  @override
  void close({bool force = false}) {
    closed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Request implements HttpClientRequest {
  _Request(this.response);
  final _Response response;
  @override
  Future<HttpClientResponse> close() async => response;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.contentLength, this.chunks);
  @override
  final int contentLength;
  final List<List<int>> chunks;
  @override
  int get statusCode => 200;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.fromIterable(chunks).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final response in [
    _Response(10, [
      [1, 2, 3],
    ]),
    _Response(photoDownloadLimit + 1, const []),
  ]) {
    test(
      'truncated or oversized response is rejected and transport closed: ${response.contentLength}',
      () async {
        final previous = debugNetworkImageHttpClientProvider;
        final client = _Client(response);
        debugNetworkImageHttpClientProvider = () => client;
        addTearDown(() => debugNetworkImageHttpClientProvider = previous);
        await expectLater(
          transport.downloadPhoto(
            Uri.parse('https://example.test/photo'),
            PhotoCancellation(),
          ),
          throwsFormatException,
        );
        expect(client.closed, isTrue);
      },
    );
  }
}
