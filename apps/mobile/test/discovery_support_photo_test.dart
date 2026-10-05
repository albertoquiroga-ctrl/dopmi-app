import 'dart:typed_data';

import 'package:dopmi_mobile/core/media/photo_runtime.dart';
import 'package:dopmi_mobile/core/media/photo_store.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_ui.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/rescue/rescue_public_photo.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'community_test.dart' show FakeCommunity;
import 'rescue_test.dart' show FakeRescue;
import 'fake_identity_repository.dart';

class RescueCardRepository extends FakeRescue {
  final signed = <String>[];
  @override
  Future<String> fileUrl(String path) async {
    signed.add(path);
    return 'https://fixture.test/rescue';
  }
}

class AdoptionCardRepository extends FakeCommunity {
  final signed = <String>[];
  @override
  Future<String> photoUrl(String path) async {
    signed.add(path);
    throw StateError('A rescue path must never use the adoption bucket');
  }
}

void main() {
  testWidgets(
    'support cover prefetch and presentation use the authorized rescue source',
    (tester) async {
      tester.view.physicalSize = const Size(377, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final identity = FakeIdentityRepository()
        ..user = const Identity(
          'one',
          'synthetic@example.test',
          verified: true,
        );
      addTearDown(identity.changes.close);
      final repo = AdoptionCardRepository();
      repo.discoveryItems = [
        Adoption({...repo.post.data, 'photos': <String>[]}),
        Adoption({...repo.post.data, 'id': 'second', 'photos': <String>[]}),
      ];
      repo.supportItems = [
        SupportOpportunity({
          'case_id': 'case-one',
          'expense_id': 'expense-one',
          'pet_name': 'DEMO',
          'expense_title': 'Tratamiento',
          'photo': 'approved/rescue.jpg',
          'reimbursable_cents': 10000,
          'funded_cents': 2500,
        }),
      ];
      final rescue = RescueCardRepository();
      final store = MemoryPhotoStore();
      final bytes = Uint8List.fromList(
        img.encodeJpg(img.Image(width: 20, height: 24)),
      );
      final runtime = (await tester.runAsync(
        () async => PhotoRuntime(store: store, download: (_, _) async => bytes),
      ))!;
      addTearDown(runtime.dispose);
      await tester.runAsync(() async {
        for (final width in [384]) {
          await runtime.load(
            rescuePhotoSource(rescue, 'approved/rescue.jpg'),
            width: width,
          );
        }
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              identityRepositoryProvider.overrideWithValue(identity),
              routerInitialLocationProvider.overrideWithValue('/adoptions'),
              communityRepositoryProvider.overrideWithValue(repo),
              rescueRepositoryProvider.overrideWithValue(rescue),
              photoRuntimeProvider.overrideWithValue(runtime),
            ],
            child: const DopmiApp(),
          ),
        );
      });
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => runtime.load(
          rescuePhotoSource(rescue, 'approved/rescue.jpg'),
          width: 384,
        ),
      );
      await tester.tap(find.byTooltip('Pasar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Pasar'));
      await tester.pumpAndSettle();
      expect(find.text('DEMO'), findsOneWidget);
      final cover = find.byWidgetPredicate(
        (w) => w is AdoptionPhoto && w.path == 'approved/rescue.jpg',
      );
      expect(
        tester
            .widget<RawImage>(
              find.descendant(of: cover, matching: find.byType(RawImage)),
            )
            .image,
        isNotNull,
      );
      expect(rescue.signed, ['approved/rescue.jpg']);
      expect(repo.signed, isEmpty);
      expect(runtime.metrics.downloads, 1);
      expect(store.entries, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
}
