import 'dart:ui' show PointerDeviceKind;

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/communication/rescuer_threads_screen.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'rescue_test.dart' show FakeRescue;

void main() {
  Future<ProviderContainer> start(
    WidgetTester tester,
    FakeCommunity repo,
    bool large,
  ) async {
    tester.view.physicalSize = large
        ? const Size(320, 640)
        : const Size(384, 852);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = large ? 2 : 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'fixture@example.test', verified: true);
    await identity.setExperience('rescuer');
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        communityRepositoryProvider.overrideWithValue(repo),
        rescueRepositoryProvider.overrideWithValue(FakeRescue()),
        routerInitialLocationProvider.overrideWithValue('/messages'),
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

  for (final large in [false, true]) {
    testWidgets('rescuer empty inbox opens actual publication; large=$large', (
      tester,
    ) async {
      final container = await start(
        tester,
        FakeCommunity()..threadItems = [],
        large,
      );
      expect(find.byType(RescuerThreadsScreen), findsOneWidget);
      expect(find.text('Mis match'), findsNothing);
      expect(find.text('Mis favoritos'), findsNothing);
      expect(find.text('Habla con adoptantes'), findsOneWidget);
      expect(find.text('No tienes mensajes'), findsOneWidget);
      final button = find.widgetWithText(FilledButton, 'Publicar caso');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(container.read(routerProvider).state.uri.path, '/publish');
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'rescuer inbox preserves unread, closed state and keyboard destination; large=$large',
      (tester) async {
        final repo = FakeCommunity()
          ..threadItems = [
            {
              'id': 'thread-one',
              'participant_name': 'Ana',
              'pet_name': 'Luna',
              'unread_count': 3,
              'last_message': 'Hola Luna',
              'status': 'active',
            },
            {
              'id': 'thread-two',
              'participant_name': 'Carlos',
              'pet_name': 'Milo',
              'unread_count': 0,
              'last_message': 'Private old preview',
              'status': 'closed',
            },
          ];
        final container = await start(tester, repo, large);
        expect(find.text('Hola Luna'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(find.text('Sobre Luna'), findsOneWidget);
        expect(find.text('Conversación cerrada'), findsOneWidget);
        expect(find.text('Private old preview'), findsNothing);
        final row = find.byType(RescuerThreadRow).first;
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(tester.getCenter(row));
        await tester.pump();
        final material = find.descendant(
          of: row,
          matching: find.byType(Material),
        );
        expect(
          tester.widget<Material>(material).color,
          const Color(0xfffbfaff),
        );
        expect(container.read(routerProvider).state.uri.path, '/messages');
        await mouse.moveTo(Offset.zero);
        await mouse.removePointer();
        await tester.pump();
        final outline = find.descendant(
          of: row,
          matching: find.byKey(const ValueKey('reference-keyboard-outline')),
        );
        for (var i = 0; i < 12 && outline.evaluate().isEmpty; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
        }
        expect(outline, findsOneWidget);
        expect(container.read(routerProvider).state.uri.path, '/messages');
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(
          container.read(routerProvider).state.uri.path,
          '/messages/thread-one',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
