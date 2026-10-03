import 'dart:async';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/adoption/discovery_filters.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';

class FilterQueries extends FakeCommunity {
  final queries = <Json>[];
  @override
  Future<DataPage<Adoption>> discovery(Json filters, int page) {
    queries.add(Map<String, dynamic>.from(filters));
    return super.discovery(filters, page);
  }
}

class DelayedFilters extends FilterQueries {
  final female = Completer<DataPage<Adoption>>();
  @override
  Future<DataPage<Adoption>> discovery(Json filters, int page) {
    if (filters['sex'] == 'female') return female.future;
    if (filters['sex'] == 'male') {
      return Future.value(
        DataPage([
          Adoption({...post.data, 'id': 'latest', 'pet_name': 'Milo'}),
        ], 1),
      );
    }
    return super.discovery(filters, page);
  }
}

void main() {
  Future<FilterQueries> open(
    WidgetTester tester, {
    bool large = false,
    FilterQueries? repository,
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
    final repo = repository ?? FilterQueries();
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        communityRepositoryProvider.overrideWithValue(repo),
        routerInitialLocationProvider.overrideWithValue('/adoptions'),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await identity.changes.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DopmiApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Filtros'));
    await tester.pumpAndSettle();
    return repo;
  }

  Finder label(String text) => find.descendant(
    of: find.byType(DiscoveryFilters),
    matching: find.text(text),
  );

  testWidgets('cancel discards filter drafts without a server query', (
    tester,
  ) async {
    final repo = await open(tester);
    await tester.tap(label('Hembra'));
    await tester.tap(find.byTooltip('Mediano'));
    await tester.tap(label('Tranquilo'));
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();
    expect(repo.queries, [
      {'species': 'dog'},
    ]);
    expect(find.text('Luna'), findsOneWidget);
  });
  testWidgets('filter opens immediately and back or outside discards drafts', (
    tester,
  ) async {
    final repo = await open(tester);
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();
    for (final outside in [false, true]) {
      await tester.tap(find.byTooltip('Filtros'));
      await tester.pump();
      final context = tester.element(find.byType(DiscoveryFilters));
      expect(ModalRoute.of(context)!.animation!.value, 1);
      await tester.tap(label('Hembra'));
      await tester.pump();
      if (outside) {
        await tester.tapAt(const Offset(4, 4));
      } else {
        await tester.binding.handlePopRoute();
      }
      await tester.pump();
      expect(find.byType(DiscoveryFilters), findsNothing);
      expect(repo.queries, [
        {'species': 'dog'},
      ]);
    }
    await tester.tap(find.byTooltip('Filtros'));
    await tester.pump();
    final option = tester.widget<FilterOption>(
      find.ancestor(of: label('Hembra'), matching: find.byType(FilterOption)).first,
    );
    expect(option.selected, false);
    expect(tester.takeException(), isNull);
  });
  testWidgets('apply sends real keys and clear preserves species', (
    tester,
  ) async {
    final repo = await open(tester);
    await tester.tap(label('Hembra'));
    await tester.tap(find.byTooltip('Mediano'));
    await tester.tap(label('Tranquilo'));
    await tester.tap(label('Aplicar filtros'));
    await tester.pumpAndSettle();
    expect(repo.queries.last, {
      'species': 'dog',
      'sex': 'female',
      'size': 'medium',
      'personality': ['tranquilo'],
    });
    await tester.tap(find.byTooltip('Filtros'));
    await tester.pumpAndSettle();
    final selected = tester.widget<FilterOption>(
      find
          .ancestor(of: label('Tranquilo'), matching: find.byType(FilterOption))
          .first,
    );
    expect(selected.selected, true);
    await tester.tap(label('Limpiar filtros'));
    await tester.pumpAndSettle();
    expect(repo.queries.last, {'species': 'dog'});
  });
  testWidgets('large text dialog scrolls to apply and keeps close reachable', (
    tester,
  ) async {
    final repo = await open(tester, large: true);
    await tester.scrollUntilVisible(
      label('Aplicar filtros'),
      150,
      scrollable: find.descendant(
        of: find.byType(DiscoveryFilters),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(label('Aplicar filtros'));
    await tester.pumpAndSettle();
    expect(repo.queries.length, 2);
    expect(find.byType(DiscoveryFilters), findsNothing);
  });
  testWidgets(
    'late filter response cannot replace the latest selected results',
    (tester) async {
      final repo = DelayedFilters();
      await open(tester, repository: repo);
      await tester.tap(label('Hembra'));
      await tester.tap(label('Aplicar filtros'));
      await tester.pump();
      await tester.tap(find.byTooltip('Filtros'));
      await tester.pump();
      await tester.tap(label('Macho'));
      await tester.tap(label('Aplicar filtros'));
      await tester.pumpAndSettle();
      expect(find.text('Milo'), findsOneWidget);
      repo.female.complete(DataPage([repo.post], 1));
      await tester.pumpAndSettle();
      expect(find.text('Milo'), findsOneWidget);
      expect(find.text('Luna'), findsNothing);
    },
  );
}
