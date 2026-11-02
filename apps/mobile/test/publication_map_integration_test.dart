import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/adoption/location_map_picker.dart';
import 'package:dopmi_mobile/features/adoption/location_selection.dart';
import 'package:dopmi_mobile/features/adoption/location_service.dart';
import 'package:dopmi_mobile/features/adoption/publication_frame.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'case_publication_test.dart' show DraftCaseRescue;
import 'community_test.dart' show PhotoDraftCommunity;
import 'fake_identity_repository.dart';
import 'nearby_location_test.dart'
    show mapConfig, FakeNearbyService, PendingPlaceLookup;
import 'publication_frame_test.dart' show tapPublication;

class FixturePlaceLookup implements PlaceLookup {
  @override
  Future<SelectedLocation> describe(ApproximateLocation location) async =>
      SelectedLocation(
        latitude: location.latitude,
        longitude: location.longitude,
        city: 'Monterrey',
        region: 'Nuevo León',
      );
  @override
  Future<SelectedLocation> search(String query) =>
      describe(const ApproximateLocation(25.686614, -100.316113));
}

class CentroidAddressLookup extends FixturePlaceLookup {
  @override
  Future<SelectedLocation> describe(ApproximateLocation location) async =>
      SelectedLocation(
        latitude: 0,
        longitude: 0,
        city: 'Monterrey',
        region: 'Nuevo León',
      );
}

