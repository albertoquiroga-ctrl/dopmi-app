import 'dart:async';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/core/config.dart';
import 'package:dopmi_mobile/core/measurement.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/auth_ui.dart';
import 'package:dopmi_mobile/features/identity/auth_screens.dart';
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
import 'usage_analytics_choice_test.dart' show ChoiceStore;

void main() {
  Future<
    ({
      AnalyticsSpy analytics,
      ChoiceStore store,
      MeasurementController measurement,
    })
  >
  start(WidgetTester tester, FakeIdentityRepository repository) async {
    SharedPreferences.setMockInitialValues({});
    final analytics = AnalyticsSpy();
    final store = ChoiceStore();
    final measurement = MeasurementController(
      await SharedPreferences.getInstance(),
      'test',
      analytics,
      DiagnosticsSpy(),
      analyticsChoices: store,
    );
    final container = ProviderContainer(
      overrides: [
        configProvider.overrideWithValue(
          const AppConfig(url: '', key: '', redirect: ''),
        ),
        identityRepositoryProvider.overrideWithValue(repository),
        communityRepositoryProvider.overrideWithValue(FakeCommunity()),
        accountPhotoRepositoryProvider.overrideWithValue(
          emptyAccountPhotoRepository(repository),
        ),
        measurementControllerProvider.overrideWith((ref) => measurement),
        routerInitialLocationProvider.overrideWithValue('/confirm'),
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
    await tester.enterText(
      find.byType(TextFormField).first,
      'fixture@example.test',
    );
    await tester.enterText(find.byType(TextFormField).last, '123456');
    return (analytics: analytics, store: store, measurement: measurement);
  }

  Future<void> tap(WidgetTester tester, String label) async {
    final target = find.text(label);
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  for (final firstLegal in [false, true]) {
    testWidgets(
      'confirmed signup enters without analytics choice or collection (first legal: $firstLegal)',
      (tester) async {
        final repository = FakeIdentityRepository();
        if (firstLegal) {
          repository.profile = const Profile(
            id: 'one',
            name: 'Fixture',
            phone: '',
            city: '',
            mode: 'donor',
            intent: 'adopt',
            status: 'active',
            termsVersion: null,
          );
        }
        final (:analytics, :store, :measurement) = await start(
          tester,
          repository,
        );
        await tap(tester, 'Verificar código');
        expect(repository.codeRequests, 1);
        expect(analytics.events, isEmpty);
        expect(store.writes, isEmpty);
        expect(measurement.analyticsEnabled, isFalse);

        if (firstLegal) {
          final consent = find.byType(AuthConsentRow);
          await tester.ensureVisible(consent);
          await tester.tapAt(
            tester.getRect(consent).topLeft + const Offset(2, 3),
          );
          await tester.pumpAndSettle();
          await tap(tester, 'Aceptar actualización y continuar');
          expect(repository.consentCount, 1);
          expect(analytics.events, isEmpty);
        }
        expect(find.text('Tú decides qué compartes'), findsNothing);
        expect(find.byType(ConfirmationScreen), findsNothing);
        expect(store.writes, isEmpty);
        expect(analytics.events, isEmpty);
        expect(measurement.analyticsEnabled, isFalse);
        await tester.pumpAndSettle();
        expect(analytics.events, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('confirmation response A never attributes signup to current B', (
    tester,
  ) async {
    final repository = ReplacedConfirmationRepository();
    final (:analytics, :measurement, :store) = await start(tester, repository);
    await tap(tester, 'Verificar código');
    expect(repository.current?.id, 'two');
    expect(measurement.ownerId, 'two');
    expect(find.text('Tú decides qué compartes'), findsNothing);
    expect(store.writes, isEmpty);
    expect(analytics.events, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'successful redirect may unmount confirmation before its ACK continuation',
    (tester) async {
      final repository = DelayedConfirmationRepository();
      final (:analytics, :measurement, :store) = await start(
        tester,
        repository,
      );
      await tap(tester, 'Verificar código');
      expect(repository.started.isCompleted, isTrue);
      expect(find.byType(ConfirmationScreen), findsNothing);
      expect(find.text('Tú decides qué compartes'), findsNothing);
      expect(analytics.events, isEmpty);
      repository.release.complete();
      await tester.pumpAndSettle();
      expect(measurement.analyticsEnabled, isFalse);
      expect(store.writes, isEmpty);
      expect(analytics.events, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}

class ReplacedConfirmationRepository extends FakeIdentityRepository {
  @override
  Future<String?> confirmCode(
    String email,
    String code, {
    required bool recovery,
  }) async {
    final actor = await super.confirmCode(email, code, recovery: recovery);
    profile = const Profile(
      id: 'two',
      name: 'Fixture Two',
      phone: '',
      city: '',
      mode: 'donor',
      intent: 'adopt',
      status: 'active',
      termsVersion: currentTermsVersion,
      privacyVersion: currentPrivacyVersion,
      adultConfirmed: true,
    );
    emit(
      const IdentityEvent(Identity('two', 'two@example.test', verified: true)),
    );
    return actor;
  }
}

class DelayedConfirmationRepository extends FakeIdentityRepository {
  final started = Completer<void>(), release = Completer<void>();
  @override
  Future<String?> confirmCode(
    String email,
    String code, {
    required bool recovery,
  }) async {
    final actor = await super.confirmCode(email, code, recovery: recovery);
    started.complete();
    await release.future;
    return actor;
  }
}
