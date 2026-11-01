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
import 'nearby_location_test.dart' show mapConfig;
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

Future<void> mapPublication(
  WidgetTester tester,
  String path,
  PhotoDraftCommunity community, {
  DraftCaseRescue? rescue,
}) async {
  SharedPreferences.setMockInitialValues({});
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
      placeLookupProvider.overrideWithValue(FixturePlaceLookup()),
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
}

Future<void> selectFixtureMap(WidgetTester tester) async {
  await tapPublication(
    tester,
    find.byKey(const ValueKey('publication-location-map')),
  );
  await tester.tap(find.text('Punto de prueba'));
  await tester.pumpAndSettle();
  await tapPublication(
    tester,
    find.byKey(const ValueKey('location-map-confirm')),
  );
}

void main() {
  testWidgets(
    'adoption draft saves before a map choice, then saves only the selected coarse pair',
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
      expect(repo.savedPayload!['approximate_latitude'], 25.69);
      expect(repo.savedPayload!['approximate_longitude'], -100.32);
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
    'support case requires its map choice for continuing and sends coarse values through the save request',
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
      expect(rescue.publicSaved!['approximate_latitude'], 25.69);
      expect(rescue.publicSaved!['approximate_longitude'], -100.32);
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
