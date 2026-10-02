import 'dart:async';

import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/rescue/case_update_repository.dart';
import 'package:dopmi_mobile/features/rescue/owned_case_history.dart';
import 'package:dopmi_mobile/features/rescue/case_update_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'rescue_test.dart' show FakeCaseUpdates;

class StoryFixture extends FakeCaseUpdates {
  bool fail = false;
  int publicCalls = 0, photoCalls = 0;
  @override
  Future<List<CaseUpdate>> publicFor(String caseId) async {
    publicCalls++;
    if (fail) throw const FormatException('La historia no está disponible.');
    return [
      CaseUpdate({
        'id': 'published-one',
        'body': 'Avance aprobado del rescate',
        'photos': ['approved-only'],
        'published_at': '2026-10-01T16:00:00Z',
      }),
    ];
  }

  @override
  Future<List<CaseUpdate>> mine(String caseId) =>
      throw StateError('Private drafts must not enter public history');
  @override
  Future<String> photoUrl(String path) async {
    photoCalls++;
    throw const FormatException('Offline photo');
  }
}

class PendingStoryPhoto extends StoryFixture {
  final retry = Completer<String>();
  @override
  Future<String> photoUrl(String path) {
    photoCalls++;
    if (photoCalls == 1) return Future.error(const FormatException('Offline'));
    return retry.future;
  }
}

class PendingStoryHistory extends StoryFixture {
  final initial = Completer<List<CaseUpdate>>();
  @override
  Future<List<CaseUpdate>> publicFor(String caseId) {
    if (publicCalls == 0) {
      publicCalls++;
      return initial.future;
    }
    return super.publicFor(caseId);
  }
}

void main() {
  testWidgets(
    'history heading stays visible through pending, error and retry',
    (tester) async {
      final updates = PendingStoryHistory();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            caseUpdateRepositoryProvider.overrideWithValue(updates),
            communityRepositoryProvider.overrideWithValue(FakeCommunity()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: PublicCaseUpdates('case-one')),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('La historia hasta ahora'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining('Los avances aprobados'), findsNothing);
      updates.initial.completeError(const FormatException('Offline'));
      await tester.pumpAndSettle();
      expect(find.text('La historia hasta ahora'), findsOneWidget);
      expect(find.textContaining('Los avances aprobados'), findsNothing);
      await tester.tap(find.text('Volver a intentar'));
      await tester.pumpAndSettle();
      expect(updates.publicCalls, 2);
      expect(find.text('La historia hasta ahora'), findsOneWidget);
      expect(find.text('Avance aprobado del rescate'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('photo retry replaces the old error while signing is pending', (
    tester,
  ) async {
    final updates = PendingStoryPhoto();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [caseUpdateRepositoryProvider.overrideWithValue(updates)],
        child: const MaterialApp(
          home: Scaffold(body: OwnedStoryPhoto('approved-only')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reintentar foto'), findsOneWidget);
    await tester.tap(find.text('Reintentar foto'));
    await tester.pump();
    expect(updates.photoCalls, 2);
    expect(find.text('Reintentar foto'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.getSize(find.byType(OwnedStoryPhoto)).height, 160);
    updates.retry.completeError(const FormatException('Still offline'));
    await tester.pumpAndSettle();
    expect(find.text('Reintentar foto'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'public history shares approved cards and recovers failed photos',
    (tester) async {
      final updates = StoryFixture();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            caseUpdateRepositoryProvider.overrideWithValue(updates),
            communityRepositoryProvider.overrideWithValue(FakeCommunity()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: PublicCaseUpdates('case-one')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('La historia hasta ahora'), findsOneWidget);
      expect(find.text('Avance aprobado del rescate'), findsOneWidget);
      expect(updates.publicCalls, 1);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.getSize(find.byType(OwnedStoryPhoto)).height, 160);
      await tester.tap(find.text('Reintentar foto'));
      await tester.pumpAndSettle();
      expect(updates.photoCalls, 2);
      expect(tester.getSize(find.byType(OwnedStoryPhoto)).height, 160);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'owner history uses approved projection and retry keeps photo geometry',
    (tester) async {
      final updates = StoryFixture();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            caseUpdateRepositoryProvider.overrideWithValue(updates),
            communityRepositoryProvider.overrideWithValue(FakeCommunity()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: OwnedCaseHistory('case-one')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Avance aprobado del rescate'), findsOneWidget);
      expect(updates.publicCalls, 1);
      expect(tester.getSize(find.byType(OwnedStoryPhoto)).height, 160);
      await tester.tap(find.text('Reintentar foto'));
      await tester.pumpAndSettle();
      expect(updates.photoCalls, 2);
      expect(tester.getSize(find.byType(OwnedStoryPhoto)).height, 160);
      expect(tester.takeException(), isNull);
      updates.fail = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Avance aprobado del rescate'), findsNothing);
      expect(
        find.text('Los avances aprobados del rescate aparecerán aquí.'),
        findsNothing,
      );
      expect(find.text('Volver a intentar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('long approved story date and copy reflow at 320px and 200%', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 1704);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final story = CaseUpdate({
      'id': 'one',
      'body': 'El caso continúa con los cuidados indicados por el equipo veterinario.',
      'published_at': '2026-10-01T16:00:00Z',
    });
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(child: OwnedCaseStory(story)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('El caso continúa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
