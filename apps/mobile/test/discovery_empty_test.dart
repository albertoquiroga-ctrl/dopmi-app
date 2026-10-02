import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/discovery_empty.dart';
import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';

class EmptyRepository extends FakeCommunity {
  bool cats = true;
  final queries = <Json>[];
  @override
  Future<DataPage<Adoption>> discovery(Json filters, int page) async {
    queries.add(Map.of(filters));
    return filters['species'] == 'cat' && cats
        ? DataPage([
            Adoption({...post.data, 'species': 'cat'}),
          ], 1)
        : const DataPage([], 0);
  }
}

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('empty heading scales its reference width at $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(377, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var switched = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: dopmiTheme(),
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(377, 852),
              textScaler: TextScaler.linear(scale),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: DiscoveryEmpty(
                  filtered: false,
                  global: false,
                  species: 'dog',
                  clear: () {},
                  switchSpecies: () => switched = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.text('No hay mascotas disponibles')).width,
        closeTo(scale == 1 ? 244.244 : 270, .5),
      );
      final action = find.byType(FilledButton);
      await tester.ensureVisible(action);
      await tester.tap(action);
      expect(switched, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  Future<void> open(WidgetTester tester, EmptyRepository repo) async {
    tester.view.physicalSize = const Size(377, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'fixture@example.test', verified: true);
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        communityRepositoryProvider.overrideWithValue(repo),
        routerInitialLocationProvider.overrideWithValue('/adoptions'),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DopmiApp()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('empty species switches to real alternate-category results', (
    tester,
  ) async {
    final repo = EmptyRepository();
    await open(tester, repo);
    expect(find.text('No hay mascotas disponibles'), findsOneWidget);
    expect(find.text('Ver gatos'), findsOneWidget);
    await tester.tap(find.text('Ver gatos'));
    await tester.pumpAndSettle();
    expect(find.text('Luna'), findsOneWidget);
    expect(repo.queries.last['species'], 'cat');
  });
  testWidgets('both empty categories offer the real support route', (
    tester,
  ) async {
    await open(tester, EmptyRepository()..cats = false);
    expect(find.text('Ir a Apoyar'), findsOneWidget);
    expect(find.text('Ver gatos'), findsNothing);
  });
  testWidgets(
    'empty filtered search clears keys and preserves chosen species',
    (tester) async {
      final repo = EmptyRepository();
      await open(tester, repo);
      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hembra'));
      await tester.tap(find.text('Aplicar filtros'));
      await tester.pumpAndSettle();
      expect(find.text('Limpiar filtros'), findsOneWidget);
      await tester.tap(find.text('Limpiar filtros'));
      await tester.pumpAndSettle();
      expect(repo.queries.where((q) => q['species'] == 'dog').last, {
        'species': 'dog',
      });
      expect(find.text('Ver gatos'), findsOneWidget);
    },
  );
}
