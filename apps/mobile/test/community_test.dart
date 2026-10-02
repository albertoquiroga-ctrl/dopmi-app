import 'dart:async';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/core/measurement.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_identity_repository.dart';
import 'rescue_test.dart' show FakeRescue;

import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';

class DetailThreadCommunity extends FakeCommunity {
  final openedPosts = <String>[];
  @override
  Future<Json> thread(String id) async => {
    'id': id,
    'post_id': 'post',
    'pet_name': 'Luna',
    'participant_name': 'Patricia V.',
    'status': 'active',
  };
  @override
  Future<Adoption?> detail(String id) async {
    openedPosts.add(id);
    return post;
  }
}

class ReceiptThreadCommunity extends DetailThreadCommunity {
  bool failReceipt = true;
  int reads = 0;
  bool resumed = false;
  @override
  Future<void> readThread(String id) async {
    reads++;
    if (failReceipt) throw Exception('offline');
  }

  @override
  Future<List<Json>> messages(String id, {Json? before}) async => [
    {
      'id': 'first',
      'sender_id': 'other',
      'body': 'Puedes conocer a Luna el domingo.',
      'created_at': '2026-10-01T16:00:00Z',
    },
    if (resumed)
      {
        'id': 'second',
        'sender_id': 'other',
        'body': 'Te esperamos a las diez.',
        'created_at': '2026-10-02T16:00:00Z',
      },
  ];
}

class HistoryThreadCommunity extends DetailThreadCommunity {
  bool denyThread = false;
  @override
  Future<Json> thread(String id) async {
    if (denyThread) throw Exception('access denied');
    return super.thread(id);
  }

  Completer<List<Json>>? pendingOlder;
  final cursors = <String>[];
  Json message(int number) => {
    'id': 'message-$number',
    'sender_id': 'other',
    'body': 'Mensaje $number',
    'created_at': DateTime.utc(2026, 10, 1, 0, number).toIso8601String(),
  };
  @override
  Future<List<Json>> messages(String id, {Json? before}) async {
    if (before == null) return List.generate(40, (index) => message(index + 1));
    cursors.add(before['id'] as String);
    if (pendingOlder != null) return pendingOlder!.future;
    return [message(0), message(1)];
  }
}

class CommunityAnalyticsSpy implements ProductAnalytics {
  final events = <String>[];
  @override
  Future<void> enabled(bool value) async {}
  @override
  Future<void> event(String name, {Map<String, Object>? parameters}) async {
    events.add(name);
  }
}

class CommunityDiagnosticsSpy implements ErrorDiagnostics {
  @override
  Future<void> discardPending() async {}
  @override
  Future<void> enabled(bool value) async {}
  @override
  Future<void> record(Object error, StackTrace stack, {String? reason}) async {}
  @override
  Future<void> sendPending() async {}
}

class FakeCommunity implements CommunityRepository {
  Adoption post = Adoption({
    'id': 'post',
    'owner_id': 'owner',
    'pet_name': 'Luna',
    'species': 'dog',
    'sex': 'female',
    'size': 'medium',
    'age_months': 24,
    'city': 'Monterrey',
    'region': 'Nuevo León',
    'story': 'Una historia por conocer.',
    'publisher_name': 'Refugio Luna',
    'publisher_bio': 'Ayudamos a adoptar.',
    'photos': <String>[],
    'status': 'published',
    'version': 1,
  });
  bool failSave = false, failSend = true;
  bool failFavorite = false;
  List<Adoption>? discoveryItems;
  Map<int, List<Adoption>>? discoveryPages;
  List<SupportOpportunity> supportItems = [];
  List<Json> threadItems = [];
  List<SavedEntry>? savedItems;
  final sentIds = <String>[];
  final stored = <String, Json>{};
  Json? savedPayload;
  Json? reported;
  @override
  String? get userId => 'one';
  @override
  Future<int> unreadNotificationCount() async => 0;
  @override
  VoidCallback watch(List<String> tables, VoidCallback refresh) => () {};
  @override
  Future<DataPage<Adoption>> catalog(Json filters, int page) async =>
      DataPage([post], 1);
  @override
  Future<DataPage<Adoption>> discovery(Json filters, int page) async {
    if (discoveryPages != null) {
      return DataPage(
        discoveryPages![page] ?? [],
        discoveryPages!.values.fold(0, (total, items) => total + items.length),
      );
    }
    return DataPage(
      discoveryItems ?? [post],
      (discoveryItems ?? [post]).length,
    );
  }

