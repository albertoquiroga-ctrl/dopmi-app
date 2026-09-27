import 'dart:typed_data';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'fake_identity_repository.dart';

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
  final sentIds = <String>[];
  final stored = <String, Json>{};
  Json? savedPayload;
  Json? reported;
  @override
  String? get userId => 'one';
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
  Future<DataPage<SavedEntry>> savedAdoptions(int page) async => DataPage([
    SavedEntry({...post.data, 'available': true, 'saved': true}),
  ], 1);
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
  Future<DataPage<Json>> threads(int page, {String search = ''}) async =>
      const DataPage([], 0);

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

void main() {
  Future<ProviderContainer> start(
    WidgetTester tester,
    FakeCommunity repo,
    String path,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'ana@example.test', verified: true);
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        communityRepositoryProvider.overrideWithValue(repo),
        routerInitialLocationProvider.overrideWithValue(path),
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

  testWidgets(
    'catalog opens approved detail and persists a favorite at narrow width',
    (tester) async {
      final repo = FakeCommunity();
      await start(tester, repo, '/adoptions');
      await tester.tap(find.text('Luna'));
      await tester.pumpAndSettle();
      await tap(tester, 'Guardar');
      expect(repo.post.saved, true);
      expect(find.text('Guardada'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('failed detail favorite rolls the optimistic state back', (
    tester,
  ) async {
    final repo = FakeCommunity()..failFavorite = true;
    await start(tester, repo, '/adoptions/post');
    await tap(tester, 'Guardar');
    expect(repo.post.saved, false);
    expect(find.text('Guardar'), findsOneWidget);
    expect(find.textContaining('No pudimos completar'), findsOneWidget);
  });
  testWidgets('contact asks for confirmation before opening the thread', (
    tester,
  ) async {
    final repo = FakeCommunity();
    await start(tester, repo, '/adoptions/post');
    await tap(tester, 'Quiero conocerle');
    expect(find.text('¿Iniciamos el proceso?'), findsOneWidget);
    await tester.tap(find.text('Contactar'));
    await tester.pumpAndSettle();
    expect(find.text('Sobre Luna'), findsOneWidget);
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
    expect(find.text('25 % cubierto'), findsOneWidget);
    expect(find.text('Apoyar este gasto'), findsOneWidget);
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
  testWidgets('failed like keeps the card and exposes a retry', (tester) async {
    final repo = FakeCommunity()..failFavorite = true;
    await start(tester, repo, '/adoptions');
    await tester.tap(find.byTooltip('Me gusta'));
    await tester.pumpAndSettle();
    expect(find.text('Luna'), findsOneWidget);
    expect(find.text('Volver a intentar'), findsOneWidget);
    expect(repo.post.saved, false);
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
      final repo = FakeCommunity()..failSave = true;
      await start(tester, repo, '/my-adoptions/new');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre de la mascota'),
        'Mora',
      );
      await tap(tester, 'Guardar borrador');
      expect(repo.savedPayload!['pet_name'], 'Mora');
      expect(
        find.text(
          'No pudimos completar la solicitud. Comprueba tu conexión y vuelve a intentar.',
        ),
        findsWidgets,
      );
      repo.failSave = false;
      await tap(tester, 'Guardar borrador');
      expect(repo.post.name, 'Mora');
      expect(repo.post.status, 'draft');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'ambiguous message response retries with same id and removes private data on logout',
    (tester) async {
      final repo = FakeCommunity();
      final container = await start(tester, repo, '/messages/thread-one');
      await tester.enterText(
        find.byType(TextField),
        'Hola, quiero conocer a Luna.',
      );
      await tap(tester, 'Enviar mensaje');
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
