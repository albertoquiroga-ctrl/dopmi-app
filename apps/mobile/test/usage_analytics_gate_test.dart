import 'dart:async';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/core/config.dart';
import 'package:dopmi_mobile/core/measurement.dart';
import 'package:dopmi_mobile/core/splash.dart';
import 'package:dopmi_mobile/core/usage_analytics_choice.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/profile/account_photo_repository.dart';
import 'package:dopmi_mobile/features/profile/usage_analytics_prompt.dart';
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
  testWidgets(
    'a cached legacy OFF reaches the review prompt with OFF selected',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'dopmi.test.one.analytics': false,
      });
      final repository = FakeIdentityRepository()
        ..user = const Identity('one', 'fixture@example.test', verified: true);
      final store = ChoiceStore()
        ..state = const UsageAnalyticsChoice(
          hasChoice: true,
          consent: false,
          revision: 5,
        );
      final analytics = AnalyticsSpy();
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
          routerInitialLocationProvider.overrideWithValue('/adoptions'),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await repository.changes.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DopmiApp(),
        ),
      );
      await tester.pumpAndSettle();
      final prompt = tester.widget<UsageAnalyticsPrompt>(
        find.byType(UsageAnalyticsPrompt),
      );
      expect(prompt.isReview, isTrue);
      expect(prompt.initialValue, isFalse);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      expect(measurement.analyticsEnabled, isFalse);
      expect(analytics.events, isEmpty);
      expect(store.writes, isEmpty);
      expect(store.state.revision, 5);
      final confirm = find.text('Guardar elección y continuar');
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(store.writes, [false]);
      expect(store.state.hasCurrentExplicitChoice, isTrue);
      expect(store.state.revision, 6);
      expect(measurement.analyticsEnabled, isFalse);
      expect(find.byType(UsageAnalyticsPrompt), findsNothing);
      expect(repository.consentCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a superseded failed choice remains retryable after same-owner refresh',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repository = FakeIdentityRepository()
        ..user = const Identity('one', 'fixture@example.test', verified: true);
      final save = Completer<UsageAnalyticsChoiceResult>();
      final store = ChoiceStore()..pendingSave = save;
      final analytics = AnalyticsSpy();
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
          routerInitialLocationProvider.overrideWithValue('/adoptions'),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await repository.changes.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DopmiApp(),
        ),
      );
      await tester.pumpAndSettle();
      final confirm = find.text('Guardar elección y continuar');
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pump();
      expect(store.writes, [true]);
      expect(measurement.analyticsEnabled, isFalse);

      // Refresh reserves a newer owner revision while the save is in flight.
      // Its unchanged legacy/absent state must not confirm the superseded save.
      final refresh = measurement.owner('one', refresh: true);
      save.completeError(StateError('network'));
      await refresh;
      await tester.pumpAndSettle();
      expect(find.byType(UsageAnalyticsPrompt), findsOneWidget);
      expect(find.textContaining('No pudimos guardar'), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
        isNotNull,
      );
      expect(measurement.analyticsChoicePending, isTrue);
      expect(measurement.analyticsEnabled, isFalse);
      expect(analytics.events, isEmpty);

      store.pendingSave = null;
      final off = find.text('Continuar sin analítica');
      await tester.ensureVisible(off);
      await tester.tap(off);
      await tester.pumpAndSettle();
      expect(store.writes, [true, false]);
      expect(store.state.hasCurrentExplicitChoice, isTrue);
      expect(store.state.consent, isFalse);
      expect(find.byType(UsageAnalyticsPrompt), findsNothing);
      expect(measurement.analyticsEnabled, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a captured analytics prompt cannot save for a different owner',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repository = FakeIdentityRepository()
        ..user = const Identity('one', 'fixture@example.test', verified: true);
      final store = ChoiceStore();
      final preferences = await SharedPreferences.getInstance();
      final measurement = MeasurementController(
        preferences,
        'test',
        AnalyticsSpy(),
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
          routerInitialLocationProvider.overrideWithValue('/adoptions'),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await repository.changes.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DopmiApp(),
        ),
      );
      await tester.pumpAndSettle();
      final confirm = tester
          .widget<UsageAnalyticsPrompt>(find.byType(UsageAnalyticsPrompt))
          .onConfirm;

      // The old rendered callback can still run before the next frame removes
      // it. It must reject the changed actor before reserving any intention.
      await measurement.owner('two');
      await expectLater(confirm(true), throwsStateError);
      expect(store.writes, isEmpty);
      expect(preferences.getBool('dopmi.test.two.analytics'), isNull);
      expect(measurement.analyticsEnabled, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'location gate waits for the optional analytics state to resolve',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repository = FakeIdentityRepository()
        ..user = const Identity('one', 'fixture@example.test', verified: true);
      final pending = Completer<UsageAnalyticsChoice>();
      final store = ChoiceStore()..pendingRead = pending;
      final measurement = MeasurementController(
        await SharedPreferences.getInstance(),
        'test',
        AnalyticsSpy(),
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
          routerInitialLocationProvider.overrideWithValue('/adoptions'),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await repository.changes.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DopmiApp(),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(DopmiSplash), findsOneWidget);
      expect(find.byType(UsageAnalyticsPrompt), findsNothing);
      pending.complete(
        const UsageAnalyticsChoice(
          hasChoice: false,
          consent: false,
          revision: 0,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(UsageAnalyticsPrompt), findsOneWidget);
      expect(store.writes, isEmpty);
    },
  );
  testWidgets(
    'current legal acceptance does not skip optional analytics choice',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repository = FakeIdentityRepository()
        ..user = const Identity('one', 'fixture@example.test', verified: true);
      final store = ChoiceStore();
      final measurement = MeasurementController(
        await SharedPreferences.getInstance(),
        'test',
        AnalyticsSpy(),
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
          routerInitialLocationProvider.overrideWithValue('/adoptions'),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await repository.changes.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DopmiApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(UsageAnalyticsPrompt), findsOneWidget);
      expect(measurement.analyticsEnabled, isFalse);
      expect(repository.consentCount, 0);
      final off = find.text('Continuar sin analítica');
      await tester.ensureVisible(off);
      await tester.tap(off);
      await tester.pumpAndSettle();
      expect(find.byType(UsageAnalyticsPrompt), findsNothing);
      expect(store.writes, [false]);
      expect(repository.consentCount, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
