import 'dart:async';
import 'dart:convert';

import 'package:dopmi_mobile/core/meta_lifecycle_measurement.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Deliberately model a failed device preference write, independently of RAM.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

const _app = '1156849688851390';
const _token = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _channel = MethodChannel('io.dopmi.app/meta_lifecycle_measurement');
const _fields = <String, Object?>{
  'platform': 'android',
  'package_name': 'com.mycompany.dopmi',
  'advertising_id': '81000000-0000-4000-8000-000000000001',
  'tracking_authorized': true,
  'app_version': '2.3.13',
  'app_build': 444,
  'os_version': '16',
  'install_eligible': true,
};

class _Native implements MetaLifecycleNative {
  @override
  bool get available => true;
  int reads = 0, cancellations = 0;
  Future<MetaLifecycleContext?> Function()? respond;

  @override
  Future<MetaLifecycleContext?> readContext() async {
    reads++;
    return respond == null ? MetaLifecycleContext.fromMap(_fields) : respond!();
  }

  @override
  void cancel() => cancellations++;
}

class _Transport implements MetaLifecycleTransport {
  final requests = <({Uri uri, Map<String, String> fields})>[];
  int cancellations = 0;
  bool disposed = false;
  Future<bool> Function()? respond;

  @override
  Future<bool> post(Uri uri, Map<String, String> fields) async {
    requests.add((uri: uri, fields: Map.of(fields)));
    return respond == null ? true : respond!();
  }

  @override
  void cancel() => cancellations++;

  @override
  void dispose() => disposed = true;
}

class _Storage extends InMemorySharedPreferencesStore {
  _Storage() : super.empty();
  bool failOff = false;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (failOff &&
        key.endsWith('.consent') &&
        value is String &&
        jsonDecode(value)['consent'] == false) {
      return false;
    }
    return super.setValue(valueType, key, value);
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences preferences;
  late _Native native;
  late _Transport transport;
  late DateTime now;
  late bool gate;
  late int gateReads;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    native = _Native();
    transport = _Transport();
    now = DateTime.utc(2026, 11, 24, 18);
    gate = true;
    gateReads = 0;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  MetaLifecycleController controller({
    String namespace = 'production.fixture',
    bool configured = true,
    String appId = _app,
    String clientToken = _token,
    Future<bool> Function()? readGate,
  }) {
    final result = MetaLifecycleController(
      preferences,
      namespace,
      configured: configured,
      appId: appId,
      clientToken: clientToken,
      readGate:
          readGate ??
          () async {
            gateReads++;
            return gate;
          },
      native: native,
      transport: transport,
      clock: () => now,
    );
    addTearDown(result.dispose);
    return result;
  }

  List<String> events() =>
      transport.requests.map((request) => request.fields['event']!).toList();

  test(
    'starts OFF and initialization/first foreground do not read IDs',
    () async {
      final value = controller();
      await value.initialize();
      expect(value.loading, isFalse);
      expect(value.available, isTrue);
      expect(value.consent, isFalse);
      expect(value.needsChoice, isTrue);

      await value.foreground();

      expect(native.reads, 0);
      expect(gateReads, 0);
      expect(transport.requests, isEmpty);
    },
  );

  test(
    'pending initialize cannot undo background or forget saved consent',
    () async {
      final original = controller();
      await original.initialize();
      await original.setConsent(true);
      original.dispose();
      final restarted = controller();
      final pending = restarted.foreground();
      restarted.background();
      await pending;
      expect(restarted.consent, isTrue);
      expect(restarted.needsChoice, isFalse);
      expect(native.reads, 0);
      expect(transport.requests, isEmpty);
      await restarted.foreground();
      expect(events(), ['CUSTOM_APP_EVENTS']);
    },
  );

