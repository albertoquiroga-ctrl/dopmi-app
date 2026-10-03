import 'dart:async';
import 'dart:typed_data';

import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/profile/account_photo_repository.dart';
import 'package:dopmi_mobile/features/profile/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'fake_identity_repository.dart';

void main() {
  testWidgets(
    'private photo preview waits for save and retries the same upload',
    (tester) async {
      tester.view.physicalSize = const Size(377, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final identity = FakeIdentityRepository()
        ..user = const Identity('one', 'ana@example.test', verified: true);
      addTearDown(identity.changes.close);
      var uploads = 0, saves = 0;
      Future<Uint8List?> Function() pick = () async =>
          Uint8List.fromList(img.encodePng(img.Image(width: 8, height: 8)));
      final paths = <String?>[];
      final photos = AccountPhotoRepository(
        owner: () => identity.current?.id,
        rpc: (name, params) async {
          if (name == 'dopmi_my_account_photo') return null;
          paths.add(params['photo_path'] as String?);
          if (++saves == 1) throw StateError('retry');
          return {'photo_path': paths.last};
        },
        upload: (id, bytes) async {
          uploads++;
          expect(img.decodeJpg(bytes), isNotNull);
          return '$id/$id/73000000-0000-4000-8000-000000000001.jpg';
        },
        sign: (_) async => throw StateError('unexpected sign'),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            identityRepositoryProvider.overrideWithValue(identity),
            accountPhotoRepositoryProvider.overrideWithValue(photos),
            accountPhotoPickerProvider.overrideWithValue(() => pick()),
          ],
          child: MaterialApp(
            theme: dopmiTheme(),
            home: const BasicInfoScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Editar foto de perfil'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(uploads, 0);
      expect(find.text('Cerrar sesión'), findsNothing);
      expect(find.text('Guardados'), findsNothing);
      await tester.enterText(find.byType(TextFormField).first, 'Ana editada');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, 'Guardar cambios');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Guardamos los cambios de tu perfil.'), findsNothing);
      expect(find.text('Ana editada'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(uploads, 1);
      expect(saves, 2);
      expect(paths.first, paths.last);
      expect(find.text('Guardamos los cambios de tu perfil.'), findsOneWidget);
      final savedPreview = tester.widget<Image>(find.byType(Image)).image;
      pick = () async => null;
      await tester.ensureVisible(find.byTooltip('Editar foto de perfil'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Editar foto de perfil'));
      await tester.pumpAndSettle();
      expect(tester.widget<Image>(find.byType(Image)).image, savedPreview);
      expect(uploads, 1);
      final pending = Completer<Uint8List?>();
      pick = () => pending.future;
      await tester.tap(find.byTooltip('Editar foto de perfil'));
      await tester.pump();
      identity.user = const Identity(
        'two',
        'other@example.test',
        verified: true,
      );
      pending.complete(
        Uint8List.fromList(img.encodePng(img.Image(width: 12, height: 12))),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pumpAndSettle();
      expect(tester.widget<Image>(find.byType(Image)).image, savedPreview);
      expect(uploads, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
