import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';

class DetailRepository extends FakeCommunity {
  bool verified = false;
  final signed = <String>[];
  @override
  Future<Json?> publicProfile(String id) async => {'verified': verified};
  @override
  Future<String> photoUrl(String path) async {
    signed.add(path);
    throw Exception('offline');
  }
}

class DistanceRepository extends DetailRepository {
  @override
  Future<Adoption?> detail(String id) async =>
      Adoption(Map<String, dynamic>.from(post.data)..remove('distance_km'));
}

void main() {
  Future<DetailRepository> open(
    WidgetTester tester, {
    bool large = false,
    bool photos = false,
    bool verified = false,
    DetailRepository? repository,
    String initialLocation = '/adoptions/post',
  }) async {
    tester.view.physicalSize = large
        ? const Size(320, 640)
        : const Size(377, 852);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = large ? 2 : 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'fixture@example.test', verified: true);
    final repo = (repository ?? DetailRepository())..verified = verified;
    repo.post = Adoption({
      ...repo.post.data,
      'photos': photos ? ['approved/one', 'approved/two'] : <String>[],
      'vaccinated': true,
      'special_care': 'Necesita su medicamento cada mañana.',
    });
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        communityRepositoryProvider.overrideWithValue(repo),
        routerInitialLocationProvider.overrideWithValue(initialLocation),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DopmiApp()),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets(
    'detail carries server-calculated discovery distance without fabricating it',
    (tester) async {
      final repository = DistanceRepository();
      repository.post = Adoption({...repository.post.data, 'distance_km': 3.4});
      await open(tester, repository: repository, initialLocation: '/adoptions');
      await tester.tap(find.text('Luna'));
      await tester.pumpAndSettle();
      expect(find.text('3.4 km'), findsOneWidget);
      expect(find.text('Quiero adoptar'), findsOneWidget);
    },
  );

  testWidgets(
    'badge requires server verification and care remains accessible',
    (tester) async {
      await open(tester, verified: false);
      expect(find.text('Rescatista verificado'), findsNothing);
      expect(find.text('Necesita su medicamento cada mañana.'), findsOneWidget);
      await Scrollable.ensureVisible(
        tester.element(find.text('Más sobre su salud y cuidados')),
        alignment: .25,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Más sobre su salud y cuidados'));
      await tester.pumpAndSettle();
      expect(find.text('Vacunas al día: Sí'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'real gallery tracks swipes and retries only approved photo paths',
    (tester) async {
      final repo = await open(tester, photos: true, verified: true);
      final semantics = tester.ensureSemantics();
      expect(find.text('Rescatista verificado'), findsOneWidget);
      expect(find.bySemanticsLabel('Foto 1 de 2'), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Foto 2 de 2'), findsOneWidget);
      expect(repo.signed.toSet(), {'approved/one', 'approved/two'});
      semantics.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('large text keeps contact and save fixed while content scrolls', (
    tester,
  ) async {
    await open(tester, large: true);
    expect(
      tester.getRect(find.text('Quiero adoptar')).bottom,
      lessThanOrEqualTo(640),
    );
    expect(
      tester.getRect(find.byTooltip('Guardar')).bottom,
      lessThanOrEqualTo(640),
    );
    await tester.tap(find.text('Quiero adoptar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Iniciamos el proceso?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
