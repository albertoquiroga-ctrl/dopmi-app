import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/communication/rescuer_threads_screen.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart'
    show FakeCommunity, PagedSavedCommunity, SavedRescuerCommunity;
import 'fake_identity_repository.dart';
import 'rescue_test.dart' show FakeRescue;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final family in ['Inter', 'Fraunces']) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/$family.ttf'))).load();
    }
  });

  Future<ProviderContainer> open(
    WidgetTester tester,
    FakeCommunity repository,
    String route, {
    bool rescuer = false,
  }) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'fixture@example.test', verified: true);
    if (rescuer) await identity.setExperience('rescuer');
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        communityRepositoryProvider.overrideWithValue(repository),
        rescueRepositoryProvider.overrideWithValue(FakeRescue()),
        routerInitialLocationProvider.overrideWithValue(route),
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

  void expectWholeWord(WidgetTester tester, String title, String word) {
    final paragraph = tester.renderObject<RenderParagraph>(find.text(title));
    final start = title.indexOf(word);
    expect(start, greaterThanOrEqualTo(0));
    expect(
      paragraph.getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: start + word.length),
      ),
      hasLength(1),
      reason: '$word should fit on one line with the bundled Inter font',
    );
  }

  testWidgets('enlarged favorites header and more action remain separate', (
    tester,
  ) async {
    await open(tester, FakeCommunity(), '/messages');
    final heading = tester.getRect(find.text('Mis favoritos'));
    final action = find.widgetWithText(TextButton, 'Ver más');
    final button = tester.getRect(action);
    final label = tester.getRect(find.text('Ver más'));
    expect(button.top, greaterThan(heading.bottom));
    expect(label.top, greaterThanOrEqualTo(button.top + 7));
    expect(label.bottom, lessThanOrEqualTo(button.bottom - 7));
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.text('Ordenar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'enlarged adoption CTA centers both lines with readable margins',
    (tester) async {
      await open(tester, FakeCommunity(), '/adoptions/post');
      final label = find.text('Quiero adoptar');
      final action = find.widgetWithText(FilledButton, 'Quiero adoptar');
      final button = tester.getRect(action);
      final labelRect = tester.getRect(label);
      expect(labelRect.top, greaterThanOrEqualTo(button.top + 11.9));
      expect(labelRect.bottom, lessThanOrEqualTo(button.bottom - 11.9));
      final paragraph = tester.renderObject<RenderParagraph>(label);
      for (final selection in const [
        TextSelection(baseOffset: 0, extentOffset: 6),
        TextSelection(baseOffset: 7, extentOffset: 14),
      ]) {
        final boxes = paragraph.getBoxesForSelection(selection);
        expect(boxes, hasLength(1));
        expect(
          paragraph.localToGlobal(boxes.single.toRect().center).dx,
          closeTo(button.center.dx, 1),
        );
      }
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.text('¿Iniciamos el proceso?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('enlarged saved rows preserve words and withdrawn privacy', (
    tester,
  ) async {
    await open(tester, PagedSavedCommunity(), '/saved');
    expectWholeWord(tester, 'Guardado 1', 'Guardado');
    await open(tester, SavedRescuerCommunity(), '/saved?kind=rescuer');
    expect(
      find.byKey(const ValueKey('saved-rescuer-title-icon')),
      findsOneWidget,
    );
    expectWholeWord(tester, 'Contenido no disponible', 'Contenido');
    expectWholeWord(tester, 'Contenido no disponible', 'disponible');
    expect(find.text('Nombre privado'), findsNothing);
    expect(find.text('8 casos publicados'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('enlarged rescuer inbox preserves full name and unread action', (
    tester,
  ) async {
    final repository = FakeCommunity()
      ..threadItems = [
        {
          'id': 'thread-one',
          'participant_name': 'Ana Patricia Hernandez',
          'pet_name': 'Luna',
          'updated_at': '2025-09-30T18:30:00Z',
          'last_message': 'Hola Luna',
          'unread_count': 3,
          'status': 'active',
        },
      ];
    final container = await open(
      tester,
      repository,
      '/messages',
      rescuer: true,
    );
    expectWholeWord(tester, 'Ana Patricia Hernandez', 'Hernandez');
    expect(find.text('3'), findsOneWidget);
    final row = find.byType(RescuerThreadRow).first;
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(
      container.read(routerProvider).state.uri.path,
      '/messages/thread-one',
    );
    expect(tester.takeException(), isNull);
  });
}
