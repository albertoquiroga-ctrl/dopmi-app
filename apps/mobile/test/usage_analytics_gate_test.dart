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
