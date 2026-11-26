import 'dart:async';
import 'dart:io';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/core/config.dart';
import 'package:dopmi_mobile/core/measurement.dart';
import 'package:dopmi_mobile/core/usage_analytics_choice.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/profile/account_photo_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_account_photo_repository.dart';
import 'fake_identity_repository.dart';
import 'measurement_test.dart' show AnalyticsSpy, DiagnosticsSpy;
import 'usage_analytics_choice_test.dart' show ChoiceStore;
import '../tool/capture_design_test.dart' show saveCapture;

void main() {
  Future<
    ({
      MeasurementController measurement,
      AnalyticsSpy analytics,
      FakeCommunity community,
      GlobalKey boundary,
      ProviderContainer container,
    })
  >
  start(
    WidgetTester tester,
    ChoiceStore store, {
    bool? cached,
    bool settle = true,
  }) async {
    SharedPreferences.setMockInitialValues({
      'dopmi.test.one.analytics': ?cached,
    });
    if (const bool.fromEnvironment('CAPTURE_AUTOMATIC_REPORT')) {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final family in ['Inter', 'Fraunces']) {
        final loader = FontLoader(family)
          ..addFont(rootBundle.load('assets/fonts/$family.ttf'));
        await tester.runAsync(loader.load);
      }
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await tester.runAsync(icons.load);
    }
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'fixture@example.test', verified: true);
    final analytics = AnalyticsSpy();
    final measurement = MeasurementController(
      await SharedPreferences.getInstance(),
      'test',
      analytics,
      DiagnosticsSpy(),
      analyticsChoices: store,
    );
    final community = FakeCommunity();
    final container = ProviderContainer(
      overrides: [
        configProvider.overrideWithValue(
          const AppConfig(url: '', key: '', redirect: ''),
        ),
        identityRepositoryProvider.overrideWithValue(identity),
        communityRepositoryProvider.overrideWithValue(community),
        accountPhotoRepositoryProvider.overrideWithValue(
          emptyAccountPhotoRepository(identity),
        ),
        measurementControllerProvider.overrideWith((ref) => measurement),
        routerInitialLocationProvider.overrideWithValue('/adoptions/post'),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await identity.changes.close();
    });
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: UncontrolledProviderScope(
          container: container,
          child: const DopmiApp(),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(const Duration(seconds: 1));
    }
    return (
      measurement: measurement,
      analytics: analytics,
      community: community,
      boundary: boundary,
      container: container,
    );
  }

  for (final choice in ['new', 'legacy-off', 'review', 'on', 'read-error']) {
    testWidgets(
      'entry has no analytics screen for $choice and preserves the optional preference',
      (tester) async {
        final store = ChoiceStore();
        if (choice == 'legacy-off' || choice == 'review' || choice == 'on') {
          store.state = UsageAnalyticsChoice(
            hasChoice: true,
            consent: choice != 'legacy-off',
            revision: 3,
            noticeVersion: choice == 'on' ? usageAnalyticsNoticeVersion : null,
          );
        }
        if (choice == 'read-error') store.failRead = true;
        final result = await start(
          tester,
          store,
          cached: choice == 'legacy-off' ? false : null,
        );
        expect(find.text('Tú decides qué compartes'), findsNothing);
        expect(find.text('Guardar elección y continuar'), findsNothing);
        expect(find.text('Luna'), findsOneWidget);
        expect(result.community.detailViews, ['post']);
        expect(result.measurement.analyticsEnabled, choice == 'on');
        expect(store.writes, isEmpty);
        expect(result.analytics.events, isEmpty);
        expect(tester.takeException(), isNull);
        if (choice == 'new' &&
            const bool.fromEnvironment('CAPTURE_AUTOMATIC_REPORT')) {
          final output = Directory(
            '../../.tools/design-review/automatic-report-20261126',
          );
          await tester.runAsync(() => output.create(recursive: true));
          await tester.runAsync(
            () => saveCapture(
              result.boundary,
              '${output.path}/entry-without-choice.png',
            ),
          );
          result.container.read(routerProvider).go('/privacy-notice');
          await tester.pumpAndSettle();
          await tester.ensureVisible(
            find.text('Reportes de actividad de adopciones'),
          );
          await tester.pumpAndSettle();
          await tester.runAsync(
            () => saveCapture(
              result.boundary,
              '${output.path}/privacy-report-activity.png',
            ),
          );
        }
      },
    );
  }

  testWidgets(
    'a pending optional analytics read does not block detail activity or enable Firebase',
    (tester) async {
      final pending = Completer<UsageAnalyticsChoice>();
      final store = ChoiceStore()..pendingRead = pending;
      final result = await start(tester, store, settle: false);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Luna'), findsOneWidget);
      expect(result.community.detailViews, ['post']);
      expect(result.measurement.analyticsEnabled, isFalse);
      expect(store.writes, isEmpty);
      pending.complete(
        const UsageAnalyticsChoice(
          hasChoice: false,
          consent: false,
          revision: 0,
        ),
      );
      await tester.pumpAndSettle();
      expect(result.community.detailViews, ['post']);
      expect(result.analytics.events, isEmpty);
    },
  );
}
