import 'package:dopmi_mobile/features/adoption/community_ui.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/store/store_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fake_identity_repository.dart';
import 'store_screen_test.dart' show StoreFake;

void main() {
  testWidgets(
    'real community navigation labels private preview and removes it on account change',
    (tester) async {
      final repository = StoreFake()
        ..preview = true
        ..externalLinksEnabled = false
        ..expiresAt = DateTime.now().add(const Duration(hours: 1));
      final identity = FakeIdentityRepository();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const Scaffold(bottomNavigationBar: CommunityNav(0)),
          ),
        ],
      );
      addTearDown(router.dispose);
      addTearDown(repository.changes.close);
      addTearDown(identity.changes.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            identityRepositoryProvider.overrideWithValue(identity),
            storeRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Vista previa de Tienda'), findsOneWidget);
      expect(find.bySemanticsLabel('Tienda'), findsNothing);
      repository.enabled = false;
      repository.switchActor('ordinary');
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Vista previa de Tienda'), findsNothing);
      expect(find.bySemanticsLabel('Tienda'), findsNothing);
      expect(find.bySemanticsLabel('Adoptar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
