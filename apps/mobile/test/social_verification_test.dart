import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/profile/social_verification_repository.dart';
import 'package:dopmi_mobile/features/profile/social_verification_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_identity_repository.dart';

class SocialFixture implements SocialVerificationRepository {
  @override
  String? owner = 'one';
  final calls = <Map<String, dynamic>>[];
  Completer<Map<String, dynamic>>? startGate;
  String host = 'www.facebook.com';
  @override
  Future<Map<String, dynamic>> call(Map<String, dynamic> input) async {
    calls.add(input);
    return switch (input['operation']) {
      'list' => {
        'accounts': [],
        'available_providers': ['facebook', 'instagram'],
      },
      'start' =>
        await (startGate?.future ??
            Future.value({
              'attempt_id': '00000000-0000-4000-8000-000000000001',
              'authorization_url':
                  'https://$host/v25.0/dialog/oauth?state=fixture&response_type=code',
            })),
      'status' => {'provider': 'facebook', 'status': 'pending'},
      'cancel' => {'status': 'denied'},
      _ => throw StateError('unsupported'),
    };
  }
}

void main() {
  test('authorization URL rejects alternate hosts, protocols and provider', () {
    for (final value in [
      'https://www.facebook.com.evil.test/v25.0/dialog/oauth?state=x&response_type=code',
      'https://www.facebook.com@evil.test/v25.0/dialog/oauth?state=x&response_type=code',
      'http://www.facebook.com/v25.0/dialog/oauth?state=x&response_type=code',
      'https://www.facebook.com:444/v25.0/dialog/oauth?state=x&response_type=code',
      'https://www.facebook.com/v25.0/dialog/oauth?response_type=code',
      'https://www.instagram.com/oauth/authorize?state=x&response_type=code',
    ]) {
      expect(
        () => socialAuthorizationUri('facebook', value),
        throwsFormatException,
      );
    }
    expect(
      socialAuthorizationUri(
        'instagram',
        'https://www.instagram.com/oauth/authorize?state=x&response_type=code',
      ).host,
      'www.instagram.com',
    );
  });

  Future<void> mount(
    WidgetTester tester,
    SocialFixture repo,
    Future<bool> Function(Uri) opener,
  ) async {
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'fixture@example.test', verified: true);
    addTearDown(() => identity.changes.close());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          socialVerificationRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          theme: dopmiTheme(rescuer: true),
          home: SocialVerificationScreen(openAuthorization: opener),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('no polling; explicit check and cancellation reach server once', (
    tester,
  ) async {
    final repo = SocialFixture();
    var opened = 0;
    await mount(tester, repo, (_) async {
      opened++;
      return true;
    });
    await tester.tap(find.text('Conectar Facebook'));
    await tester.pumpAndSettle();
    expect(opened, 1);
    await tester.pump(const Duration(minutes: 2));
    expect(repo.calls.where((c) => c['operation'] == 'status'), isEmpty);
    await tester.ensureVisible(find.text('Ya autoricé, comprobar'));
    await tester.tap(find.text('Ya autoricé, comprobar'));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c['operation'] == 'status'), hasLength(1));
    await tester.ensureVisible(find.text('Cancelar este intento'));
    await tester.tap(find.text('Cancelar este intento'));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c['operation'] == 'cancel'), hasLength(1));
    expect(find.text('Ya autoricé, comprobar'), findsNothing);
  });

  testWidgets('actor change during start prevents opening browser', (
    tester,
  ) async {
    final repo = SocialFixture()..startGate = Completer();
    var opened = 0;
    await mount(tester, repo, (_) async {
      opened++;
      return true;
    });
    await tester.tap(find.text('Conectar Facebook'));
    await tester.pump();
    repo.owner = 'two';
    repo.startGate!.complete({
      'attempt_id': '00000000-0000-4000-8000-000000000001',
      'authorization_url': 'https://www.facebook.com/v25.0/dialog/oauth?state=x&response_type=code',
    });
    await tester.pumpAndSettle();
    expect(opened, 0);
    expect(
      find.text('La sesión cambió. Vuelve a abrir esta pantalla.'),
      findsOneWidget,
    );
  });

  testWidgets('malicious URL never opens and raw error is hidden', (
    tester,
  ) async {
    final repo = SocialFixture()..host = 'evil.test';
    var opened = 0;
    await mount(tester, repo, (_) async {
      opened++;
      return true;
    });
    await tester.tap(find.text('Conectar Facebook'));
    await tester.pumpAndSettle();
    expect(opened, 0);
    expect(find.textContaining('evil.test'), findsNothing);
    expect(repo.calls.where((c) => c['operation'] == 'cancel'), hasLength(1));
    expect(
      find.text('No pudimos abrir la verificación. Vuelve a intentar.'),
      findsOneWidget,
    );
  });

  testWidgets('social controls remain reachable at 320px and 200 percent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      final font = FontLoader('Inter')
        ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
      await font.load();
    });
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'fixture@example.test', verified: true);
    addTearDown(() => identity.changes.close());
    final key = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          socialVerificationRepositoryProvider.overrideWithValue(
            SocialFixture(),
          ),
        ],
        child: MaterialApp(
          theme: dopmiTheme(rescuer: true),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(2)),
            child: RepaintBoundary(key: key, child: child!),
          ),
          home: const SocialVerificationScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final folder = Platform.environment['DOPMI_SOCIAL_CAPTURE_DIR'];
    if (folder != null) {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$folder/social-320-200.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.scrollUntilVisible(
      find.text('Conectar Instagram profesional'),
      300,
    );
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Actualizar estado'), 300);
    expect(tester.takeException(), isNull);
  });
}
