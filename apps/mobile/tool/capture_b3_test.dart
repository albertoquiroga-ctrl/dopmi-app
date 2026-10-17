// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/core/media/photo_runtime.dart';
import 'package:dopmi_mobile/core/media/photo_store.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/payments/guardian_repository.dart';
import 'package:dopmi_mobile/features/profile/account_photo_repository.dart';
import 'package:dopmi_mobile/features/profile/impact_photo_journey.dart';
import 'package:dopmi_mobile/features/profile/monthly_impact_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_public_photo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/community_test.dart' show FakeCommunity;
import '../test/fake_account_photo_repository.dart';
import '../test/fake_identity_repository.dart';
import '../test/guardian_registration_screen_test.dart' show registration;
import '../test/monthly_impact_test.dart' show FakeMonthlyImpact;
import '../test/support_membership_test.dart'
    show MembershipGuardian, MembershipRescue;
import 'capture_design_test.dart' show saveCapture;

class CaptureImpactCommunity extends FakeCommunity {
  @override
  Future<List<Json>> personalImpact() async => [
    for (final entry in [('case-one', 'Luna'), ('case-two', 'Milo')])
      {
        'case_id': entry.$1,
        'public_data': {
          'pet_name': entry.$2,
          'photos': ['synthetic/${entry.$1}.png'],
        },
        'allocated_cents': 4600,
        'updates': <Json>[],
      },
  ];
}

class CaptureImpactRescue extends MembershipRescue {
  @override
  Future<String> fileUrl(String path) async => 'https://fixture.invalid/$path';
}

// All identities, amounts, counts, photos and provider responses here are test
// fixtures. No socket, processor operation or real user action is performed.
void main() {
  for (final scale in [1.0, 1.15, 2.0]) {
    for (final state in ['registered', 'discovery', 'error']) {
      testWidgets('B3 actual route $state scale=$scale', (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = scale == 2
            ? const Size(320, 640)
            : const Size(377, 852);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        for (final family in ['Inter', 'Fraunces', 'MaterialIcons']) {
          final loader = FontLoader(family)
            ..addFont(
              rootBundle.load(
                family == 'MaterialIcons'
                    ? 'fonts/MaterialIcons-Regular.otf'
                    : 'assets/fonts/$family.ttf',
              ),
            );
          await tester.runAsync(loader.load);
        }
        final photo = await tester.runAsync(
          () => File('tool/fixtures/milo.png').readAsBytes(),
        );
        final identity = FakeIdentityRepository()
          ..user = const Identity(
            'one',
            'fixture@example.test',
            verified: true,
          );
        final guardian = MembershipGuardian()
          ..membership = state == 'discovery'
              ? {}
              : {
                  'registration': registration(
                    '72000000-0000-4000-8000-000000000002',
                    status: 'registered',
                  ),
                };
        final rescue = CaptureImpactRescue();
        final monthly = FakeMonthlyImpact()..fail = state == 'error';
        final container = ProviderContainer(
          overrides: [
            identityRepositoryProvider.overrideWithValue(identity),
            accountPhotoRepositoryProvider.overrideWithValue(
              emptyAccountPhotoRepository(identity),
            ),
            communityRepositoryProvider.overrideWithValue(
              CaptureImpactCommunity(),
            ),
            rescueRepositoryProvider.overrideWithValue(rescue),
            guardianRepositoryProvider.overrideWithValue(guardian),
            guardianEnabledProvider.overrideWithValue(true),
            monthlyImpactRepositoryProvider.overrideWithValue(monthly),
            routerInitialLocationProvider.overrideWithValue('/rescue-cases'),
            photoRuntimeProvider.overrideWith((ref) {
              final runtime = PhotoRuntime(
                store: MemoryPhotoStore(),
                actor: 'one',
                download: (_, _) async => photo!,
              );
              ref.onDispose(runtime.dispose);
              return runtime;
            }),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await identity.changes.close();
        });
        // Decode the fixture in real async time before any loading spinner can
        // advance the synthetic test clock to its network timeout.
        final runtime = container.read(photoRuntimeProvider);
        for (final id in ['case-one', 'case-two']) {
          await tester.runAsync(
            () => runtime.load(
              rescuePhotoSource(rescue, 'synthetic/$id.png'),
              width: 384,
            ),
          );
        }
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: UncontrolledProviderScope(
              container: container,
              child: const DopmiApp(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
        });
        await tester.pumpAndSettle();
        final output = Directory('../../.tools/b3-visual-20261017');
        await tester.runAsync(() => output.create(recursive: true));
        final prefix = '${output.path}/$state-$scale';
        await tester.runAsync(() => saveCapture(key, '$prefix-top.png'));
        final scrollable = find.byType(Scrollable).first;
        if (state == 'registered') {
          expect(rescue.catalogReads, 0);
          expect(
            find.byTooltip('Foto no disponible. Reintentar foto'),
            findsNothing,
          );
          final hero = find.byKey(const ValueKey('impact-hero-case-one'));
          final ring = find.byKey(const ValueKey('impact-ring-case-one'));
          final gap = tester.getCenter(hero).dy - tester.getCenter(ring).dy;
          final stageTop = tester
              .getTopLeft(find.byType(ImpactPhotoJourney))
              .dy;
          final position = tester.state<ScrollableState>(scrollable).position;
          position.jumpTo(stageTop + gap / 2);
          await tester.pump();
          expect(
            find.byKey(const ValueKey('impact-photo-flight')),
            findsOneWidget,
          );
          final flight = find.byKey(const ValueKey('impact-photo-flight'));
          final flightRect = tester.getRect(flight);
          // The flight mounts a photo at a new decode size. Let real decoding
          // finish while keeping the presentation's scroll position fixed.
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 60));
          });
          await tester.pumpAndSettle();
          expect(tester.getRect(flight), flightRect);
          expect(
            find.descendant(of: flight, matching: find.byType(RawImage)),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: flight,
              matching: find.byType(CircularProgressIndicator),
            ),
            findsNothing,
          );
          await tester.runAsync(() => saveCapture(key, '$prefix-flight.png'));
        } else if (state == 'discovery') {
          final deck = find.byKey(const ValueKey('guardian-support-carousel'));
          await tester.ensureVisible(deck);
          await tester.pumpAndSettle();
          final point = tester.getTopLeft(deck) + const Offset(150, 100);
          expect(
            point.dy,
            inInclusiveRange(0, tester.view.physicalSize.height),
          );
          await tester.dragFrom(point, const Offset(-350, 0));
          await tester.pump(const Duration(milliseconds: 140));
          await tester.runAsync(
            () => saveCapture(key, '$prefix-deck-140ms.png'),
          );
          await tester.pumpAndSettle();
        }
        for (var step = 0; step < 30; step++) {
          await tester.drag(scrollable, const Offset(0, -500));
          await tester.pumpAndSettle();
          if (tester.state<ScrollableState>(scrollable).position.extentAfter <
              .5)
            break;
        }
        final position = tester.state<ScrollableState>(scrollable).position;
        expect(position.extentAfter, lessThan(.5));
        await tester.runAsync(() => saveCapture(key, '$prefix-end.png'));
        expect(guardian.calls, isEmpty);
        expect(guardian.opened, 0);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
