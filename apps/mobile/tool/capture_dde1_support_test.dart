// Synthetic local captures only; no server, user data or external transport.
import 'dart:io';

import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/core/media/photo_runtime.dart';
import 'package:dopmi_mobile/core/media/photo_store.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/rescue/case_update_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_screens.dart';
import 'package:dopmi_mobile/features/rescue/support_stories.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/community_test.dart' show FakeCommunity;
import '../test/fake_identity_repository.dart';
import '../test/rescue_test.dart' show FakeRescue, FakeCaseUpdates;
import 'capture_design_test.dart' show saveCapture;

final captureCase = RescueRecord({
  'id': 'capture-case',
  'kind': 'case',
  'status': 'approved',
  'target_cents': 250000,
  'funded_cents': 85000,
  'public_data': {
    'pet_name': 'Luna',
    'story': 'Luna necesita tratamiento para recuperarse y encontrar un hogar.',
    'city': 'Monterrey',
    'photos': ['fixture/luna.jpg', 'fixture/luna-2.jpg'],
    'need_items': [
      {
        'id': 'planned',
        'type': 'medicine',
        'title': 'Medicamentos',
        'amount_cents': 80000,
        'detail': 'Tratamiento de cuatro semanas',
      },
    ],
  },
});
final captureExpense = RescueRecord({
  'id': 'capture-expense',
  'parent_id': 'capture-case',
  'kind': 'expense',
  'status': 'approved',
  'target_cents': 250000,
  'funded_cents': 85000,
  'public_data': {
    'title': 'Tratamiento veterinario',
    'category': 'veterinary',
    'description': 'Consulta y tratamiento para Luna.',
    'photos': ['fixture/evidence.jpg'],
  },
});

class SupportCaptureRescue extends FakeRescue {
  @override
  Future<String> fileUrl(String path) async => 'https://fixture.test/$path';
  @override
  Future<DataPage<RescueRecord>> catalog(int page, {String? caseId}) async =>
      DataPage(
        caseId == null ? [captureCase] : [captureCase, captureExpense],
        caseId == null ? 1 : 2,
      );
  @override
  Future<DataPage<RescueRecord>> completeCaseCatalog(String caseId) async =>
      DataPage([captureCase, captureExpense], 2);
}

void main() {
  testWidgets('capture DDE1 support stories and collapsed expanded needs', (
    tester,
  ) async {
    // This tool is a Flutter test harness, outside the conventional test folder.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    final originalShadows = debugDisableShadows;
    final semantics = tester.ensureSemantics();
    final filter =
        Platform.environment['CAPTURE_FILTER'] ??
        const String.fromEnvironment('CAPTURE_FILTER');
    try {
      debugDisableShadows = false;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final family in ['Inter', 'Fraunces', 'MaterialIcons']) {
        final loader = FontLoader(family)
          ..addFont(
            rootBundle.load(
              family == 'MaterialIcons'
                  ? 'fonts/MaterialIcons-Regular.otf'
                  : 'assets/fonts/$family.ttf',
            ),
          );
        await tester.runAsync(loader.load);
      }
      final bytes = (await tester.runAsync(
        () => File('tool/fixtures/milo.png').readAsBytes(),
      ))!;
      final output = Directory('../../.tools/dde1/captures-support');
      await tester.runAsync(() => output.create(recursive: true));
      for (final spec in [
        ('normal', const Size(377, 852), 1.0),
        ('115', const Size(377, 852), 1.15),
        ('320-200', const Size(320, 640), 2.0),
      ]) {
        for (final route in ['/rescue-cases', '/stories', '/detail']) {
          if (filter.isNotEmpty && !'${spec.$1}:$route'.contains(filter)) {
            continue;
          }
          tester.view.physicalSize = spec.$2;
          final runtime = PhotoRuntime(
            store: MemoryPhotoStore(),
            download: (_, cancellation) async {
              cancellation.check();
              return bytes;
            },
          );
          final identity = FakeIdentityRepository();
          final container = ProviderContainer(
            overrides: [
              rescueRepositoryProvider.overrideWithValue(
                SupportCaptureRescue(),
              ),
              caseUpdateRepositoryProvider.overrideWithValue(FakeCaseUpdates()),
              communityRepositoryProvider.overrideWithValue(FakeCommunity()),
              identityRepositoryProvider.overrideWithValue(identity),
              photoRuntimeProvider.overrideWithValue(runtime),
            ],
          );
          final router = GoRouter(
            initialLocation: route,
            routes: [
              GoRoute(
                path: '/rescue-cases',
                builder: (_, _) => const RescueCatalogScreen(),
              ),
              GoRoute(
                path: '/stories',
                builder: (_, _) => SupportStories(records: [captureCase]),
              ),
              GoRoute(
                path: '/detail',
                builder: (_, _) =>
                    const RescueCatalogScreen(caseId: 'capture-case'),
              ),
            ],
          );
          final key = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: UncontrolledProviderScope(
                container: container,
                child: MaterialApp.router(
                  debugShowCheckedModeBanner: false,
                  theme: dopmiTheme(),
                  routerConfig: router,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(spec.$3),
                      disableAnimations: route == '/stories',
                    ),
                    child: child!,
                  ),
                ),
              ),
            ),
          );
          Future<void> ready() async {
            for (var i = 0; i < 3; i++) {
              await tester.pump(const Duration(milliseconds: 100));
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 40)),
              );
            }
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }

          Future<void> capture(String suffix) async {
            await ready();
            await tester.runAsync(
              () => saveCapture(
                key,
                '${output.path}/${spec.$1}-${route.substring(1)}-$suffix.png',
              ),
            );
          }

          await capture('initial');
          if (route == '/rescue-cases') {
            final supporting = find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics && widget.properties.label == 'Apoyar',
            );
            expect(supporting, findsOneWidget);
            expect(
              tester.widget<Semantics>(supporting).properties.selected,
              isTrue,
            );
          }
          if (route == '/detail') {
            final need = find.byKey(const ValueKey('capture-expense'));
            await tester.scrollUntilVisible(
              need,
              180,
              scrollable: find.byType(Scrollable).first,
            );
            await capture('need-collapsed');
            expect(
              find.text('Evidencias cargadas por rescatista:'),
              findsNothing,
            );
            final toggle = find.descendant(
              of: need,
              matching: find.text('Tratamiento veterinario'),
            );
            await tester.ensureVisible(toggle);
            await tester.tap(toggle);
            await capture('need-expanded');
            expect(
              find.text('Evidencias cargadas por rescatista:'),
              findsOneWidget,
            );
          }
          await tester.pumpWidget(const SizedBox());
          router.dispose();
          container.dispose();
          runtime.dispose();
          await identity.changes.close();
        }
      }
    } finally {
      debugDisableShadows = originalShadows;
      semantics.dispose();
    }
  });
}
