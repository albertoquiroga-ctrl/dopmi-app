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
  String status = 'pending';
  bool consumeOnStart = false;
  bool failReload = false;
  bool loseStartResponse = false;
  Completer<Map<String, dynamic>>? reloadGate;
  List<String> available = ['facebook', 'instagram'];
  @override
  Future<Map<String, dynamic>> call(Map<String, dynamic> input) async {
    calls.add(input);
    return switch (input['operation']) {
      'list' => await _listResponse(),
      'start' => await _startResponse(),
      'status' => {'provider': 'facebook', 'status': status},
      'cancel' => {'status': 'denied'},
      _ => throw StateError('unsupported'),
    };
  }

  Future<Map<String, dynamic>> _listResponse() async {
    if (failReload && calls.where((c) => c['operation'] == 'list').length > 1) {
      throw StateError('fixture_offline');
    }
    if (reloadGate != null &&
        calls.where((c) => c['operation'] == 'list').length > 1) {
      return reloadGate!.future;
    }
    return {'accounts': [], 'available_providers': available};
  }

  Future<Map<String, dynamic>> _startResponse() async {
    final data =
        await (startGate?.future ??
            Future.value({
              'attempt_id': '00000000-0000-4000-8000-000000000001',
              'authorization_url':
                  'https://$host/v25.0/dialog/oauth?state=fixture&response_type=code',
            }));
    if (consumeOnStart) available = [];
    if (loseStartResponse) throw StateError('fixture_response_lost');
    return data;
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
    Future<bool> Function(Uri) opener, {
    double textScale = 1,
    GlobalKey? captureKey,
  }) async {
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: captureKey == null
                ? child!
                : RepaintBoundary(key: captureKey, child: child!),
          ),
          home: SocialVerificationScreen(openAuthorization: opener),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('denial cannot offer a consumed connection again', (
    tester,
  ) async {
    final repo = SocialFixture()
      ..consumeOnStart = true
      ..status = 'denied';
    await mount(tester, repo, (_) async => true);
    await tester.tap(find.text('Conectar Facebook'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(
      find.text('No autorizaste la conexión. Tu cuenta Dopmi se conserva.'),
      findsOneWidget,
    );
    final connect = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Conectar Facebook'),
    );
    expect(connect.onPressed, isNull);
    expect(repo.calls.where((c) => c['operation'] == 'start'), hasLength(1));
  });

  testWidgets('terminal refresh failure never revives consumed availability', (
    tester,
  ) async {
    final repo = SocialFixture()
      ..consumeOnStart = true
      ..status = 'denied'
      ..failReload = true;
    await mount(tester, repo, (_) async => true);
    await tester.tap(find.text('Conectar Facebook'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Conectar Facebook'),
          )
          .onPressed,
      isNull,
    );
    expect(find.textContaining('No autorizaste la conexión.'), findsOneWidget);
    expect(repo.calls.where((c) => c['operation'] == 'start'), hasLength(1));
  });

  testWidgets(
    'lost start response reconciles availability without another start',
    (tester) async {
      final repo = SocialFixture()
        ..consumeOnStart = true
        ..loseStartResponse = true;
      await mount(tester, repo, (_) async => true);
      await tester.tap(find.text('Conectar Facebook'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Conectar Facebook'),
            )
            .onPressed,
        isNull,
      );
      expect(repo.calls.where((c) => c['operation'] == 'start'), hasLength(1));
      expect(repo.calls.where((c) => c['operation'] == 'cancel'), isEmpty);
      expect(repo.calls.where((c) => c['operation'] == 'status'), isEmpty);
      expect(find.textContaining('Vuelve a intentar'), findsNothing);
    },
  );

  testWidgets('cancelled consumed attempt refreshes without starting again', (
    tester,
  ) async {
    final repo = SocialFixture()..consumeOnStart = true;
    await mount(tester, repo, (_) async => true);
    await tester.tap(find.text('Conectar Facebook'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cancelar este intento'));
    await tester.tap(find.text('Cancelar este intento'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Conectar Facebook'),
          )
          .onPressed,
      isNull,
    );
    expect(repo.calls.where((c) => c['operation'] == 'start'), hasLength(1));
    expect(repo.calls.where((c) => c['operation'] == 'cancel'), hasLength(1));
    expect(repo.calls.where((c) => c['operation'] == 'status'), isEmpty);
  });

  testWidgets(
    'checking a rejected request never instructs authorization or a new start',
    (tester) async {
      final repo = SocialFixture()
        ..consumeOnStart = true
        ..status = 'failed';
      await mount(tester, repo, (_) async => true);
      await tester.tap(find.text('Conectar Facebook'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Autoriza en la red social'), findsNothing);
      expect(find.text('Comprobar estado'), findsOneWidget);
      await tester.ensureVisible(find.text('Comprobar estado'));
      await tester.tap(find.text('Comprobar estado'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Puedes volver a intentar'), findsNothing);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Conectar Facebook'),
            )
            .onPressed,
        isNull,
      );
      expect(repo.calls.where((c) => c['operation'] == 'start'), hasLength(1));
    },
  );

  testWidgets(
    'expired request closes consumed availability without promising another start',
    (tester) async {
      final repo = SocialFixture()
        ..consumeOnStart = true
        ..status = 'expired';
      await mount(tester, repo, (_) async => true);
      await tester.tap(find.text('Conectar Facebook'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Comprobar estado'));
      await tester.tap(find.text('Comprobar estado'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'La solicitud venció. Consulta la disponibilidad para continuar.',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Conectar Facebook'),
            )
            .onPressed,
        isNull,
      );
      expect(repo.calls.where((c) => c['operation'] == 'start'), hasLength(1));
    },
  );

  testWidgets(
    'normal server availability remains usable after a terminal result',
    (tester) async {
      final repo = SocialFixture()..status = 'denied';
      await mount(tester, repo, (_) async => true);
      await tester.tap(find.text('Conectar Facebook'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Comprobar estado'));
      await tester.tap(find.text('Comprobar estado'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Conectar Facebook'),
            )
            .onPressed,
        isNotNull,
      );
      expect(repo.calls.where((c) => c['operation'] == 'start'), hasLength(1));
    },
  );

  testWidgets(
    'terminal refresh keeps controls closed until the server answers',
    (tester) async {
      final repo = SocialFixture()
        ..consumeOnStart = true
        ..status = 'denied'
        ..reloadGate = Completer();
      await mount(tester, repo, (_) async => true);
      await tester.tap(find.text('Conectar Facebook'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Comprobar estado'));
      await tester.tap(find.text('Comprobar estado'));
      await tester.pump();
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Conectar Facebook'),
            )
            .onPressed,
        isNull,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      repo.reloadGate!.complete({'accounts': [], 'available_providers': []});
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Conectar Facebook'),
            )
            .onPressed,
        isNull,
      );
      expect(repo.calls.where((c) => c['operation'] == 'start'), hasLength(1));
    },
  );

  testWidgets(
    'denied result and final read control remain reachable at 320px 200 percent',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        await (FontLoader(
          'Inter',
        )..addFont(rootBundle.load('assets/fonts/Inter.ttf'))).load();
      });
      final key = GlobalKey();
      final repo = SocialFixture()
        ..consumeOnStart = true
        ..status = 'denied';
      await mount(
        tester,
        repo,
        (_) async => true,
        textScale: 2,
        captureKey: key,
      );
      await tester.scrollUntilVisible(find.text('Conectar Facebook'), 250);
      await tester.tap(find.text('Conectar Facebook'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Comprobar estado'), 250);
      await tester.tap(find.text('Comprobar estado'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Actualizar estado'), 250);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.text('No autorizaste la conexión. Tu cuenta Dopmi se conserva.'),
        findsOneWidget,
      );
      final folder = Platform.environment['DOPMI_SOCIAL_CAPTURE_DIR'];
      if (folder != null) {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('$folder/social-denied-320-200.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      expect(repo.calls.where((c) => c['operation'] == 'start'), hasLength(1));
    },
  );

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
    await tester.ensureVisible(find.text('Comprobar estado'));
    await tester.tap(find.text('Comprobar estado'));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c['operation'] == 'status'), hasLength(1));
    await tester.ensureVisible(find.text('Cancelar este intento'));
    await tester.tap(find.text('Cancelar este intento'));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c['operation'] == 'cancel'), hasLength(1));
    expect(find.text('Comprobar estado'), findsNothing);
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
      find.text(
        'No pudimos completar la verificación. Actualiza el estado antes de iniciar otra conexión.',
      ),
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
