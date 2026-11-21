import 'dart:async';

import 'package:dopmi_mobile/core/ios_cpp_acquisition.dart';
import 'package:dopmi_mobile/core/ios_cpp_link_capture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final campaign = Uri.parse('io.dopmi.app://acquire/personal-a');
  final oauth = Uri.parse('io.dopmi.app://login-callback?code=private');

  Future<IosCppAcquisition> service() async {
    SharedPreferences.setMockInitialValues({});
    return IosCppAcquisition(
      await SharedPreferences.getInstance(),
      'test',
      supported: true,
    );
  }

  Future<List<String>> claim(IosCppAcquisition acquisition) async {
    await acquisition.observeOwner('alice');
    final sent = <String>[];
    await acquisition.record(
      owner: 'alice',
      sessionStillEligible: () => true,
      send: (variant) async {
        sent.add(variant);
        return IosCppClaimResult.recorded;
      },
    );
    return sent;
  }

  test('an early stream campaign survives slow startup and a later OAuth initial link', () async {
    final links = StreamController<Uri>.broadcast(sync: true);
    final initial = Completer<Uri?>();
    final startup = Completer<IosCppAcquisition?>();
    final capture = IosCppLinkCapture(
      events: links.stream,
      readInitial: () => initial.future,
      acquisition: startup.future,
    )..start();
    links.add(campaign);
    initial.complete(oauth);
    final acquisition = await service();
    startup.complete(acquisition);
    await capture.ready;
    expect(await claim(acquisition), ['personal-a']);
    await capture.dispose();
    await links.close();
  });

  test(
    'initial and stream candidates are captured while OAuth stays unrelated',
    () async {
      final links = StreamController<Uri>.broadcast(sync: true);
      final acquisition = await service();
      var captured = 0;
      final capture = IosCppLinkCapture(
        events: links.stream,
        readInitial: () async => campaign,
        acquisition: Future.value(acquisition),
        onCaptured: () => captured++,
      )..start();
      links.add(oauth);
      links.add(campaign);
      await capture.ready;
      expect(await claim(acquisition), ['personal-a']);
      expect(captured, 2);
      await capture.dispose();
      await links.close();
    },
  );

  test(
    'disposal before startup resolves prevents queued capture or callbacks',
    () async {
      final links = StreamController<Uri>.broadcast(sync: true);
      final startup = Completer<IosCppAcquisition?>();
      final acquisition = await service();
      var captured = 0;
      final capture = IosCppLinkCapture(
        events: links.stream,
        readInitial: () async => campaign,
        acquisition: startup.future,
        onCaptured: () => captured++,
      )..start();
      links.add(campaign);
      await capture.dispose();
      startup.complete(acquisition);
      await capture.ready;
      expect(await claim(acquisition), isEmpty);
      expect(captured, 0);
      await links.close();
    },
  );

  test(
    'read and stream failures leave normal startup available without a source',
    () async {
      final links = StreamController<Uri>.broadcast(sync: true);
      final acquisition = await service();
      final capture = IosCppLinkCapture(
        events: links.stream,
        readInitial: () async => throw StateError('platform unavailable'),
        acquisition: Future.value(acquisition),
      )..start();
      links.addError(StateError('stream unavailable'));
      await expectLater(capture.ready, completes);
      expect(await claim(acquisition), isEmpty);
      await capture.dispose();
      await links.close();
    },
  );
}
