import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/rescue/case_update_repository.dart';

import 'package:dopmi_mobile/features/payments/payment_repository.dart';

import 'payments_test.dart' show FakePayments;

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';

import 'package:dopmi_mobile/features/rescue/owned_case_detail.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rescue_test.dart' show PhotoPublicCaseRescue, FakeCaseUpdates;

class OwnerDetailRescue extends PhotoPublicCaseRescue {
  OwnerDetailRescue(this.closed);
  final bool closed;
  @override
  Future<Json> detail(String id) async => {
    'record': {
      ...caseRecord.data,
      'id': id,
      'owner_id': 'one',
      'status': closed ? 'closed' : 'approved',
      'public_data': {
        ...caseRecord.publicData,
        'photos': ['one', 'two'],
      },
    },
    'history': <Json>[],
  };
}

void main() {
  testWidgets('owned summary matches measured reference content origin', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(377, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final record = RescueRecord({
      'id': 'case-one',
      'status': 'approved',
      'public_data': {
        'pet_name': 'Choco',
        'story': 'Historia real',
        'city': 'CDMX',
      },
    });
    final identity = FakeIdentityRepository();
    addTearDown(identity.changes.close);
    final router = GoRouter(
      initialLocation: '/rescue/case-one',
      routes: [
        GoRoute(
          path: '/rescue/:id',
          builder: (_, _) => OwnedCaseDetail(
            record: record,
            needs: const SizedBox(),
            updates: const SizedBox(),
            busy: false,
            onBack: () {},
            onRecord: () {},
            onRefresh: () {},
            onExpense: () {},
            onUpdates: () {},
            onClose: () {},
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [identityRepositoryProvider.overrideWithValue(identity)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    final title = tester.getRect(find.text('Choco'));
    // Source runtime553: summary x16/y276, content x33/y293.
    expect(title.left, 33);
    expect(title.top, 293);
    expect(tester.getRect(find.text('Historia real')).left, 33);
    // Source runtime553: location pill height27, padding5x9 + border1.
    final location = find
        .ancestor(of: find.text('CDMX'), matching: find.byType(Container))
        .first;
    expect(tester.getSize(location).height, 27);
    expect(tester.getRect(location).top, 294.5);
    expect(tester.takeException(), isNull);
  });

  for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.space]) {
    testWidgets('owner back opens real callback with ${key.keyLabel}', (
      tester,
    ) async {
      var backs = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OwnedCaseHero(
              record: RescueRecord({
                'id': 'one',
                'public_data': {'photos': <String>[]},
              }),
              onBack: () => backs++,
            ),
          ),
        ),
      );
      final back = find.byKey(const ValueKey('owned-case-back'));
      expect(tester.getSize(back), const Size(48, 48));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      Focus.of(
        tester.element(
          find
              .descendant(of: back, matching: find.byType(GestureDetector))
              .first,
        ),
      ).requestFocus();
      await tester.pump();
      expect(backs, 0);
      final outline = find.byKey(const ValueKey('reference-keyboard-outline'));
      expect(outline, findsOneWidget);
      expect(tester.getSize(outline), const Size(50, 50));
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
      expect(backs, 1);
      expect(tester.takeException(), isNull);
    });
  }

  for (final closed in [false, true]) {
    testWidgets(
      'owner case consultation returns to the same gallery; closed=$closed',
      (tester) async {
        final semanticHandle = tester.ensureSemantics();
        final identity = FakeIdentityRepository()
          ..user = const Identity(
            'one',
            'fixture@example.test',
            verified: true,
          );
        identity.profile = const Profile(
          id: 'one',
          name: 'Ana',
          phone: '',
          city: '',
          mode: 'rescuer',
          intent: 'rescue',
          status: 'active',
          termsVersion: currentTermsVersion,
          privacyVersion: currentPrivacyVersion,
          adultConfirmed: true,
        );
        final container = ProviderContainer(
          overrides: [
            identityRepositoryProvider.overrideWithValue(identity),
            communityRepositoryProvider.overrideWithValue(FakeCommunity()),
            rescueRepositoryProvider.overrideWithValue(
              OwnerDetailRescue(closed),
            ),
            caseUpdateRepositoryProvider.overrideWithValue(FakeCaseUpdates()),
            paymentRepositoryProvider.overrideWithValue(FakePayments()),
            routerInitialLocationProvider.overrideWithValue('/rescue/case-one'),
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
        expect(find.byType(OwnedCaseDetail), findsOneWidget);
        expect(
          tester.getSemantics(find.bySemanticsLabel('Casos')),
          matchesSemantics(
            label: 'Casos',
            isButton: true,
            isSelected: true,
            hasSelectedState: true,
            hasTapAction: true,
          ),
        );
        expect(
          find.text('Registrar gasto realizado'),
          closed ? findsNothing : findsOneWidget,
        );
        expect(
          find.text('Cerrar caso'),
          closed ? findsNothing : findsOneWidget,
        );
        final rect = tester.getRect(
          find.byKey(const ValueKey('owned-case-photo-selector')),
        );
        await tester.tapAt(Offset(rect.right - 8, rect.center.dy));
        await tester.pumpAndSettle();
        expect(find.text('2 / 2'), findsOneWidget);
        await tester.ensureVisible(find.text('Consultar expediente'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Consultar expediente'));
        await tester.pumpAndSettle();
        expect(find.text('Volver al caso'), findsOneWidget);
        await tester.tap(find.text('Volver al caso'));
        await tester.pumpAndSettle();
        expect(find.byType(OwnedCaseDetail), findsOneWidget);
        expect(find.text('2 / 2'), findsOneWidget);
        expect(tester.takeException(), isNull);
        semanticHandle.dispose();
      },
    );
  }

  testWidgets(
    'owner gallery Tab Enter Space and touch select photos; swipe and changed record reset correctly',
    (tester) async {
      final rescue = PhotoPublicCaseRescue();
      var record = RescueRecord({
        'id': 'owner-one',
        'public_data': {
          'pet_name': 'Luna',
          'photos': ['one', 'two', 'three'],
        },
      });
      Future<void> show() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [rescueRepositoryProvider.overrideWithValue(rescue)],
            child: MaterialApp(
              home: Scaffold(
                body: OwnedCaseHero(record: record, onBack: () {}),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await show();
      expect(find.text('1 / 3'), findsOneWidget);
      final firstDot = find.byKey(const ValueKey('owned-case-photo-0'));
      Focus.of(
        tester.element(
          find
              .descendant(of: firstDot, matching: find.byType(GestureDetector))
              .first,
        ),
      ).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final dotOutline = find.byKey(
        const ValueKey('reference-keyboard-outline'),
      );
      expect(dotOutline, findsOneWidget);
      expect(tester.getSize(dotOutline), const Size(18, 18));
      expect(find.text('1 / 3'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.text('3 / 3'), findsOneWidget);
      await tester.tap(firstDot);
      await tester.pumpAndSettle();
      expect(find.text('1 / 3'), findsOneWidget);
      final selector = find.byKey(const ValueKey('owned-case-photo-selector'));
      final rect = tester.getRect(selector);
      await tester.tapAt(Offset(rect.right - 8, rect.center.dy));
      await tester.pumpAndSettle();
      expect(find.text('3 / 3'), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(500, 0));
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
      record = RescueRecord({
        'id': 'owner-two',
        'public_data': {
          'pet_name': 'Milo',
          'photos': ['one', 'two'],
        },
      });
      await show();
      expect(find.text('1 / 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
