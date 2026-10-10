import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';

class SearchCommunity extends FakeCommunity {
  SearchCommunity() {
    savedItems = [];
    threadItems = [
      {
        'id': 'luna',
        'pet_name': 'Luna',
        'participant_name': 'Ana',
        'last_message': 'Mensaje de Luna',
      },
      {
        'id': 'milo',
        'pet_name': 'Milo',
        'participant_name': 'Patricia',
        'last_message': 'Mensaje de Milo',
      },
    ];
  }
  final queries = <String>[];
  @override
  Future<DataPage<Json>> threads(int page, {String search = ''}) async {
    queries.add(search);
    final items = threadItems
        .where(
          (item) => '${item['pet_name']} ${item['participant_name']}'
              .toLowerCase()
              .contains(search.toLowerCase()),
        )
        .toList();
    return DataPage(items, items.length);
  }
}

void main() {
  for (final large in [false, true]) {
    testWidgets(
      'opening, clearing and closing thread search preserves the actual query flow; large=$large',
      (tester) async {
        tester.view.physicalSize = large
            ? const Size(320, 640)
            : const Size(384, 852);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = large ? 2 : 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final identity = FakeIdentityRepository()
          ..user = const Identity(
            'one',
            'fixture@example.test',
            verified: true,
          );
        final repo = SearchCommunity();
        final container = ProviderContainer(
          overrides: [
            identityRepositoryProvider.overrideWithValue(identity),
            communityRepositoryProvider.overrideWithValue(repo),
            routerInitialLocationProvider.overrideWithValue('/messages'),
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
        expect(find.byType(TextField), findsNothing);
        final open = find.byTooltip('Buscar conversaciones');
        await tester.scrollUntilVisible(
          open,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(tester.element(open), alignment: .3);
        await tester.pumpAndSettle();
        await tester.tap(open);
        await tester.pumpAndSettle();
        final field = find.byType(TextField);
        await tester.scrollUntilVisible(
          field,
          -200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(field);
        expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
        await tester.enterText(field, ' Luna ');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        expect(repo.queries.last, 'Luna');
        await tester.scrollUntilVisible(
          find.text('Mensaje de Luna'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.text('Mensaje de Luna'), findsOneWidget);
        expect(find.text('Mensaje de Milo'), findsNothing);
        await tester.ensureVisible(find.byTooltip('Limpiar búsqueda'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Limpiar búsqueda'));
        await tester.pumpAndSettle();
        expect(repo.queries.last, '');
        await tester.scrollUntilVisible(
          find.text('Mensaje de Milo'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.text('Mensaje de Milo'), findsOneWidget);
        await tester.scrollUntilVisible(
          field,
          -200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(field).focusNode!.hasFocus, isFalse);
        await tester.enterText(field, 'Ana');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byTooltip('Cerrar b\u00fasqueda'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(find.byTooltip('Cerrar b\u00fasqueda'));
        await tester.tap(find.byTooltip('Cerrar búsqueda'));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNothing);
        expect(repo.queries.last, '');
        await tester.scrollUntilVisible(
          find.text('Mensaje de Milo'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.text('Mensaje de Milo'), findsOneWidget);
        expect(container.read(routerProvider).state.uri.path, '/messages');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
