import 'package:dopmi_mobile/features/rescue/rescue_screens.dart';
import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'fake_identity_repository.dart';
import 'community_test.dart' show FakeCommunity;
import 'rescue_test.dart' show FakeRescue;

import 'dart:ui' show PointerDeviceKind;

import 'package:dopmi_mobile/features/profile/rescuer_profile_activity.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class GuardianActivityRescue extends FakeRescue {
  @override
  Future<Json> dashboard() async => {
    ...await super.dashboard(),
    'financial': {
      'assigned_cents': 3314,
      'transferred_cents': 3314,
      'in_review_cents': 0,
    },
    'recent_activity': [
      {
        'source': 'guardian',
        'expense_id': 'expense-one',
        'expense_title': 'Medicamentos',
        'allocated_cents': 3314,
        'transfer_status': 'transferred',
      },
    ],
  };
  @override
  Future<Json> detail(String id) async => id == 'expense-one'
      ? {
          'record': {...expenseRecord.data, 'owner_id': 'one'},
          'expenses': <Json>[],
        }
      : super.detail(id);
}

void main() {
  testWidgets(
    'settled Guardian activity displays net and opens its actual expense',
    (tester) async {
      final identity = FakeIdentityRepository()
        ..user = const Identity('one', 'ana@example.test', verified: true);
      await identity.setExperience('rescuer');
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          communityRepositoryProvider.overrideWithValue(FakeCommunity()),
          rescueRepositoryProvider.overrideWithValue(GuardianActivityRescue()),
          routerInitialLocationProvider.overrideWithValue('/profile'),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await identity.changes.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DopmiApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining(r'$33.14 MXN asignados'), findsOneWidget);
      expect(find.text('Transferido a la cuenta Stripe'), findsOneWidget);
      final activity = find.byType(RescuerProfileActivityRow);
      await tester.ensureVisible(activity);
      await tester.pumpAndSettle();
      await tester.tap(activity);
      await tester.pumpAndSettle();
      final route = container.read(routerProvider).state.uri;
      expect(route.path, '/rescue/expense-one');
      expect(route.queryParameters, {'kind': 'expense', 'record': '1'});
      expect(find.byType(RescueEditorScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('activity home link opens the actual rescuer home by keyboard', (
    tester,
  ) async {
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'ana@example.test', verified: true);
    await identity.setExperience('rescuer');
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        communityRepositoryProvider.overrideWithValue(FakeCommunity()),
        rescueRepositoryProvider.overrideWithValue(FakeRescue()),
        routerInitialLocationProvider.overrideWithValue('/profile'),
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
    final link = find.byType(RescuerActivityHomeLink);
    await tester.ensureVisible(link);
    await tester.pumpAndSettle();
    final outline = find.descendant(
      of: link,
      matching: find.byKey(const ValueKey('reference-keyboard-outline')),
    );
    for (var i = 0; i < 12 && outline.evaluate().isEmpty; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
    }
    expect(outline, findsOneWidget);
    expect(container.read(routerProvider).state.uri.path, '/profile');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(container.read(routerProvider).state.uri.path, '/rescuer');
    expect(find.text('Acciones pendientes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final large in [false, true]) {
    testWidgets(
      'activity shows actual allocation states and expense IDs; large=$large',
      (tester) async {
        tester.view.physicalSize = const Size(640, 1704);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final opened = <String>[];
        var home = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                textScaler: TextScaler.linear(large ? 2 : 1),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: RescuerProfileActivity(
                    data: {
                      'verification_status': 'approved',
                      'recent_activity': [
                        for (var n = 0; n < 4; n++)
                          {
                            'expense_id': 'expense-$n',
                            'expense_title': 'Consulta veterinaria $n',
                            'allocated_cents': 5015,
                            'transfer_status': n == 0 ? 'pending' : 'reversed',
                          },
                      ],
                    },
                    onHome: () => home++,
                    onExpense: opened.add,
                    onStart: () => fail('must not fabricate an empty state'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(RescuerProfileActivityRow), findsNWidgets(3));
        expect(find.text('Transferencia en proceso'), findsOneWidget);
        expect(find.text('Transferencia revertida'), findsNWidgets(2));
        expect(find.textContaining(r'$50.15 MXN asignados'), findsNWidgets(3));
        expect(find.textContaining('Consulta veterinaria 3'), findsNothing);

        final link = find.byType(RescuerActivityHomeLink);
        expect(tester.getSize(link).height, 48);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(tester.getCenter(link));
        await tester.pump();
        expect(
          tester.widget<Text>(find.text('Ver inicio')).style!.decoration,
          TextDecoration.underline,
        );
        expect(home, 0);
        await mouse.moveTo(Offset.zero);
        await tester.pump();
        expect(
          tester.widget<Text>(find.text('Ver inicio')).style!.decoration,
          TextDecoration.none,
        );
        await mouse.removePointer();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        final outline = find.descendant(
          of: link,
          matching: find.byKey(const ValueKey('reference-keyboard-outline')),
        );
        expect(outline, findsOneWidget);
        expect(tester.getSize(outline).height, 54);
        expect(home, 0);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(home, 1);
        await tester.tap(find.text('Ver inicio'));
        await tester.ensureVisible(
          find.byType(RescuerProfileActivityRow).first,
        );
        await tester.tap(find.byType(RescuerProfileActivityRow).first);
        await tester.pumpAndSettle();
        expect(home, 2);
        expect(opened, ['expense-0']);
        final second = find.byType(RescuerProfileActivityRow).at(1);
        final rowOutline = find.descendant(
          of: second,
          matching: find.byKey(const ValueKey('reference-keyboard-outline')),
        );
        for (var i = 0; i < 8 && rowOutline.evaluate().isEmpty; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
        }
        expect(rowOutline, findsOneWidget);
        expect(tester.getRect(rowOutline), tester.getRect(second).inflate(5));
        expect(opened, ['expense-0']);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(opened, ['expense-0', 'expense-1']);

        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final approved in [false, true]) {
    testWidgets('empty activity offers real next step; approved=$approved', (
      tester,
    ) async {
      var starts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RescuerProfileActivity(
              data: {
                'verification_status': approved ? 'approved' : 'not_started',
                'recent_activity': const [],
              },
              onHome: () {},
              onExpense: (_) {},
              onStart: () => starts++,
            ),
          ),
        ),
      );
      expect(find.text('Ver inicio'), findsNothing);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.byType(FilledButton)));
      await tester.pump();
      final paintedButton = find.descendant(
        of: find.byType(FilledButton),
        matching: find.byType(Material),
      );
      expect(
        tester.widget<Material>(paintedButton).color,
        const Color(0xff6d28d9),
      );
      await mouse.moveTo(Offset.zero);
      await tester.pump();
      expect(
        tester.widget<Material>(paintedButton).color,
        const Color(0xff7841f2),
      );
      await mouse.removePointer();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final button = find.byType(FilledButton);
      final outline = find.byKey(const ValueKey('reference-keyboard-outline'));
      expect(outline, findsOneWidget);
      expect(tester.getRect(outline), tester.getRect(button).inflate(5));
      expect(starts, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(starts, 1);

      await tester.tap(
        find.text(approved ? 'Publicar caso' : 'Ir a verificación'),
      );
      await tester.pumpAndSettle();
      expect(starts, 2);
      expect(outline, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
