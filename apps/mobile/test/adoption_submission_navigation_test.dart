import 'dart:async';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/adoption/publication_screens.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'community_test.dart' show PhotoDraftCommunity;
import 'fake_identity_repository.dart';
import 'rescue_test.dart' show FakeRescue;

class SubmissionCommunity extends PhotoDraftCommunity {
  int saves = 0, submissions = 0;
  bool failTransition = false;
  String transitionStatus = 'submitted';
  Completer<void>? pendingTransition;

  @override
  Future<Adoption> save(Json payload, {String? id, int? version}) async {
    saves++;
    savedPayload = payload;
    if (failSave) throw StateError('offline');
    return post = Adoption({
      ...payload,
      'id': id ?? 'post',
      'owner_id': 'one',
      'version': (version ?? 0) + 1,
      'status': 'draft',
    });
  }

  @override
  Future<Adoption> transition(Adoption post, String action) async {
    if (action != 'submit') throw StateError('Unexpected transition: $action');
    submissions++;
    if (failTransition) throw StateError('review unavailable');
    if (pendingTransition != null) await pendingTransition!.future;
    return this.post = Adoption({
      ...post.data,
      'status': transitionStatus,
      'version': post.version + 1,
    });
  }
}

class SubmissionCases extends FakeRescue {
  SubmissionCases(this.community);
  final SubmissionCommunity community;
  final queries = <Json>[];

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
    final post = community.post;
    final included =
        program == 'adoption' &&
        !archived &&
        statuses.contains(post.status == 'submitted' ? 'review' : 'draft');
    return {
      'total_owned': 1,
      'total': included ? 1 : 0,
      'items': [
        if (included)
          {
            'id': post.id,
            'program': 'adoption',
            'status': post.status,
            'version': post.version,
            'pet_name': post.name,
            'cover_path': '',
            'record': post.data,
            'thread_count': 0,
            'unique_view_count': 0,
            'need_types': <String>[],
          },
      ],
    };
  }
}

Future<ProviderContainer> mountSubmission(
  WidgetTester tester,
  SubmissionCommunity community,
  SubmissionCases cases, {
  String path = '/my-adoptions/post',
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final identity = FakeIdentityRepository()
    ..user = const Identity('one', 'fixture@example.test', verified: true);
  await identity.setExperience('rescuer');
  final container = ProviderContainer(
    overrides: [
      identityRepositoryProvider.overrideWithValue(identity),
      communityRepositoryProvider.overrideWithValue(community),
      rescueRepositoryProvider.overrideWithValue(cases),
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

Future<void> tapSubmission(WidgetTester tester, Finder target) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> openSubmissionPreview(WidgetTester tester) async {
  await tapSubmission(tester, find.text('Continuar'));
  await tapSubmission(tester, find.text('Ir a vista previa'));
  expect(find.text('Valida tu caso'), findsOneWidget);
}

void expectReviewDestination(GoRouter router, SubmissionCases cases) {
  expect(router.state.uri.path, '/my-cases');
  expect(router.state.uri.queryParameters, {
    'program': 'adoption',
    'status': 'review',
  });
  expect(cases.queries.last, {
    'page': 1,
    'program': 'adoption',
    'statuses': ['review'],
    'archived': false,
  });
  expect(find.byType(PublicationScreen), findsNothing);
  expect(find.text('Luna'), findsOneWidget);
  expect(find.text('En revisión'), findsOneWidget);
  expect(find.text('Pendiente de aprobación'), findsOneWidget);
}

void main() {
  testWidgets(
    'confirmed adoption submission leaves the form after acknowledgement and ignores repeated taps while pending',
    (tester) async {
      final community = SubmissionCommunity()
        ..pendingTransition = Completer<void>();
      final cases = SubmissionCases(community);
      final container = await mountSubmission(tester, community, cases);
      final router = container.read(routerProvider);
      await openSubmissionPreview(tester);
      final submit = find.widgetWithText(FilledButton, 'Enviar a revisión');
      final position = tester.getCenter(submit);
      await tester.tap(submit);
      await tester.pump();
      await tester.tapAt(position);
      await tester.pump();

      expect(community.submissions, 1);
      expect(community.post.status, 'draft');
      expect(router.state.uri.path, '/my-adoptions/post');
      expect(find.byType(PublicationScreen), findsOneWidget);
      expect(find.text('Enviado a revisión'), findsNothing);
      expect(cases.queries, isEmpty);

      community.pendingTransition!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Enviado a revisión'), findsOneWidget);
      expect(router.state.uri.path, '/my-adoptions/post');
      await tapSubmission(tester, find.text('Entendido'));

      expectReviewDestination(router, cases);
      expect(community.submissions, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'submission resets a retained review destination after its archive filter changed',
    (tester) async {
      final community = SubmissionCommunity();
      final cases = SubmissionCases(community);
      final container = await mountSubmission(
        tester,
        community,
        cases,
        path: '/my-cases?program=adoption&status=review',
      );
      final router = container.read(routerProvider);
      await tapSubmission(tester, find.byTooltip('Ver archivo'));
      expect(cases.queries.last['archived'], isTrue);
      expect(find.text('No tienes casos archivados.'), findsOneWidget);
      final previousReads = cases.queries.length;

      unawaited(router.push('/my-adoptions/post'));
      await tester.pumpAndSettle();
      await openSubmissionPreview(tester);
      await tapSubmission(tester, find.text('Enviar a revisión'));
      await tapSubmission(tester, find.text('Entendido'));

      expectReviewDestination(router, cases);
      expect(cases.queries.length, greaterThan(previousReads));
      expect(find.text('No tienes casos archivados.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final failure in ['save', 'transition', 'unconfirmed status']) {
    testWidgets('submission $failure keeps the authored form available', (
      tester,
    ) async {
      final community = SubmissionCommunity();
      final cases = SubmissionCases(community);
      final container = await mountSubmission(tester, community, cases);
      await tester.enterText(
        find.byKey(const ValueKey('publication-field-pet_name')),
        'Luna corregida',
      );
      await openSubmissionPreview(tester);
      community.failSave = failure == 'save';
      community.failTransition = failure == 'transition';
      if (failure == 'unconfirmed status') community.transitionStatus = 'draft';
      await tapSubmission(tester, find.text('Enviar a revisión'));

      expect(
        container.read(routerProvider).state.uri.path,
        '/my-adoptions/post',
      );
      expect(find.byType(PublicationScreen), findsOneWidget);
      expect(find.text('Enviado a revisión'), findsNothing);
      expect(find.text('Valida tu caso'), findsOneWidget);
      expect(community.savedPayload?['pet_name'], 'Luna corregida');
      expect(community.submissions, failure == 'save' ? 0 : 1);
      expect(cases.queries, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('saving a draft keeps editing without sending it to review', (
    tester,
  ) async {
    final community = SubmissionCommunity();
    final cases = SubmissionCases(community);
    final container = await mountSubmission(tester, community, cases);
    await tester.enterText(
      find.byKey(const ValueKey('publication-field-pet_name')),
      'Luna corregida',
    );
    await tapSubmission(tester, find.text('Guardar borrador'));

    expect(container.read(routerProvider).state.uri.path, '/my-adoptions/post');
    expect(find.byType(PublicationScreen), findsOneWidget);
    expect(find.text('Enviado a revisión'), findsNothing);
    expect(community.post.name, 'Luna corregida');
    expect(community.post.status, 'draft');
    expect(community.saves, 1);
    expect(community.submissions, 0);
    expect(cases.queries, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
