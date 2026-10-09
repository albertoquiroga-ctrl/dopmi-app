import 'dart:async';
import 'dart:typed_data';

import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_edit_screen.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_repository.dart';
import 'package:dopmi_mobile/features/profile/phone_verification_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import 'fake_identity_repository.dart';
import 'rescuer_profile_test.dart' show FakeRescuerProfile;
import 'profile_dde1_test.dart' show FakePhoneDde;

void main() {
  for (final spec in [
    (const Size(377, 852), 1.0),
    (const Size(320, 640), 2.0),
  ]) {
    testWidgets(
      'visible photo Editar selects image and cancellation preserves preview at ${spec.$1.width}/${spec.$2}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = spec.$1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final identity = FakeIdentityRepository()
          ..user = const Identity(
            'owner-one',
            'qa@example.test',
            verified: true,
          );
        addTearDown(identity.changes.close);
        final pending = Completer<XFile?>();
        var calls = 0;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              identityRepositoryProvider.overrideWithValue(identity),
              rescuerProfileRepositoryProvider.overrideWithValue(
                FakeRescuerProfile(),
              ),
              phoneVerificationRepositoryProvider.overrideWithValue(
                FakePhoneDde(),
              ),
              publicProfilePhotoPickerProvider.overrideWithValue(() {
                calls++;
                return calls == 1 ? pending.future : Future.value(null);
              }),
            ],
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(spec.$2)),
                child: child!,
              ),
              home: const RescuerPublicProfileEditScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final edit = find.byKey(const ValueKey('public-profile-edit-photo'));
        await tester.scrollUntilVisible(
          edit,
          120,
          scrollable: find
              .byWidgetPredicate(
                (widget) =>
                    widget is Scrollable &&
                    widget.axisDirection == AxisDirection.down,
              )
              .first,
        );
        await tester.ensureVisible(edit);
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: edit, matching: find.text('Editar')),
          findsOneWidget,
        );
        expect(tester.widget<OutlinedButton>(edit).onPressed, isNotNull);
        expect(edit.hitTestable(), findsOneWidget);
        await tester.tap(edit);
        await tester.pump();
        expect(calls, 1);
        expect(tester.widget<OutlinedButton>(edit).onPressed, isNull);
        pending.complete(
          XFile.fromData(
            Uint8List.fromList(img.encodePng(img.Image(width: 8, height: 8))),
            name: 'photo.png',
          ),
        );
        await tester.pumpAndSettle();
        final avatar = find.descendant(
          of: find.byKey(const ValueKey('public-profile-photo')),
          matching: find.byType(CircleAvatar),
        );
        final preview = tester.widget<CircleAvatar>(avatar).backgroundImage;
        expect(preview, isA<MemoryImage>());
        expect(edit.hitTestable(), findsOneWidget);
        await tester.tap(edit);
        await tester.pumpAndSettle();
        expect(calls, 2);
        expect(tester.widget<CircleAvatar>(avatar).backgroundImage, preview);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