  test(
    'background during saved consent write preserves choice without sending',
    () async {
      final value = controller();
      await value.initialize();
      final saved = value.setConsent(true);
      value.background();
      await saved;
      expect(value.consent, isTrue);
      expect(value.needsChoice, isFalse);
      expect(transport.requests, isEmpty);
      await value.foreground();
      expect(events(), ['CUSTOM_APP_EVENTS']);
    },
  );

  test(
    'saving an existing choice never reopens the first-choice gate',
    () async {
      final value = controller();
      await value.initialize();
      await value.setConsent(true);
      for (final next in [false, true]) {
        final saving = value.setConsent(next);
        expect(value.consent, isFalse);
        expect(value.needsChoice, isFalse);
        await saving;
      }
      expect(transport.requests, isEmpty);
    },
  );

  test(
    'failed OFF immediately revokes and successful OFF retry recovers storage',
    () async {
      final previous = SharedPreferencesStorePlatform.instance;
      final storage = _Storage();
      SharedPreferences.resetStatic();
      SharedPreferencesStorePlatform.instance = storage;
      addTearDown(() {
        SharedPreferencesStorePlatform.instance = previous;
        SharedPreferences.resetStatic();
      });
      preferences = await SharedPreferences.getInstance();
      final value = controller();
      await value.initialize();
      await value.setConsent(true);
      storage.failOff = true;
      final rejected = value.setConsent(false);
      expect(value.consent, isFalse);
      await expectLater(rejected, throwsStateError);
      await value.foreground();
      expect(transport.requests, isEmpty);
      storage.failOff = false;
      await value.setConsent(false);
      expect(value.available, isTrue);
      expect(value.consent, isFalse);
      expect(value.needsChoice, isFalse);
      await value.foreground();
      expect(transport.requests, isEmpty);
    },
  );

  test(
    'diagnostics hold only safe current ACK and revoke clears late delivery',
    () async {
      final value = controller();
      await value.initialize();
      await value.setConsent(true);
      await value.foreground();
      expect(value.lastDelivery, (event: 'CUSTOM_APP_EVENTS', accepted: true));
      now = now.add(const Duration(seconds: 61));
      transport.respond = () async => false;
      await value.foreground();
      expect(value.lastDelivery, (event: 'CUSTOM_APP_EVENTS', accepted: false));
      now = now.add(const Duration(seconds: 61));
      final entered = Completer<void>();
      final result = Completer<bool>();
      transport.respond = () {
        entered.complete();
        return result.future;
      };
      final pending = value.foreground();
      await entered.future;
      await value.setConsent(false);
      expect(value.lastDelivery, isNull);
      result.complete(true);
      await pending;
      expect(value.lastDelivery, isNull);
    },
  );

  test(
    'resumed during an invalidated native read rechecks once for Activate',
    () async {
      final entered = Completer<void>();
      final firstContext = Completer<MetaLifecycleContext?>();
      native.respond = () {
        if (native.reads == 1) {
          entered.complete();
          return firstContext.future;
        }
        return Future.value(
          MetaLifecycleContext.fromMap({..._fields, 'install_eligible': false}),
        );
      };
      final value = controller();
      await value.initialize();
      await value.setConsent(true);
      final first = value.foreground();
      await entered.future;
      // Native onPause canceled its read. Dart intentionally ignores inactive,
      // and resumed arrives while that old read is still completing.
      native.cancel();
      final resumed = value.foreground();
      firstContext.complete(null);
      await Future.wait([first, resumed]);
      expect(native.reads, 2);
      expect(events(), ['CUSTOM_APP_EVENTS']);
    },
  );