Future<ProviderContainer> mapPublication(
  WidgetTester tester,
  String path,
  PhotoDraftCommunity community, {
  DraftCaseRescue? rescue,
  bool defaultAllowed = false,
  FakeNearbyService? gps,
  PlaceLookup? lookup,
}) async {
  SharedPreferences.setMockInitialValues({
    if (defaultAllowed)
      'dopmi.rescuer-location.prompt.v1:test:example.test:one': true,
    if (defaultAllowed)
      'dopmi.rescuer-location.follow-device.v1:test:example.test:one': true,
  });
  final identity = FakeIdentityRepository()
    ..user = const Identity('one', 'fixture@example.test', verified: true);
  identity.profile = const Profile(
    id: 'one',
    name: 'Ana',
    phone: '',
    city: '',
    mode: 'rescuer',
    intent: 'rescue',
    status: 'active',
    termsVersion: currentTermsVersion,
    privacyVersion: currentPrivacyVersion,
    adultConfirmed: true,
  );
  final container = ProviderContainer(
    overrides: [
      configProvider.overrideWithValue(mapConfig),
      identityRepositoryProvider.overrideWithValue(identity),
      communityRepositoryProvider.overrideWithValue(community),
      if (rescue != null) rescueRepositoryProvider.overrideWithValue(rescue),
      routerInitialLocationProvider.overrideWithValue(path),
      if (gps != null) locationServiceProvider.overrideWithValue(gps),
      placeLookupProvider.overrideWithValue(lookup ?? FixturePlaceLookup()),
      locationMapBuilderProvider.overrideWithValue(
        (context, point, select) => TextButton(
          onPressed: () =>
              select(const ApproximateLocation(25.686614, -100.316113)),
          child: const Text('Punto de prueba'),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const DopmiApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> selectFixtureMap(WidgetTester tester) async {
  await tapPublication(
    tester,
    find.byKey(const ValueKey('publication-location-map')),
  );
  final point = find.text('Punto de prueba');
  await tester.ensureVisible(point);
  await tester.pumpAndSettle();
  expect(point.hitTestable(), findsOneWidget);
  await tester.tap(point);
  await tester.pumpAndSettle();
  await tapPublication(
    tester,
    find.byKey(const ValueKey('location-map-confirm')),
  );
}

void main() {
  for (final kind in ['adoption', 'case']) {
    testWidgets(
      'new $kind uses the authorized device point as an editable initial location',
      (tester) async {
        final community = PhotoDraftCommunity();
        final rescue = DraftCaseRescue();
        final gps = FakeNearbyService()
          ..pending = Future.value(
            const ApproximateLocation(26.123456, -101.234567),
          );
        await mapPublication(
          tester,
          kind == 'adoption' ? '/my-adoptions/new' : '/rescue/new?kind=case',
          community,
          rescue: rescue,
          defaultAllowed: true,
          gps: gps,
          lookup: CentroidAddressLookup(),
        );
        expect(gps.permissionRequests, [false]);
        await tapPublication(tester, find.text('Guardar borrador'));
        final initial = kind == 'adoption'
            ? community.savedPayload!
            : rescue.publicSaved!;
        expect(initial['approximate_latitude'], 26.123456);
        expect(initial['approximate_longitude'], -101.234567);
        expect(initial['city'], 'Monterrey');
        expect(initial[kind == 'adoption' ? 'region' : 'state'], 'Nuevo León');
        await selectFixtureMap(tester);
        await tapPublication(tester, find.text('Guardar borrador'));
        final changed = kind == 'adoption'
            ? community.savedPayload!
            : rescue.publicSaved!;
        expect(changed['approximate_latitude'], 25.686614);
        expect(changed['approximate_longitude'], -100.316113);
        expect(gps.permissionRequests, [false]);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'a stored adoption point takes priority over a different current device point',
    (tester) async {
      final community = PhotoDraftCommunity();
      community.post = Adoption({
        ...community.post.data,
        'approximate_latitude': 25.69,
        'approximate_longitude': -100.32,
      });
      final gps = FakeNearbyService()
        ..pending = Future.value(
          const ApproximateLocation(26.123456, -101.234567),
        );
      await mapPublication(
        tester,
        '/my-adoptions/post',
        community,
        defaultAllowed: true,
        gps: gps,
      );
      await tapPublication(tester, find.text('Guardar borrador'));
      expect(community.savedPayload!['approximate_latitude'], 25.69);
      expect(community.savedPayload!['approximate_longitude'], -100.32);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('a late default lookup cannot replace a manual selection', (
    tester,
  ) async {
    final lookup = PendingPlaceLookup();
    final community = PhotoDraftCommunity();
    final gps = FakeNearbyService()
      ..pending = Future.value(
        const ApproximateLocation(26.123456, -101.234567),
      );
    await mapPublication(
      tester,
      '/my-adoptions/new',
      community,
      defaultAllowed: true,
      gps: gps,
      lookup: lookup,
    );
    expect(lookup.requests.length, 1);
    await tester.ensureVisible(
      find.byKey(const ValueKey('publication-location-map')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('publication-location-map')));
    // The reverse lookup is deliberately pending; the map remains editable.
    await tester.pump(const Duration(milliseconds: 300));
    final mapPoint = find.text('Punto de prueba');
    await tester.ensureVisible(mapPoint);
    await tester.pump(const Duration(milliseconds: 300));
    expect(mapPoint.hitTestable(), findsOneWidget);
    final lookupsBeforeManualChoice = lookup.requests.length;
    await tester.tap(mapPoint);
    await tester.pump();
    expect(lookup.requests.length, lookupsBeforeManualChoice + 1);
    lookup.requests.last.complete(
      SelectedLocation(
        latitude: 25.686614,
        longitude: -100.316113,
        city: 'Zona elegida',
        region: 'Estado elegido',
      ),
    );
    await tester.pumpAndSettle();
    await tapPublication(
      tester,
      find.byKey(const ValueKey('location-map-confirm')),
    );
    lookup.requests.first.complete(
      SelectedLocation(
        latitude: 26.123456,
        longitude: -101.234567,
        city: 'Sugerencia anterior',
        region: 'Estado anterior',
      ),
    );
    // The map's initial reverse lookup was superseded by the manual choice.
    for (final request in lookup.requests.where(
      (request) => !request.isCompleted,
    )) {
      request.complete(SelectedLocation(latitude: 0, longitude: 0));
    }
    await tester.pumpAndSettle();
    await tapPublication(tester, find.text('Guardar borrador'));
    expect(community.savedPayload!['approximate_latitude'], 25.686614);
    expect(community.savedPayload!['city'], 'Zona elegida');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'adoption draft saves before a map choice, then saves the selected precise private pair',
    (tester) async {
      final repo = PhotoDraftCommunity();
      await mapPublication(tester, '/my-adoptions/post', repo);
      expect(
        find.byKey(const ValueKey('publication-field-city')),
        findsNothing,
      );
      expect(
        tester
            .widget<PublicationFooter>(find.byType(PublicationFooter))
            .onContinue,
        isNull,
      );
      await tapPublication(tester, find.text('Guardar borrador'));
      expect(repo.savedPayload!.containsKey('approximate_latitude'), isFalse);
      await selectFixtureMap(tester);
      expect(
        tester
            .widget<PublicationFooter>(find.byType(PublicationFooter))
            .onContinue,
        isNotNull,
      );
      await tapPublication(tester, find.text('Guardar borrador'));
      expect(repo.savedPayload!['approximate_latitude'], 25.686614);
      expect(repo.savedPayload!['location_precision_version'], 1);
      expect(repo.savedPayload!['approximate_longitude'], -100.316113);
      expect(repo.savedPayload!['city'], 'Monterrey');
      expect(repo.savedPayload!['region'], 'Nuevo León');
      expect(repo.savedPayload!['publisher_bio'], 'Ayudamos a adoptar.');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'existing adoption restores its private pair without another map selection',
    (tester) async {
      final repo = PhotoDraftCommunity();
      repo.post = Adoption({
        ...repo.post.data,
        'approximate_latitude': 25.69,
        'approximate_longitude': -100.32,
      });
      await mapPublication(tester, '/my-adoptions/post', repo);
      expect(
        tester
            .widget<PublicationFooter>(find.byType(PublicationFooter))
            .onContinue,
        isNotNull,
      );
      await tapPublication(tester, find.text('Guardar borrador'));
      expect(repo.savedPayload!['approximate_latitude'], 25.69);
      expect(repo.savedPayload!['approximate_longitude'], -100.32);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'support case requires its map choice for continuing and sends precise private values through the save request',
    (tester) async {
      final rescue = DraftCaseRescue();
      await mapPublication(
        tester,
        '/rescue/case-one',
        PhotoDraftCommunity(),
        rescue: rescue,
      );
      expect(find.byKey(const ValueKey('case-field-city')), findsNothing);
      expect(
        tester
            .widget<PublicationFooter>(find.byType(PublicationFooter))
            .onContinue,
        isNull,
      );
      await selectFixtureMap(tester);
      expect(
        tester
            .widget<PublicationFooter>(find.byType(PublicationFooter))
            .onContinue,
        isNotNull,
      );
      await tapPublication(tester, find.text('Guardar borrador'));
      expect(rescue.publicSaved!['approximate_latitude'], 25.686614);
      expect(rescue.publicSaved!['location_precision_version'], 1);
      expect(rescue.publicSaved!['approximate_longitude'], -100.316113);
      expect(rescue.publicSaved!['city'], 'Monterrey');
      expect(rescue.publicSaved!['state'], 'Nuevo León');
      expect(
        rescue.caseSaves.last.files,
        rescue.caseFiles ??
            [
              {'role': 'public', 'path': 'one/case-one/photo.jpg'},
            ],
      );
      expect(tester.takeException(), isNull);
    },
  );
}
