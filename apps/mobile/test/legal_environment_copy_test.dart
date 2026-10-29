import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/core/config.dart';
import 'package:dopmi_mobile/features/identity/auth_screens.dart';
import 'package:dopmi_mobile/features/identity/auth_ui.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/identity/legal_document_frame.dart';
import 'package:dopmi_mobile/features/identity/privacy_notice_screen.dart';
import 'package:dopmi_mobile/features/profile/information_screens.dart';
import 'package:dopmi_mobile/features/profile/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_identity_repository.dart';

void main() {
  Future<Map<String, String>> document(
    WidgetTester tester,
    Widget screen,
  ) async {
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    return {
      for (final section in tester.widgetList<LegalDocumentSection>(
        find.byType(LegalDocumentSection),
      ))
        section.title: section.body,
    };
  }

  testWidgets(
    'production terms change only the approved authorization paragraph and document version',
    (tester) async {
      final testTerms = await document(tester, const TermsScreen());
      expect(
        find.textContaining('terms-2026-10-17 · 17 de octubre de 2026'),
        findsWidgets,
      );
      final liveTerms = await document(
        tester,
        const TermsScreen(environment: 'production'),
      );
      expect(
        find.textContaining('terms-live-2026-10-28 · 28 de octubre de 2026'),
        findsWidgets,
      );
      expect(liveTerms.keys, testTerms.keys);
      for (final title in testTerms.keys.where(
        (title) => title != 'Autorizaciones separadas',
      )) {
        expect(liveTerms[title], testTerms[title]);
      }
      expect(
        testTerms['Autorizaciones separadas'],
        contains('exclusivamente Stripe TEST'),
      );
      final authorization = liveTerms['Autorizaciones separadas']!;
      expect(
        authorization,
        contains('no registra Guardián, no guarda una tarjeta y no cobra'),
      );
      expect(authorization, contains('Stripe LIVE y dinero real'));
      expect(
        authorization,
        contains('requieren la confirmación correspondiente'),
      );
      expect(authorization, isNot(contains('Stripe TEST')));
    },
  );

  testWidgets(
    'production privacy adds Stream processing and preserves all other purposes and retention text',
    (tester) async {
      final testPrivacy = await document(tester, const PrivacyNoticeScreen());
      expect(
        find.textContaining('privacy-2026-10-17 · 17 de octubre de 2026'),
        findsWidgets,
      );
      final livePrivacy = await document(
        tester,
        const PrivacyNoticeScreen(environment: 'production'),
      );
      expect(
        find.textContaining('privacy-live-2026-10-28 · 28 de octubre de 2026'),
        findsWidgets,
      );
      expect(livePrivacy.keys, testPrivacy.keys);
      for (final title in testPrivacy.keys.where(
        (title) => title != 'Proveedores y conexiones sociales',
      )) {
        expect(livePrivacy[title], testPrivacy[title]);
      }
      final providers = livePrivacy['Proveedores y conexiones sociales']!;
      expect(
        providers,
        startsWith(testPrivacy['Proveedores y conexiones sociales']!),
      );
      expect(providers, contains('Cloudflare Stream'));
      expect(
        providers,
        contains(
          'carga, el procesamiento y la reproducción de videos y sus pósters',
        ),
      );
      expect(
        providers,
        contains('moderación y aprobación antes de publicarse'),
      );
      expect(
        providers,
        contains(
          'comprobantes y las evidencias privados conservan el acceso autorizado',
        ),
      );
      expect(testPrivacy.values.join(), isNot(contains('Cloudflare Stream')));
    },
  );

  testWidgets('unknown documents expose no legal version or substitute text', (
    tester,
  ) async {
    for (final screen in [
      const TermsScreen(environment: 'unknown'),
      const PrivacyNoticeScreen(environment: 'unknown'),
    ]) {
      expect(await document(tester, screen), isEmpty);
      expect(find.text('Documento no disponible'), findsOneWidget);
    }
  });

  for (final environment in ['test', 'production']) {
    testWidgets('$environment transparency describes its payment mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: TransparencyScreen(environment: environment)),
      );
      final notice = find.textContaining(
        environment == 'production'
            ? 'Las aportaciones de esta beta usan dinero real.'
            : 'Los pagos de esta versión funcionan en modo prueba.',
      );
      await tester.scrollUntilVisible(notice, 400);
      expect(notice, findsOneWidget);
      if (environment == 'production') {
        final copy = tester.widget<Text>(notice).data!;
        expect(copy, contains('2 % del importe bruto'));
        expect(copy, contains('costos reales de Stripe'));
        expect(copy, isNot(contains('No utilizan dinero real')));
      }
      expect(tester.takeException(), isNull);
    });
  }

  final scenarios = [
    (environment: 'test', acceptedEnvironment: 'test', allowed: true),
    (environment: 'test', acceptedEnvironment: 'production', allowed: false),
    (
      environment: 'production',
      acceptedEnvironment: 'production',
      allowed: true,
    ),
    (environment: 'production', acceptedEnvironment: 'test', allowed: false),
    (environment: 'unknown', acceptedEnvironment: 'test', allowed: false),
  ];
  for (final scenario in scenarios) {
    testWidgets(
      'router ${scenario.environment} with ${scenario.acceptedEnvironment} prior acceptance sends its mode to documents',
      (tester) async {
        final accepted = legalVersionsForEnvironment(
          scenario.acceptedEnvironment,
        )!;
        final identity = FakeIdentityRepository()
          ..user = const Identity('one', 'fixture@example.test', verified: true)
          ..profile = Profile(
            id: 'one',
            name: 'Ana',
            phone: '',
            city: '',
            mode: 'donor',
            intent: 'adopt',
            status: 'active',
            termsVersion: accepted.terms,
            privacyVersion: accepted.privacy,
            adultConfirmed: true,
          );
        final container = ProviderContainer(
          overrides: [
            identityRepositoryProvider.overrideWithValue(identity),
            configProvider.overrideWithValue(
              AppConfig(
                url: 'http://127.0.0.1:54321',
                key: 'synthetic-key',
                redirect: 'io.dopmi.app://auth/callback',
                environment: scenario.environment,
              ),
            ),
            routerInitialLocationProvider.overrideWithValue('/about'),
          ],
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
          await identity.changes.close();
        });
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const DopmiApp(),
          ),
        );
        await tester.pumpAndSettle();
        final router = container.read(routerProvider);
        expect(router.state.uri.path, scenario.allowed ? '/about' : '/consent');
        if (!scenario.allowed) {
          expect(find.byType(ConsentScreen), findsOneWidget);
          expect(
            tester.widget<AuthConsentRow>(find.byType(AuthConsentRow)).value,
            false,
          );
          if (scenario.environment == 'unknown') {
            expect(
              tester
                  .widget<AuthConsentRow>(find.byType(AuthConsentRow))
                  .onChanged,
              isNull,
            );
          } else {
            expect(
              find.textContaining(
                'Actualización del ${legalVersionsForEnvironment(scenario.environment)!.date}',
              ),
              findsOneWidget,
            );
          }
        }
        expect(identity.consentCount, 0);
        router.go('/terms');
        await tester.pumpAndSettle();
        expect(
          tester.widget<TermsScreen>(find.byType(TermsScreen)).environment,
          scenario.environment,
        );
        router.go('/privacy-notice');
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<PrivacyNoticeScreen>(find.byType(PrivacyNoticeScreen))
              .environment,
          scenario.environment,
        );
        expect(identity.consentCount, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