  test(
    'overlapping resume never retries an ambiguous activation attempt',
    () async {
      final nativeEntered = Completer<void>();
      final context = Completer<MetaLifecycleContext?>();
      final entered = Completer<void>();
      final reply = Completer<bool>();
      native.respond = () {
        nativeEntered.complete();
        return context.future;
      };
      transport.respond = () {
        entered.complete();
        return reply.future;
      };
      final value = controller();
      await value.initialize();
      await value.setConsent(true);
      final first = value.foreground();
      await nativeEntered.future;
      // Queue the resume before the activation marker exists, rather than
      // merely returning early through the 60-second debounce after POST.
      final resumed = value.foreground();
      await Future<void>.delayed(Duration.zero);
      context.complete(
        MetaLifecycleContext.fromMap({..._fields, 'install_eligible': false}),
      );
      await entered.future;
      reply.completeError(TimeoutException('ambiguous fixture'));
      await Future.wait([first, resumed]);
      expect(native.reads, 1);
      expect(events(), ['CUSTOM_APP_EVENTS']);
      expect(value.lastDelivery, (event: 'CUSTOM_APP_EVENTS', accepted: false));
    },
  );

  for (final setting in [
    (configured: false, app: _app, token: _token),
    (configured: true, app: '999', token: _token),
    (configured: true, app: _app, token: ''),
    (configured: true, app: _app, token: 'server-secret'),
  ]) {
    test('invalid configuration fails closed: $setting', () async {
      final value = controller(
        configured: setting.configured,
        appId: setting.app,
        clientToken: setting.token,
      );
      await value.initialize();
      expect(value.available, isFalse);
      await expectLater(value.setConsent(true), throwsStateError);
      await value.foreground();
      expect(native.reads, 0);
      expect(transport.requests, isEmpty);
    });
  }

  test(
    'saved consent then gate precede ID and every exact minimal POST',
    () async {
      final value = controller();
      await value.initialize();
      native.respond = () async {
        expect(value.consent, isTrue);
        expect(gateReads, 1);
        expect(
          preferences.getKeys().any((key) => key.contains('consent')),
          isTrue,
        );
        return MetaLifecycleContext.fromMap({
          ..._fields,
          'private_extra': 'omit',
        });
      };
      await value.setConsent(true);
      expect(native.reads, 0, reason: 'saving is not a measurement request');

      await value.foreground();

      expect(events(), ['MOBILE_APP_INSTALL', 'CUSTOM_APP_EVENTS']);
      expect(gateReads, 3);
      for (final request in transport.requests) {
        expect(
          request.uri.toString(),
          'https://graph.facebook.com/v27.0/$_app/activities',
        );
        expect(request.uri.query, isEmpty);
        expect(request.fields['access_token'], '$_app|$_token');
        expect(request.fields['application_tracking_enabled'], '1');
        expect(request.fields['advertiser_tracking_enabled'], '1');
        expect(request.fields['advertiser_id'], _fields['advertising_id']);
        expect(jsonDecode(request.fields['extinfo']!), [
          'a2',
          'com.mycompany.dopmi',
          '444',
          '2.3.13',
          '16',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
        ]);
        expect(
          request.fields.keys,
          unorderedEquals([
            'event',
            'access_token',
            'application_tracking_enabled',
            'advertiser_tracking_enabled',
            'advertiser_id',
            'extinfo',
            if (request.fields['event'] == 'CUSTOM_APP_EVENTS') 'custom_events',
          ]),
        );
      }
      expect(jsonDecode(transport.requests.last.fields['custom_events']!), [
        {
          '_eventName': 'fb_mobile_activate_app',
          '_logTime': now.millisecondsSinceEpoch ~/ 1000,
        },
      ]);
      final stored = preferences.getKeys().map(preferences.get).join('|');
      expect(stored, isNot(contains(_fields['advertising_id'])));
      expect(stored, isNot(contains(_token)));
      expect(stored, isNot(contains('fb_mobile_activate_app')));
    },
  );

  for (final failure in ['OFF', 'error']) {
    test('gate $failure suppresses identifier access and POST', () async {
      final value = controller(
        readGate: () async {
          if (failure == 'error') throw StateError('unavailable gate');
          return false;
        },
      );
      await value.initialize();
      await value.setConsent(true);
      await value.foreground();
      expect(native.reads, 0);
      expect(transport.requests, isEmpty);
    });
  }

