import 'dart:async';

import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/rescue/owned_cases_screen.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'rescue_test.dart' show FakeRescue;

Json ownedItem(
  String id, {
  String program = 'adoption',
  String status = 'published',
  int target = 10000,
  int funded = 2500,
}) {
  final record = <String, dynamic>{
    'id': id,
    'owner_id': 'one',
    'status': status,
    'version': 3,
    if (program == 'support') 'kind': 'case',
    'pet_name': id,
    'species': 'dog',
    'sex': 'female',
    'size': 'medium',
    'photos': <String>['original/photo-one', 'original/photo-two'],
    'personality': <String>['happy'],
    'coexistence': <String>['children'],
    'special_care': 'Cuidados reales',
    'public_data': {'pet_name': id, 'photos': <String>[]},
    'target_cents': target,
    'funded_cents': funded,
  };
  return {
    'id': id,
    'program': program,
    'status': status,
    'version': 3,
    'pet_name': id,
    'cover_path': '',
    'record': record,
    'thread_count': 4,
    'unique_view_count': 7,
    'published_at': '2026-10-01T00:00:00Z',
    'target_cents': target,
    'funded_cents': funded,
    'need_types': ['veterinary', 'medicine', 'food'],
  };
}

class OwnedCasesRepository extends FakeRescue {
  OwnedCasesRepository(this.items);
  final List<Json> items;
  final queries = <Json>[];
  final closed = <Json>[];
  final archives = <String>[];
  final reactivated = <Adoption>[];
  final transitioned = <String>[];
  bool fail = false;
  Completer<void>? pending;
  List<RescueRecord> needs = [];
  int catalogReads = 0;
  int? forcedTotal;
  @override
  Future<Json> ownedCases(
    int page, {
    String program = 'adoption',
    List<String> statuses = const [],
    bool archived = false,
  }) async {
    queries.add({
      'page': page,
      'program': program,
      'statuses': List<String>.from(statuses),
      'archived': archived,
    });
    final filtered = items.where((item) {
      final closed = ['closed', 'adopted', 'archived'].contains(item['status']);
      final phase = switch (item['status']) {
        'published' || 'approved' => 'active',
        'submitted' => 'review',
        'changes_requested' || 'rejected' => 'corrections',
        _ => 'draft',
      };
      return item['program'] == program &&
          closed == archived &&
          (archived || statuses.contains(phase));
    }).toList();
    return {
      'total': forcedTotal ?? filtered.length,
      'total_owned': items.length,
      'items': filtered.skip((page - 1) * 20).take(20).toList(),
    };
  }

  Future<void> accept() async {
    if (pending != null) await pending!.future;
    if (fail) throw Exception('offline');
  }

  void update(String id, String status) {
    final item = items.firstWhere((item) => item['id'] == id);
    item['status'] = status;
    item['record'] = {...Json.from(item['record'] as Map), 'status': status};
  }

  @override
  Future<void> closeAdoption(
    String id,
    int version,
    String reason, {
    bool? dopmiSupport,
    String description = '',
  }) async {
    closed.add({
      'id': id,
      'version': version,
      'reason': reason,
      'support': dopmiSupport,
      'description': description,
    });
    await accept();
    update(id, reason == 'adopted' ? 'adopted' : 'archived');
    items.firstWhere((item) => item['id'] == id)['close_reason'] = reason;
  }

  @override
  Future<void> archiveSupport(String id, int version) async {
    archives.add(id);
    await accept();
    update(id, 'closed');
  }

  @override
  Future<Adoption> reactivateAdoption(Adoption post) async {
    reactivated.add(post);
    await accept();
    update(post.id, 'draft');
    return Adoption({...post.data, 'status': 'draft'});
  }

  @override
  Future<RescueRecord> closeSupportCase(RescueRecord record) =>
      transition(record, 'close');

  @override
  Future<RescueRecord> transition(RescueRecord record, String action) async {
    transitioned.add('${record.id}:$action');
    await accept();
    update(record.id, 'closed');
    return RescueRecord({...record.data, 'status': 'closed'});
  }

  @override
  Future<DataPage<RescueRecord>> completeCaseCatalog(String id) async {
    catalogReads++;
    return DataPage(needs, needs.length);
  }
}

class ArchiveCommunity extends FakeCommunity {
  ArchiveCommunity(this.rescue);
  final OwnedCasesRepository rescue;
  final archived = <String>[];
  List<String> watched = [];
  VoidCallback? refresh;
  @override
  VoidCallback watch(List<String> tables, VoidCallback callback) {
    watched = List.of(tables);
    refresh = callback;
    return () => refresh = null;
  }

