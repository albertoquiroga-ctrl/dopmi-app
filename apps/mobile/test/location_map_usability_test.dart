import 'dart:async';

import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/adoption/location_map_picker.dart';
import 'package:dopmi_mobile/features/adoption/location_selection.dart';
import 'package:dopmi_mobile/features/adoption/location_service.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_identity_repository.dart';
import 'nearby_location_test.dart'
    show FakeNearbyService, mapConfig, PendingPlaceLookup;
import 'publication_map_integration_test.dart' show FixturePlaceLookup;

class PendingSearchLookup extends FixturePlaceLookup {
  final result = Completer<SelectedLocation>();
  @override
  Future<SelectedLocation> search(String query) => result.future;
}

Future<List<ApproximateLocation?>> openUsablePicker(
  WidgetTester tester, {
  PlaceLookup? lookup,
  FakeNearbyService? service,
  double textScale = 1,
  GlobalKey? captureBoundary,
}) async {
  SharedPreferences.setMockInitialValues({});
  final repo = FakeIdentityRepository()
    ..user = const Identity('one', 'fixture@example.test', verified: true);
  final shown = <ApproximateLocation?>[];
  final container = ProviderContainer(
    overrides: [
      identityRepositoryProvider.overrideWithValue(repo),
      configProvider.overrideWithValue(mapConfig),
      placeLookupProvider.overrideWithValue(lookup ?? FixturePlaceLookup()),
      locationServiceProvider.overrideWithValue(service ?? FakeNearbyService()),
      locationMapBuilderProvider.overrideWithValue((context, point, select) {
        shown.add(point);
        return const ColoredBox(
          color: Color(0xffeef2e6),
          child: Center(child: Text('Mapa de prueba')),
        );
      }),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    RepaintBoundary(
      key: captureBoundary,
      child: UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: dopmiTheme(rescuer: true),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => chooseLocationOnMap(
                  context,
                  initial: SelectedLocation(
                    latitude: 25.686614,
                    longitude: -100.316113,
                    city: 'Monterrey',
                    region: 'Nuevo León',
                  ),
                ),
                child: const Text('Abrir mapa'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Abrir mapa'));
  await tester.pumpAndSettle();
  return shown;
}

void main() {
  for (final sample in [
    (const Size(320, 640), 2.0, 220.0),
    (const Size(390, 844), 1.0, 0.0),
  ]) {
    testWidgets(
      'map confirmation and close stay reachable at ${sample.$1}, scale ${sample.$2}, keyboard ${sample.$3}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = sample.$1;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetViewInsets);
        await openUsablePicker(tester, textScale: sample.$2);
        tester.view.viewInsets = FakeViewPadding(bottom: sample.$3);
        await tester.pumpAndSettle();
        final confirm = find.byKey(const ValueKey('location-map-confirm'));
        expect(confirm.hitTestable(), findsOneWidget);
        expect(find.byTooltip('Cerrar mapa').hitTestable(), findsOneWidget);
        expect(
          tester.getRect(confirm).bottom,
          lessThanOrEqualTo(sample.$1.height - sample.$3),
        );
        expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'failed search preserves the selected point and explains its pending work',
    (tester) async {
      final lookup = PendingSearchLookup();
      final shown = await openUsablePicker(tester, lookup: lookup);
      final query = find.byKey(const ValueKey('location-map-query'));
      await tester.ensureVisible(query);
      await tester.pumpAndSettle();
      await tester.enterText(query, 'Otra zona');
      await tester.pump();
      expect(shown.last?.latitude, 25.686614);
      await tester.ensureVisible(find.text('Buscar zona'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buscar zona'));
      await tester.pump();
      expect(find.text('Buscando la zona…'), findsOneWidget);
      lookup.result.completeError(
        const LocationException('No encontramos esa zona.'),
      );
      await tester.pumpAndSettle();
      expect(shown.last?.latitude, 25.686614);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('location-map-city')))
            .controller!
            .text,
        'Monterrey',
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('location-map-confirm')),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('denied GPS preserves the already selected precise location', (
    tester,
  ) async {
    final service = FakeNearbyService();
    final shown = await openUsablePicker(tester, service: service);
    await tester.ensureVisible(find.text('Cerca de mi ubicación actual'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerca de mi ubicación actual'));
    await tester.pumpAndSettle();
    expect(service.permissionRequests, [true]);
    expect(shown.last?.longitude, -100.316113);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('location-map-region')))
          .controller!
          .text,
      'Nuevo León',
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('location-map-confirm')),
          )
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('a late geocoder cannot replace the point after a timeout', (
    tester,
  ) async {
    final lookup = PendingPlaceLookup();
    final service = FakeNearbyService()
      ..pending = Future.value(
        const ApproximateLocation(26.123456, -101.234567),
      );
    final shown = await openUsablePicker(
      tester,
      service: service,
      lookup: lookup,
    );
    final locate = find.text('Cerca de mi ubicación actual');
    await tester.ensureVisible(locate);
    await tester.pumpAndSettle();
    await tester.tap(locate);
    await tester.pump();
    expect(lookup.requests.length, 1);
    await tester.pump(const Duration(seconds: 21));
    await tester.pumpAndSettle();
    lookup.requests.single.complete(
      SelectedLocation(
        latitude: 26.123456,
        longitude: -101.234567,
        city: 'Otra ciudad',
        region: 'Otro estado',
      ),
    );
    await tester.pumpAndSettle();
    expect(shown.last?.latitude, 25.686614);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('location-map-city')))
          .controller!
          .text,
      'Monterrey',
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('location-map-confirm')),
          )
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });
}