  test('closing gate during native lookup suppresses all POSTs', () async {
    final entered = Completer<void>();
    final release = Completer<MetaLifecycleContext?>();
    native.respond = () {
      entered.complete();
      return release.future;
    };
    final value = controller();
    await value.initialize();
    await value.setConsent(true);
    final pending = value.foreground();
    await entered.future;
    gate = false;
    release.complete(MetaLifecycleContext.fromMap(_fields));
    await pending;
    expect(transport.requests, isEmpty);
  });

  test('update/inconclusive proof emits Activate only', () async {
    native.respond = () async =>
        MetaLifecycleContext.fromMap({..._fields, 'install_eligible': false});
    final value = controller();
    await value.initialize();
    await value.setConsent(true);
    await value.foreground();
    expect(events(), ['CUSTOM_APP_EVENTS']);
  });

  test(
    'restart cannot recreate Install or bypass the activation debounce',
    () async {
      final first = controller();
      await first.initialize();
      await first.setConsent(true);
      await first.foreground();
      first.dispose();
      transport.requests.clear();
      final restarted = controller();
      await restarted.initialize();
      await restarted.foreground();
      expect(transport.requests, isEmpty);
      now = now.add(const Duration(seconds: 61));
      await restarted.foreground();
      expect(events(), ['CUSTOM_APP_EVENTS']);
    },
  );

  for (final close in ['deny', 'background']) {
    test(
      'first-session $close consumes Install eligibility permanently',
      () async {
        final value = controller();
        await value.initialize();
        if (close == 'deny') {
          await value.setConsent(false);
        } else {
          value.background();
        }
        await value.setConsent(true);
        await value.foreground();
        expect(events(), ['CUSTOM_APP_EVENTS']);
      },
    );
  }

  test(
    'revocation while ID is pending cancels and prevents delayed delivery',
    () async {
      final entered = Completer<void>();
      final release = Completer<MetaLifecycleContext?>();
      native.respond = () {
        entered.complete();
        return release.future;
      };
      final value = controller();
      await value.initialize();
      await value.setConsent(true);
      final pending = value.foreground();
      await entered.future;
      await value.setConsent(false);
      expect(value.consent, isFalse);
      expect(native.cancellations, greaterThan(0));
      expect(transport.cancellations, greaterThan(0));
      release.complete(MetaLifecycleContext.fromMap(_fields));
      await pending;
      expect(transport.requests, isEmpty);
    },
  );

  test('revocation in Install POST suppresses Activate and re-enable never replays Install', () async {
    final entered = Completer<void>();
    final release = Completer<bool>();
    transport.respond = () {
      entered.complete();
      return release.future;
    };
    final value = controller();
    await value.initialize();
    await value.setConsent(true);
    final pending = value.foreground();
    await entered.future;
    await value.setConsent(false);
    release.complete(true);
    await pending;
    expect(events(), ['MOBILE_APP_INSTALL']);
    transport.respond = null;
    await value.setConsent(true);
    await value.foreground();
    expect(events(), ['MOBILE_APP_INSTALL', 'CUSTOM_APP_EVENTS']);
  });

  test(
    'ambiguous Install failure is not retried automatically or on restart',
    () async {
      transport.respond = () async => throw TimeoutException('fixture');
      final value = controller();
      await value.initialize();
      await value.setConsent(true);
      await value.foreground();
      expect(events(), ['MOBILE_APP_INSTALL', 'CUSTOM_APP_EVENTS']);
      value.dispose();
      now = now.add(const Duration(seconds: 61));
      transport.respond = null;
      final restarted = controller();
      await restarted.initialize();
      await restarted.foreground();
      expect(
        events().where((event) => event == 'MOBILE_APP_INSTALL'),
        hasLength(1),
      );
    },
  );