  @override
  Future<List<SupportOpportunity>> discoverySupport() async => supportItems;
  @override
  Future<Adoption?> detail(String id) async => post;
  @override
  Future<Adoption?> own(String id) async => post;
  @override
  Future<void> favorite(String id, bool saved) async {
    if (failFavorite) throw Exception('offline');
    post = Adoption({...post.data, 'saved': saved});
  }

  @override
  Future<DataPage<SavedEntry>> savedAdoptions(int page) async => DataPage(
    savedItems ??
        [
          SavedEntry({...post.data, 'available': true, 'saved': true}),
        ],
    savedItems?.length ?? 1,
  );
  @override
  Future<DataPage<SavedEntry>> savedCases(int page) async =>
      const DataPage([], 0);
  @override
  Future<DataPage<SavedEntry>> savedRescuers(int page) async =>
      const DataPage([], 0);
  @override
  Future<void> favoriteCase(String id, bool saved) async {}
  @override
  Future<void> favoriteRescuer(String id, bool saved) async {}
  @override
  Future<String> report(
    String type,
    String id,
    String reason,
    String details,
  ) async {
    reported = {'type': type, 'id': id, 'reason': reason, 'details': details};
    return 'report-one';
  }

  @override
  Future<String> startThread(String postId) async => 'thread-one';
  @override
  Future<Json?> publicProfile(String id) async => {
    'id': id,
    'name': 'Refugio Luna',
    'bio': 'Rescate responsable.',
    'city': 'Monterrey',
    'region': 'Nuevo León',
    'adopted_count': 2,
    'saved': false,
    'activity': [
      {
        'id': 'update-one',
        'case_id': 'case-one',
        'body': 'Luna sigue mejorando.',
        'photos': <String>[],
        'published_at': '2026-09-26T20:00:00Z',
      },
    ],
    'adoptions': [post.data],
    'cases': [
      {
        'id': 'case-one',
        'public_data': {'pet_name': 'Choco'},
      },
    ],
  };
  @override
  Future<Adoption?> ownForCase(String caseId) async => null;
  @override
  Future<List<Json>> personalImpact() async => [
    {
      'case_id': 'case-one',
      'public_data': {'pet_name': 'Choco'},
      'allocated_cents': 9200,
      'updates': [
        {
          'id': 'update-one',
          'body': 'Choco volvió a comer.',
          'photos': <String>[],
          'published_at': '2026-09-26T20:00:00Z',
        },
      ],
    },
  ];
  @override
  Future<DataPage<Json>> threads(int page, {String search = ''}) async =>
      DataPage(threadItems, threadItems.length);

  @override
  Future<Adoption> save(Json payload, {String? id, int? version}) async {
    savedPayload = payload;
    if (failSave) throw Exception('offline');
    post = Adoption({
      ...payload,
      'id': id ?? 'new-post',
      'owner_id': 'one',
      'version': 2,
      'status': 'draft',
    });
    return post;
  }