  @override
  Future<Adoption> transition(Adoption post, String action) async {
    archived.add('${post.id}:$action');
    await rescue.accept();
    rescue.update(post.id, 'archived');
    return Adoption({...post.data, 'status': 'archived'});
  }
}

Future<GoRouter> mount(
  WidgetTester tester,
  OwnedCasesRepository rescue, {
  String program = 'adoption',
  String? status,
  bool large = false,
  ArchiveCommunity? community,
}) async {
  tester.view.physicalSize = Size(large ? 320 : 377, large ? 640 : 852);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = large ? 2 : 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final font = FontLoader('Inter')
    ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
  await tester.runAsync(font.load);
  final identity = FakeIdentityRepository()
    ..user = const Identity('one', 'fixture@example.test', verified: true);
  addTearDown(() => identity.changes.close());
  final router = GoRouter(
    initialLocation: '/my-cases',
    routes: [
      GoRoute(
        path: '/my-cases',
        builder: (_, state) => MyRescueCasesScreen(
          initialProgram: state.uri.queryParameters['program'] ?? program,
          initialStatus: state.uri.queryParameters['status'] ?? status,
        ),
      ),
      for (final path in [
        '/publish',
        '/notifications',
        '/my-adoptions/:id',
        '/rescue/:id',
      ])
        GoRoute(
          path: path,
          builder: (_, state) =>
              Scaffold(body: Text('Destino ${state.uri.path}')),
        ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        communityRepositoryProvider.overrideWithValue(
          community ?? ArchiveCommunity(rescue),
        ),
        rescueRepositoryProvider.overrideWithValue(rescue),
      ],
      child: MaterialApp.router(
        theme: dopmiTheme(rescuer: true),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'realtime uses real tables and refreshes before the polling interval',
    (tester) async {
      final rescue = OwnedCasesRepository([ownedItem('Luna')]);
      final community = ArchiveCommunity(rescue);
      await mount(tester, rescue, community: community);
      expect(
        community.watched,
        containsAll([
          'dopmi_adoptions',
          'dopmi_rescue_records',
          'dopmi_threads',
          'dopmi_donations',
        ]),
      );
      expect(find.text('Rocky'), findsNothing);
      rescue.items.add(ownedItem('Rocky'));
      community.refresh!();
      await tester.pumpAndSettle();
      expect(find.text('Rocky'), findsOneWidget);
      expect(rescue.queries.length, 2);
    },
  );
  testWidgets(
    'deep-link scope and status are sent before pagination; program switch resets page',
    (tester) async {
      final rescue = OwnedCasesRepository([
        for (var index = 0; index < 21; index++) ownedItem('Mascota $index'),
        ownedItem('Apoyo', program: 'support', status: 'approved'),
      ]);
      final router = await mount(tester, rescue, status: 'active');
      expect(rescue.queries.single['statuses'], ['active']);
      await tapVisible(tester, find.byTooltip('Página siguiente'));
      expect(rescue.queries.last['page'], 2);
      expect(find.text('Mascota 20'), findsOneWidget);
      await tapVisible(tester, find.text('Apoyo').first);
      expect(rescue.queries.last['program'], 'support');
      expect(rescue.queries.last['page'], 1);
      router.go('/my-cases?program=adoption&status=corrections');
      await tester.pumpAndSettle();
      expect(rescue.queries.last['statuses'], ['corrections']);
      expect(find.text('Publicar caso'), findsNothing);
      expect(
        find.text('No tienes casos en adopción en este momento.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'filter last-unchecked restores all; archive query excludes status restriction',
    (tester) async {
      final rescue = OwnedCasesRepository([ownedItem('Luna')]);
      await mount(tester, rescue, status: 'active');
      await tapVisible(tester, find.text('Filtrar'));
      await tapVisible(
        tester,
        find.byKey(const ValueKey('owned-filter-active')),
      );
      await tapVisible(tester, find.text('Listo'));
      expect(rescue.queries.last['statuses'], [
        'corrections',
        'draft',
        'review',
        'active',
      ]);
      await tapVisible(tester, find.byTooltip('Ver archivo'));
      expect(rescue.queries.last['archived'], true);
      expect(rescue.queries.last['statuses'], isEmpty);
      expect(find.text('No tienes casos archivados.'), findsOneWidget);
    },
  );

  testWidgets(
    'true global empty has publication CTA; program-only empty keeps navigation',
    (tester) async {
      final rescue = OwnedCasesRepository([]);
      final router = await mount(tester, rescue);
      expect(find.text('No tienes casos todavía'), findsOneWidget);
      await tapVisible(tester, find.text('Publicar caso'));
      expect(router.state.uri.path, '/publish');
    },
  );

  testWidgets('closing filter with Back retains the chosen statuses', (
    tester,
  ) async {
    final rescue = OwnedCasesRepository([ownedItem('Luna')]);
    await mount(tester, rescue);
    await tapVisible(tester, find.text('Filtrar'));
    await tapVisible(tester, find.byKey(const ValueKey('owned-filter-draft')));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(rescue.queries.last['statuses'], [
      'corrections',
      'review',
      'active',
    ]);
  });

  testWidgets(
    'adoption close waits, is single-flight and persists Dopmi support metadata',
    (tester) async {
      final rescue = OwnedCasesRepository([ownedItem('Luna')])
        ..pending = Completer<void>();
      await mount(tester, rescue);
      await tapVisible(tester, find.byTooltip('Cerrar caso'));
      await tapVisible(tester, find.text('No').last);
      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar cierre'));
      await tester.pump();
      expect(rescue.closed.single, {
        'id': 'Luna',
        'version': 3,
        'reason': 'adopted',
        'support': false,
        'description': '',
      });
      expect(find.text('Guardando…'), findsOneWidget);
      expect(rescue.queries.last['archived'], false);
      await tester.tap(find.widgetWithText(FilledButton, 'Guardando…'));
      expect(rescue.closed.length, 1);
      rescue.pending!.complete();
      await tester.pumpAndSettle();
      expect(rescue.queries.last['archived'], true);
      expect(find.text('Adoptado'), findsOneWidget);
    },
  );

  testWidgets(
    'other close reason and entered description survive a failed request',
    (tester) async {
      final rescue = OwnedCasesRepository([ownedItem('Luna')])..fail = true;
      await mount(tester, rescue);
      await tapVisible(tester, find.byTooltip('Cerrar caso'));
      await tapVisible(
        tester,
        find.byKey(const ValueKey('owned-close-reason')),
      );
      await tapVisible(tester, find.text('Otro motivo').last);
      await tester.enterText(
        find.byKey(const ValueKey('owned-close-description')),
        'Cambio de hogar temporal',
      );
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Confirmar cierre'),
      );
      expect(find.text('Cambio de hogar temporal'), findsOneWidget);
      expect(find.textContaining('No pudimos completar'), findsOneWidget);
      expect(rescue.queries.last['archived'], false);
      rescue.fail = false;
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Confirmar cierre'),
      );
      expect(rescue.closed.last['reason'], 'other');
      expect(rescue.closed.last['support'], isNull);
      expect(rescue.closed.last['description'], 'Cambio de hogar temporal');
    },
  );

  testWidgets(
    'support approved edit remains blocked; remaining acknowledgement gates closing',
    (tester) async {
      final rescue = OwnedCasesRepository([
        ownedItem('Milo', program: 'support', status: 'approved'),
      ]);
      await mount(tester, rescue, program: 'support');
      expect(find.byTooltip('Editar caso'), findsNothing);
      await tapVisible(tester, find.byTooltip('Cerrar caso'));
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirmar cierre'),
            )
            .onPressed,
        isNull,
      );
      await tapVisible(
        tester,
        find.byKey(const ValueKey('owned-close-remaining')),
      );
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Confirmar cierre'),
      );
      expect(rescue.transitioned, ['Milo:close']);
      expect(rescue.queries.last['archived'], true);
    },
  );

  testWidgets(
    'support closure failure never confirms success and remains cancellable',
    (tester) async {
      final rescue = OwnedCasesRepository([
        ownedItem('Milo', program: 'support', status: 'approved', funded: 2500),
      ])..fail = true;
      await mount(tester, rescue, program: 'support');
      await tapVisible(tester, find.byTooltip('Cerrar caso'));
      await tapVisible(
        tester,
        find.byKey(const ValueKey('owned-close-remaining')),
      );
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Confirmar cierre'),
      );
      expect(find.text('Caso finalizado'), findsNothing);
      expect(rescue.queries.last['archived'], false);
      expect(find.text('Cancelar'), findsOneWidget);
      await tapVisible(tester, find.text('Cancelar'));
      expect(find.text('Confirmar cierre'), findsNothing);
      expect(rescue.items.single['status'], 'approved');
    },
  );

  testWidgets(
    'completed archive success follows RPC; notice timer never writes',
    (tester) async {
      final rescue = OwnedCasesRepository([
        ownedItem(
          'Nina',
          program: 'support',
          status: 'approved',
          funded: 10000,
        ),
      ])..fail = true;
      await mount(tester, rescue, program: 'support');
      await tapVisible(tester, find.byTooltip('Archivar caso completado'));
      expect(find.text('Caso finalizado'), findsNothing);
      expect(rescue.queries.last['archived'], false);
      rescue.fail = false;
      await tester.tap(find.byTooltip('Archivar caso completado'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Caso finalizado'), findsOneWidget);
      expect(rescue.archives.length, 2);
      await tester.pump(const Duration(milliseconds: 2900));
      await tester.pumpAndSettle();
      expect(find.text('Caso finalizado'), findsNothing);
      expect(rescue.archives.length, 2);
      expect(rescue.queries.last['archived'], true);
    },
  );

  testWidgets(
    'reactivation passes the complete same-id private draft, without publishing',
    (tester) async {
      final rescue = OwnedCasesRepository([
        ownedItem('Luna', status: 'adopted'),
      ]);
      await mount(tester, rescue);
      await tapVisible(tester, find.byTooltip('Ver archivo'));
      await tapVisible(tester, find.byTooltip('Reactivar caso'));
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Sí, reactivar'),
      );
      final post = rescue.reactivated.single;
      expect(post.id, 'Luna');
      expect(post.photos, ['original/photo-one', 'original/photo-two']);
      expect(post.data['coexistence'], ['children']);
      expect(post.data['special_care'], 'Cuidados reales');
      expect(rescue.closed, isEmpty);
      expect(rescue.queries.last['archived'], false);
      expect(find.text('Borrador'), findsOneWidget);
    },
  );

  testWidgets(
    'discard archives with honest copy and preserves the private record',
    (tester) async {
      final rescue = OwnedCasesRepository([ownedItem('Luna', status: 'draft')]);
      final community = ArchiveCommunity(rescue);
      await mount(tester, rescue, community: community);
      await tapVisible(tester, find.byTooltip('Archivar borrador'));
      expect(find.textContaining('historial se conservarán'), findsOneWidget);
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Sí, archivar'),
      );
      expect(community.archived, ['Luna:archive']);
      expect(rescue.items.single['record']['photos'], hasLength(2));
      expect(rescue.queries.last['archived'], false);
    },
  );

  testWidgets(
    'support breakdown uses the complete public catalog in stable category order and no action',
    (tester) async {
      final rescue = OwnedCasesRepository([
        ownedItem('Milo', program: 'support', status: 'approved'),
      ]);
      RescueRecord need(String id, String category) => RescueRecord({
        'id': id,
        'kind': 'expense',
        'status': 'approved',
        'version': 1,
        'target_cents': 10000,
        'funded_cents': 1000,
        'public_data': {
          'title': id,
          'category': category,
          'photos': <String>[],
        },
        'private_data': {'receipt': 'No mostrar comprobante privado'},
      });
      rescue.needs = [
        need('Comida', 'food'),
        need('Veterinario A', 'veterinary'),
        need('Medicina', 'medicine'),
        need('Veterinario B', 'veterinary'),
      ];
      await mount(tester, rescue, program: 'support');
      await tapVisible(tester, find.byTooltip('Ver desglose'));
      expect(rescue.catalogReads, 1);
      final names = tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data)
          .whereType<String>()
          .toList();
      expect(
        names.indexOf('Veterinario A'),
        lessThan(names.indexOf('Veterinario B')),
      );
      expect(
        names.indexOf('Veterinario B'),
        lessThan(names.indexOf('Medicina')),
      );
      expect(names.indexOf('Medicina'), lessThan(names.indexOf('Comida')));
      expect(find.text('Aportar'), findsNothing);
      expect(find.textContaining('comprobante privado'), findsNothing);
    },
  );

  for (final large in [false, true]) {
    testWidgets(
      'cards and close dialog reflow and remain operable at large=$large',
      (tester) async {
        final rescue = OwnedCasesRepository([
          ownedItem('Mascota con nombre largo'),
        ]);
        await mount(tester, rescue, large: large);
        await tapVisible(tester, find.byTooltip('Cerrar caso'));
        await tapVisible(
          tester,
          find.widgetWithText(OutlinedButton, 'Cancelar'),
        );
        expect(rescue.closed, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