  test('foreground calls overlap safely and resumed within 60 seconds does not inflate events', () async {
    final value = controller();
    await value.initialize();
    await value.setConsent(true);
    await Future.wait([value.foreground(), value.foreground()]);
    value.background();
    now = now.add(const Duration(seconds: 59));
    await value.foreground();
    expect(events(), ['MOBILE_APP_INSTALL', 'CUSTOM_APP_EVENTS']);
    now = now.add(const Duration(seconds: 2));
    await value.foreground();
    expect(events(), [
      'MOBILE_APP_INSTALL',
      'CUSTOM_APP_EVENTS',
      'CUSTOM_APP_EVENTS',
    ]);
  });

  test('DEV choice never grants PROD or another notice version', () async {
    final dev = controller(namespace: 'test.fixture');
    await dev.initialize();
    await dev.setConsent(true);
    final prod = controller();
    await prod.initialize();
    expect(prod.consent, isFalse);
    expect(prod.needsChoice, isTrue);
    expect(metaLifecycleNoticeVersion, 'meta-lifecycle-2026-11-24');
    expect(transport.requests, isEmpty);
  });

  for (final invalid in [
    {'advertising_id': '00000000-0000-0000-0000-000000000000'},
    {'tracking_authorized': false},
    {'platform': 'web'},
    {'package_name': 'com.other.app'},
    {'app_build': 0},
    {'app_version': 'private payload'},
    {'os_version': ''},
    {'install_eligible': 'true'},
  ]) {
    test('native context rejects invalid fields $invalid', () async {
      expect(MetaLifecycleContext.fromMap({..._fields, ...invalid}), isNull);
    });
  }

  test('iOS context uses i2 and still requires affirmative ATT result', () {
    final value = MetaLifecycleContext.fromMap({..._fields, 'platform': 'ios'});
    expect(value?.extinfo.first, 'i2');
    expect(
      MetaLifecycleContext.fromMap({
        ..._fields,
        'platform': 'ios',
        'tracking_authorized': false,
      }),
      isNull,
    );
  });

  test(
    'native bridge uses only the new method and cancels independently',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final calls = <String>[];
      binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (
        call,
      ) async {
        calls.add(call.method);
        return call.method == 'readContext' ? _fields : null;
      });
      final bridge = MethodChannelMetaLifecycleNative();
      expect(await bridge.readContext(), isNotNull);
      bridge.cancel();
      await Future<void>.delayed(Duration.zero);
      expect(calls, ['readContext', 'cancel']);
    },
  );

  for (final reply in [
    (status: 200, body: '{"success":true}', accepted: true),
    (
      status: 200,
      body: '{"success":true,"drop_reason":"fixture"}',
      accepted: false,
    ),
    (status: 200, body: '{"success":true,"error":{}}', accepted: false),
    (status: 200, body: '{"success":false}', accepted: false),
    (status: 200, body: 'invalid', accepted: false),
    (status: 302, body: '{"success":true}', accepted: false),
    (status: 503, body: '{"success":true}', accepted: false),
  ]) {
    test(
      'HTTP transport requires strict ACK and never follows redirects $reply',
      () async {
        var calls = 0;
        final sender = MetaLifecycleHttpTransport(
          createClient: () => MockClient.streaming((request, body) async {
            calls++;
            expect(request.method, 'POST');
            expect(request.followRedirects, isFalse);
            expect(request.url.query, isEmpty);
            expect(await body.bytesToString(), contains('access_token='));
            return http.StreamedResponse(
              Stream.value(utf8.encode(reply.body)),
              reply.status,
            );
          }),
        );
        addTearDown(sender.dispose);
        final accepted = await sender.post(
          Uri.parse('https://graph.facebook.com/v27.0/$_app/activities'),
          {'access_token': '$_app|$_token', 'event': 'MOBILE_APP_INSTALL'},
        );
        expect(accepted, reply.accepted);
        expect(calls, 1);
      },
    );
  }
}