  @override
  Future<Json> thread(String id) async => {
    'id': id,
    'pet_name': 'Luna',
    'status': 'active',
  };
  @override
  Future<List<Json>> messages(String id, {Json? before}) async =>
      stored.values.toList();
  @override
  Future<void> readThread(String id) async {}
  @override
  Future<Json> sendMessage(
    String threadId,
    String messageId,
    String body,
  ) async {
    sentIds.add(messageId);
    stored[messageId] = {
      'id': messageId,
      'body': body,
      'sender_id': 'one',
      'created_at': '2026-09-13T20:00:00Z',
    };
    if (failSend) {
      failSend = false;
      throw Exception('Response lost after server accepted message');
    }
    return stored[messageId]!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PagedMatchCommunity extends FakeCommunity {
  final pages = <int>[];
  @override
  Future<DataPage<SavedEntry>> savedAdoptions(int page) async {
    pages.add(page);
    return DataPage([
      for (var i = (page - 1) * 20; i < (page == 1 ? 20 : 21); i++)
        SavedEntry({
          ...post.data,
          'id': 'pet-$i',
          'pet_name': 'Mascota $i',
          'available': true,
        }),
    ], 21);
  }
}

class PhotoDraftCommunity extends FakeCommunity {
  PhotoDraftCommunity() {
    post = Adoption({
      ...post.data,
      'status': 'draft',
      'photos': ['fixture/draft-photo'],
    });
  }
  @override
  Future<String> photoUrl(String path) async =>
      throw const FormatException('Foto sin conexión en fixture');
}

void main() {
  Future<ProviderContainer> start(
    WidgetTester tester,
    FakeCommunity repo,
    String path, {
    MeasurementController? measurement,
    bool rescuer = false,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'ana@example.test', verified: true);
    if (rescuer) await identity.setExperience('rescuer');
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        communityRepositoryProvider.overrideWithValue(repo),
        rescueRepositoryProvider.overrideWithValue(FakeRescue()),
        routerInitialLocationProvider.overrideWithValue(path),
        if (measurement != null)
          measurementControllerProvider.overrideWith((ref) => measurement),
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
    return container;
  }

  Future<void> tap(WidgetTester tester, String label) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(label).last,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('conversation history pages and ignores an obsolete page error', (
    tester,
  ) async {
    final repo = HistoryThreadCommunity()
      ..pendingOlder = Completer<List<Json>>();
    await start(tester, repo, '/messages/thread-one');
    await tester.enterText(find.byType(TextField), 'Borrador pendiente');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver mensajes anteriores'));
    await tester.pump();
    expect(repo.cursors, ['message-1']);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    repo.pendingOlder!.completeError(Exception('obsolete page response'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No pudimos completar'), findsNothing);
    repo.pendingOlder = null;
    await tester.tap(find.text('Ver mensajes anteriores'));
    await tester.pumpAndSettle();
    expect(repo.cursors, ['message-1', 'message-1']);
    expect(find.text('Mensaje 0'), findsOneWidget);
    expect(find.text('Mensaje 1'), findsOneWidget);
    expect(find.text('Ver mensajes anteriores'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Mensaje 40'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Mensaje 40'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Mensaje 0'),
      -400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Mensaje 0'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Borrador pendiente',
    );
    repo.denyThread = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Mensaje 0'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Volver a cargar'), findsOneWidget);
    expect(repo.sentIds, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('receipt failure keeps history and resume recovers with draft', (
    tester,
  ) async {
    final repo = ReceiptThreadCommunity();
    await start(tester, repo, '/messages/thread-one');
    expect(find.text('Puedes conocer a Luna el domingo.'), findsOneWidget);
    expect(find.textContaining('No pudimos marcar'), findsOneWidget);
    expect(find.text('Volver a cargar'), findsNothing);
    await tester.enterText(find.byType(TextField), 'Nos vemos el domingo');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    repo.failReceipt = false;
    repo.resumed = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(repo.reads, 2);
    expect(find.textContaining('No pudimos marcar'), findsNothing);
    expect(find.text('Puedes conocer a Luna el domingo.'), findsOneWidget);
    expect(find.text('Te esperamos a las diez.'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Nos vemos el domingo',
    );
    expect(repo.sentIds, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('chat detail keyboard navigation keeps the unsent draft', (
    tester,
  ) async {
    final repo = DetailThreadCommunity();
    await start(tester, repo, '/messages/thread-one');
    expect(find.text('Patricia V.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Quiero conocer a Luna');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(repo.openedPosts, isEmpty);
    final link = find.byKey(const ValueKey('chat-detail-link'));
    expect(
      find.descendant(
        of: link,
        matching: find.byKey(const ValueKey('reference-keyboard-outline')),
      ),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(repo.openedPosts, ['post']);
    expect(find.text('Quiero adoptar'), findsOneWidget);
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Quiero conocer a Luna',
    );
    expect(repo.sentIds, isEmpty);
    expect(tester.takeException(), isNull);
  });
  for (final rescuer in [false, true]) {
    testWidgets(
      'conversation composer palette and keyboard; rescuer=$rescuer',
      (tester) async {
        await start(
          tester,
          FakeCommunity(),
          '/messages/thread-one',
          rescuer: rescuer,
        );
        final field = tester.widget<TextField>(find.byType(TextField));
        final border = field.decoration!.enabledBorder! as OutlineInputBorder;
        expect(
          border.borderSide.color,
          rescuer ? const Color(0xffe3e4ed) : const Color(0xffe6e2dd),
        );
        expect(
          field.style!.color,
          rescuer ? const Color(0xff151423) : const Color(0xff15110d),
        );
        expect(
          field.decoration!.hintStyle!.color,
          rescuer ? const Color(0xff4f4e5c) : const Color(0xff554e48),
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Hola');
        await tester.pumpAndSettle();
        expect(
          tester.getBottomRight(find.byTooltip('Enviar mensaje')).dy,
          lessThanOrEqualTo(544),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'catalog opens approved detail and persists a favorite at narrow width',
    (tester) async {
      final repo = FakeCommunity();
      await start(tester, repo, '/adoptions');
      await tester.tap(find.text('Luna'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Guardar'));
      await tester.pumpAndSettle();
      expect(repo.post.saved, true);
      expect(find.byTooltip('Guardada'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'match favorite contact can be cancelled without starting a thread',
    (tester) async {
      final repo = FakeCommunity();
      await start(tester, repo, '/messages');
      expect(find.text('Mis favoritos'), findsOneWidget);
      expect(find.text('Luna'), findsOneWidget);
      await tester.tap(find.byTooltip('Escribir sobre Luna'));
      await tester.pumpAndSettle();
      expect(find.text('Sí, contactar rescatista'), findsOneWidget);
      await tester.tap(find.text('Todavía no'));
      await tester.pumpAndSettle();
      expect(find.text('Chats'), findsOneWidget);
      expect(find.text('Sí, contactar rescatista'), findsNothing);
    },
  );
  testWidgets('match rows show real unread counts and closed status', (
    tester,
  ) async {
    final repo = FakeCommunity()
      ..threadItems = [
        {
          'id': 'one',
          'post_id': 'post',
          'pet_name': 'Luna',
          'participant_name': 'Ana',
          'last_message': 'Hola Luna',
          'unread_count': 3,
          'status': 'active',
          'updated_at': '2026-09-30T18:30:00Z',
        },
        {
          'id': 'two',
          'pet_name': 'Milo',
          'participant_name': 'Patricia',
          'last_message': 'Old preview',
          'unread_count': 0,
          'status': 'closed',
        },
      ];
    await start(tester, repo, '/messages');
    expect(find.text('Hola Luna'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Conversación cerrada'), findsOneWidget);
    expect(find.text('Old preview'), findsNothing);
    expect(find.textContaining('null'), findsNothing);
  });
  testWidgets(
    'all match favorites load beyond first page and sort the complete list',
    (tester) async {
      final repo = PagedMatchCommunity();
      await start(tester, repo, '/messages');
      await tester.tap(find.text('Ver más'));
      await tester.pumpAndSettle();
      expect(repo.pages, contains(2));
      expect(find.text('Chats'), findsNothing);
      await tester.tap(find.text('Ordenar Más recientes'));
      await tester.pumpAndSettle();
      expect(find.text('Ordenar Más antiguos'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Mascota 20')).dy,
        lessThan(tester.getTopLeft(find.text('Mascota 0')).dy),
      );
      await tester.tap(find.byTooltip('Volver a Mis match'));
      await tester.pumpAndSettle();
      expect(find.text('Chats'), findsOneWidget);
      await tester.tap(find.text('Ver más'));
      await tester.pumpAndSettle();
      expect(find.text('Ordenar Más antiguos'), findsOneWidget);
    },
  );
  testWidgets(
    'system back from full favorites returns to match instead of leaving the app',
    (tester) async {
      final repo = PagedMatchCommunity();
      await start(tester, repo, '/messages');
      await tester.tap(find.text('Ver más'));
      await tester.pumpAndSettle();
      expect(find.text('Chats'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Mis match'), findsOneWidget);
      expect(find.text('Chats'), findsOneWidget);
      expect(find.text('Ordenar Más recientes'), findsNothing);
    },
  );
  testWidgets('empty favorites explores the real adoption feed', (
    tester,
  ) async {
    final repo = FakeCommunity()..savedItems = [];
    await start(tester, repo, '/messages');
    expect(
      find.text('Es tiempo de compartir una nueva aventura'),
      findsOneWidget,
    );
    expect(find.text('Ver más'), findsNothing);
    await tester.tap(find.text('Explorar'));
    await tester.pumpAndSettle();
    expect(find.text('Perros'), findsOneWidget);
    expect(find.byTooltip('Pasar'), findsOneWidget);
  });
  testWidgets(
    'chat composer remains above the keyboard and empty send is disabled',
    (tester) async {
      final repo = FakeCommunity();
      await start(tester, repo, '/messages/thread-one');
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton && widget.tooltip == 'Enviar mensaje',
              ),
            )
            .onPressed,
        isNull,
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Hola');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton && widget.tooltip == 'Enviar mensaje',
              ),
            )
            .onPressed,
        isNotNull,
      );
      expect(
        tester.getBottomRight(find.byTooltip('Enviar mensaje')).dy,
        lessThanOrEqualTo(544),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('failed detail favorite rolls the optimistic state back', (
    tester,
  ) async {
    final repo = FakeCommunity()..failFavorite = true;
    await start(tester, repo, '/adoptions/post');
    await tester.tap(find.byTooltip('Guardar'));
    await tester.pumpAndSettle();
    expect(repo.post.saved, false);
    expect(find.byTooltip('Guardar'), findsOneWidget);
    expect(find.textContaining('No pudimos completar'), findsOneWidget);
  });
  testWidgets('contact asks for confirmation before opening the thread', (
    tester,
  ) async {
    final repo = FakeCommunity();
    await start(tester, repo, '/adoptions/post');
    await tap(tester, 'Quiero adoptar');
    expect(find.text('¿Iniciamos el proceso?'), findsOneWidget);
    await tester.tap(find.text('Sí, contactar rescatista'));
    await tester.pumpAndSettle();
    expect(find.text('Luna'), findsOneWidget);
  });
  testWidgets('saved experience separates adoption and donation', (
    tester,
  ) async {
    final repo = FakeCommunity();
    await start(tester, repo, '/saved');
    expect(find.text('Luna'), findsOneWidget);
    expect(find.text('Adopción'), findsOneWidget);
    expect(find.text('Donación'), findsOneWidget);
    await tester.tap(find.text('Donación'));
    await tester.pumpAndSettle();
    expect(
      find.text('Guarda un caso desde Apoyar para encontrarlo aquí.'),
      findsOneWidget,
    );
  });
  testWidgets(
    'public rescuer can be saved and reported with server acknowledgement',
    (tester) async {
      final repo = FakeCommunity();
      await start(tester, repo, '/people/owner');
      await tester.ensureVisible(find.text('Guardar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Guardado'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Reportar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Reportar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enviar reporte'));
      await tester.pumpAndSettle();
      expect(repo.reported?['type'], 'rescuer');
      expect(find.text('Recibimos tu reporte para revisión.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Casos'));
      await tester.pumpAndSettle();
      expect(find.text('Choco'), findsOneWidget);
      await tester.ensureVisible(find.text('Enviar mensaje'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enviar mensaje'));
      await tester.pumpAndSettle();
      expect(find.text('¿Enviar mensaje?'), findsOneWidget);
      expect(
        find.text('Abriremos una conversación sobre Luna.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Ahora no'));
      await tester.pumpAndSettle();
      expect(find.text('Refugio Luna'), findsOneWidget);
    },
  );
  testWidgets('personal impact only renders allocated cases and updates', (
    tester,
  ) async {
    final repo = FakeCommunity();
    await start(tester, repo, '/impact');
    expect(find.text('Choco'), findsOneWidget);
    expect(find.text('\$92.00 MXN'), findsOneWidget);
    expect(find.text('Asignados de tus aportaciones'), findsOneWidget);
    expect(find.text('Choco volvió a comer.'), findsOneWidget);
  });
  testWidgets('swipe buttons pass and persist likes without double actions', (
    tester,
  ) async {
    final repo = FakeCommunity();
    await start(tester, repo, '/adoptions');
    expect(find.text('Luna'), findsOneWidget);
    await tester.tap(find.byTooltip('Me gusta'));
    await tester.pumpAndSettle();
    expect(repo.post.saved, true);
    expect(
      find.text('Nuestra manada llegó hasta aquí por ahora'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('swipe contact records analytics only after the thread exists', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final analytics = CommunityAnalyticsSpy();
    final measurement = MeasurementController(
      await SharedPreferences.getInstance(),
      'test',
      analytics,
      CommunityDiagnosticsSpy(),
    );
    await measurement.owner('one');
    await measurement.setAnalytics(true);
    await start(
      tester,
      FakeCommunity(),
      '/adoptions',
      measurement: measurement,
    );
    await tester.tap(find.byTooltip('Contactar'));
    await tester.pumpAndSettle();
    expect(analytics.events, isEmpty);
    await tester.tap(find.text('Sí, contactar rescatista'));
    await tester.pumpAndSettle();
    expect(analytics.events, ['contact_started']);
    expect(find.text('Luna'), findsOneWidget);
  });
  testWidgets('an eligible support card appears after two adoptions', (
    tester,
  ) async {
    final repo = FakeCommunity();
    repo.discoveryItems = [
      repo.post,
      Adoption({...repo.post.data, 'id': 'second', 'pet_name': 'Milo'}),
    ];
    repo.supportItems = [
      SupportOpportunity({
        'case_id': 'case-one',
        'expense_id': 'expense-one',
        'pet_name': 'Choco',
        'expense_title': 'Tratamiento',
        'reimbursable_cents': 10000,
        'funded_cents': 2500,
      }),
    ];
    await start(tester, repo, '/adoptions');
    await tester.tap(find.byTooltip('Pasar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Pasar'));
    await tester.pumpAndSettle();
    expect(find.text('Choco'), findsOneWidget);
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel(RegExp('25 % cubierto')), findsOneWidget);
    expect(find.text(r'$25 de $100'), findsOneWidget);
    expect(find.text('Apoya con sus necesidades'), findsOneWidget);
    await tester.drag(find.text('Choco'), const Offset(40, 0));
    await tester.pumpAndSettle();
    expect(find.text('Choco'), findsOneWidget);
    await tester.tap(find.text('Apoya con sus necesidades'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Choco necesita recuperarse'), findsOneWidget);
    final context = tester.element(
      find.textContaining('Choco necesita recuperarse'),
    );
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    expect(find.text('Apoya con sus necesidades'), findsOneWidget);
    await tester.drag(find.text('Choco'), const Offset(150, 0));
    await tester.pumpAndSettle();
    expect(
      find.text('Nuestra manada llegó hasta aquí por ahora'),
      findsOneWidget,
    );
    expect(find.text('Confirmar aportación'), findsNothing);
    semantics.dispose();
  });
  testWidgets('short drag returns and long drag passes the current card', (
    tester,
  ) async {
    final repo = FakeCommunity();
    repo.discoveryItems = [
      repo.post,
      Adoption({...repo.post.data, 'id': 'second', 'pet_name': 'Milo'}),
    ];
    await start(tester, repo, '/adoptions');
    await tester.drag(find.text('Luna'), const Offset(-40, 0));
    await tester.pumpAndSettle();
    expect(find.text('Luna'), findsOneWidget);
    await tester.drag(find.text('Luna'), const Offset(-150, 0));
    await tester.pumpAndSettle();
    expect(find.text('Milo'), findsOneWidget);
  });
  testWidgets('failed like remains retryable while the deck advances', (
    tester,
  ) async {
    final repo = FakeCommunity()..failFavorite = true;
    repo.discoveryItems = [
      repo.post,
      Adoption({...repo.post.data, 'id': 'second', 'pet_name': 'Milo'}),
    ];
    await start(tester, repo, '/adoptions');
    await tester.tap(find.byTooltip('Me gusta'));
    await tester.pumpAndSettle();
    expect(find.text('Milo'), findsOneWidget);
    expect(
      find.text('No pudimos guardar a Luna. Intenta de nuevo.'),
      findsOneWidget,
    );
    expect(find.text('Volver a intentar'), findsOneWidget);
    expect(repo.post.saved, false);
    repo.failFavorite = false;
    await tester.ensureVisible(find.text('Volver a intentar'));
    await tester.tap(find.text('Volver a intentar'));
    await tester.pumpAndSettle();
    expect(repo.post.saved, true);
    expect(find.text('Milo'), findsOneWidget);
    expect(
      find.text('No pudimos guardar a Luna. Intenta de nuevo.'),
      findsNothing,
    );
  });
  testWidgets('the deck fetches the next page without duplicating cards', (
    tester,
  ) async {
    final repo = FakeCommunity();
    repo.discoveryPages = {
      1: [
        repo.post,
        Adoption({...repo.post.data, 'id': 'second', 'pet_name': 'Milo'}),
      ],
      2: [
        Adoption({...repo.post.data, 'id': 'third', 'pet_name': 'Nina'}),
      ],
    };
    await start(tester, repo, '/adoptions');
    await tester.tap(find.byTooltip('Pasar'));
    await tester.pumpAndSettle();
    expect(find.text('Milo'), findsOneWidget);
    await tester.tap(find.byTooltip('Pasar'));
    await tester.pumpAndSettle();
    expect(find.text('Nina'), findsOneWidget);
  });
  testWidgets(
    'failed draft save preserves authored content and can be retried',
    (tester) async {
      final repo = PhotoDraftCommunity();
      await start(tester, repo, '/my-adoptions/${repo.post.id}');
      await tap(tester, 'Continuar');
      await tester.enterText(
        find.byKey(const ValueKey('publication-field-pet_name')),
        'Mora',
      );
      repo.failSave = true;
      await tap(tester, 'Continuar');
      expect(repo.savedPayload!['pet_name'], 'Mora');
      expect(
        find.text(
          'No pudimos completar la solicitud. Comprueba tu conexión y vuelve a intentar.',
        ),
        findsWidgets,
      );
      repo.failSave = false;
      await tap(tester, 'Continuar');
      expect(repo.post.name, 'Mora');
      expect(repo.post.status, 'draft');
      expect(find.text('Revisa antes de enviar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('case-linked adoption keeps an independent moderated draft', (
    tester,
  ) async {
    final repo = FakeCommunity();
    await start(tester, repo, '/my-adoptions/new?case=case-one');
    expect(
      find.text(
        'Esta publicación está vinculada a un caso aprobado. Su revisión de adopción es independiente.',
      ),
      findsOneWidget,
    );
    await tap(tester, 'Guardar borrador');
    expect(repo.savedPayload?['rescue_case_id'], 'case-one');
    expect(repo.post.status, 'draft');
    expect(find.text('Sube fotos de la mascota'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continuar'))
          .onPressed,
      isNull,
    );
  });
  testWidgets(
    'ambiguous message response retries with same id and removes private data on logout',
    (tester) async {
      final repo = FakeCommunity();
      final container = await start(tester, repo, '/messages/thread-one');
      await tester.enterText(
        find.byType(TextField),
        'Hola, quiero conocer a Luna.',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Enviar mensaje'));
      await tester.pumpAndSettle();
      expect(find.text('Reintentar envío'), findsOneWidget);
      await tap(tester, 'Reintentar envío');
      expect(repo.sentIds.length, 2);
      expect(repo.sentIds.toSet().length, 1);
      expect(repo.stored.length, 1);
      expect(find.text('Hola, quiero conocer a Luna.'), findsOneWidget);
      await container.read(identityControllerProvider).logout();
      await tester.pumpAndSettle();
      expect(find.text('Hola, quiero conocer a Luna.'), findsNothing);
      expect(find.text('Bienvenido a DopMi'), findsOneWidget);
    },
  );
  test('photo processing strips location and description while bounding dimensions', () {
    final photo = img.Image(width: 2000, height: 500, numChannels: 3)
      ..clear(img.ColorRgb8(100, 120, 140));
    photo.exif.imageIfd.imageDescription = 'private description';
    photo.exif.gpsIfd.gpsLatitude = 25.6866;
    final input = Uint8List.fromList(img.encodeJpg(photo));
    final output = img.decodeJpg(preparePhoto(input))!;
    expect(output.width, 1600);
    expect(output.height, 400);
    expect(output.exif.imageIfd.imageDescription, isNull);
    expect(output.exif.gpsIfd.gpsLatitude, isNull);
    expect(
      () => preparePhoto(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
  });
}
