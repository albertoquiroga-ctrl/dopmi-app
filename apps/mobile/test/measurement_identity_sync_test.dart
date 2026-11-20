import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/core/config.dart';
import 'package:dopmi_mobile/core/measurement.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/profile/account_photo_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_account_photo_repository.dart';
import 'fake_identity_repository.dart';
import 'measurement_test.dart' show AnalyticsSpy, DiagnosticsSpy;

class SocialIdentityRepository extends FakeIdentityRepository {
  @override
  Set<String> get linkedProviders => const {'google'};

  @override
  Future<void> oauth(String provider) async {
    if (provider != 'google') throw ArgumentError.value(provider);
    emit(
      const IdentityEvent(Identity('one', 'one@example.test', verified: true)),
    );
  }
}

void main() {
  Future<
    ({
      ProviderContainer container,
      MeasurementController measurement,
      List<(String, bool)> consent,
    })
  >
  mount(WidgetTester tester, FakeIdentityRepository repository) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final consent = <(String, bool)>[];
    final measurement = MeasurementController(
      await SharedPreferences.getInstance(),
      'test',
      AnalyticsSpy(),
      DiagnosticsSpy(),
      prepareAdoptionConsent: (owner, enabled) =>
          () async => consent.add((owner, enabled)),
    );
    // Bootstrap configures the signed-out controller before mounting DopmiApp.
    await measurement.owner(null);
    final container = ProviderContainer(
      overrides: [
        configProvider.overrideWithValue(
          const AppConfig(url: '', key: '', redirect: '', googleEnabled: true),
        ),
        identityRepositoryProvider.overrideWithValue(repository),
        accountPhotoRepositoryProvider.overrideWithValue(
          emptyAccountPhotoRepository(repository),
        ),
        communityRepositoryProvider.overrideWithValue(FakeCommunity()),
        measurementControllerProvider.overrideWith((ref) => measurement),
        routerInitialLocationProvider.overrideWithValue('/login'),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await repository.changes.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DopmiApp()),
    );
    await tester.pumpAndSettle();
    return (container: container, measurement: measurement, consent: consent);
  }

  testWidgets('first Google login can enable analytics without restarting', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = SocialIdentityRepository();
    final state = await mount(tester, repository);

    await tester.tap(find.byTooltip('Continuar con Google'));
    await tester.pumpAndSettle();
    state.container.read(routerProvider).go('/account-privacy');
    await tester.pumpAndSettle();
    final analytics = find.widgetWithText(SwitchListTile, 'Analítica de uso');
    await tester.ensureVisible(analytics);
    await state.measurement.consentReady;
    expect(tester.widget<SwitchListTile>(analytics).value, isFalse);
    expect(state.consent, isEmpty);
    await tester.tap(analytics);
    await tester.pumpAndSettle();
    await state.measurement.consentReady;

    expect(tester.widget<SwitchListTile>(analytics).value, isTrue);
    expect(state.measurement.ownerId, 'one');
    expect(state.consent, contains(('one', true)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('sign-out and next login keep analytics consent with its owner', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'dopmi.test.one.analytics': true});
    final repository = FakeIdentityRepository()
      ..user = const Identity('one', 'one@example.test', verified: true);
    final state = await mount(tester, repository);
    expect(state.measurement.ownerId, 'one');
    expect(state.measurement.analyticsConsentCurrent, isTrue);

    await state.container.read(identityControllerProvider).logout();
    await tester.pumpAndSettle();
    expect(state.measurement.ownerId, isNull);
    expect(state.measurement.analyticsConsentCurrent, isFalse);

    repository.profile = const Profile(
      id: 'two',
      name: 'Otra cuenta',
      phone: '',
      city: '',
      mode: 'donor',
      intent: 'adopt',
      status: 'active',
      termsVersion: currentTermsVersion,
      privacyVersion: currentPrivacyVersion,
      adultConfirmed: true,
    );
    repository.emit(
      const IdentityEvent(Identity('two', 'two@example.test', verified: true)),
    );
    await tester.pumpAndSettle();
    state.container.read(routerProvider).go('/account-privacy');
    await tester.pumpAndSettle();
    await state.measurement.consentReady;

    expect(state.measurement.ownerId, 'two');
    expect(state.measurement.analyticsConsentCurrent, isFalse);
    final analytics = find.widgetWithText(SwitchListTile, 'Analítica de uso');
    expect(tester.widget<SwitchListTile>(analytics).value, isFalse);
    expect(state.consent.where((entry) => entry.$1 == 'two'), isEmpty);
    expect(tester.takeException(), isNull);
  });
}
