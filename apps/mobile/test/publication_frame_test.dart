import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/adoption/publication_frame.dart';
import 'package:dopmi_mobile/features/adoption/photo_recovery.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'community_test.dart' show FakeCommunity, PhotoDraftCommunity;
import 'fake_identity_repository.dart';

Future<void> startPublication(
  WidgetTester tester,
  FakeCommunity repo,
  String path, {
  RescueRepository? rescue,
}) async {
  SharedPreferences.setMockInitialValues({});
  final identity = FakeIdentityRepository()
    ..user = const Identity('one', 'fixture@example.test', verified: true);
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
      communityRepositoryProvider.overrideWithValue(repo),
      if (rescue != null) rescueRepositoryProvider.overrideWithValue(rescue),
      routerInitialLocationProvider.overrideWithValue(path),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const DopmiApp()),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('review reaches its final privacy notice by touch at 200%', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final repo = PhotoDraftCommunity();
    await startPublication(tester, repo, '/my-adoptions/${repo.post.id}');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    final scroll = find.byType(Scrollable).first;
    final viewport = tester.getRect(scroll);
    final submit = find.text('Enviar a revisión');
    final footerRect = tester.getRect(submit);
    final notice = find.text(
      'Al enviar, el equipo revisará fotos, información y privacidad antes de publicar.',
    );
    var sawStart = false;
    var sawEnd = false;
    for (var i = 0; i < 100; i++) {
      final rect = tester.getRect(notice);
      sawStart |= rect.top >= viewport.top && rect.top < viewport.bottom;
      sawEnd |= rect.bottom > viewport.top && rect.bottom <= viewport.bottom;
      if (sawStart && sawEnd) break;
      await tester.timedDragFrom(
        viewport.center,
        const Offset(0, -80),
        const Duration(milliseconds: 400),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(submit), footerRect);
    }
    expect(sawStart, isTrue);
    expect(sawEnd, isTrue);
    expect(submit.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'special care declaration reloads without invented details: scale=$scale',
      (tester) async {
        tester.view.physicalSize = const Size(377, 852);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final repo = PhotoDraftCommunity();
        repo.post = Adoption({...repo.post.data, 'special_care': ''});
        await startPublication(tester, repo, '/my-adoptions/${repo.post.id}');
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();
        final care = find.byKey(const ValueKey('publication-special-care'));
        await tester.ensureVisible(care);
        await tester.pumpAndSettle();
        expect(tester.widget<PublicationTraitCheck>(care).value, isFalse);
        await tester.tap(care);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Guardar borrador'));
        await tester.pumpAndSettle();
        expect(
          repo.savedPayload?['special_care'],
          'Requiere cuidados especiales',
        );
        final reload = find.text('Descartar cambios y cargar versión guardada');
        await tester.ensureVisible(reload);
        await tester.pumpAndSettle();
        await tester.tap(reload);
        await tester.pumpAndSettle();
        await tester.ensureVisible(care);
        await tester.pumpAndSettle();
        expect(tester.widget<PublicationTraitCheck>(care).value, isTrue);
        expect(
          find.byKey(const ValueKey('publication-field-special_care')),
          findsNothing,
        );
        await tester.ensureVisible(find.text('Describir cuidados'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Describir cuidados'));
        await tester.pumpAndSettle();
        final description = find.byKey(
          const ValueKey('publication-field-special_care'),
        );
        await tester.ensureVisible(description);
        await tester.enterText(
          description,
          'Dieta indicada por su veterinario',
        );
        await tester.tap(find.text('Guardar borrador'));
        await tester.pumpAndSettle();
        expect(
          repo.savedPayload?['special_care'],
          'Dieta indicada por su veterinario',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'special care checkbox preserves an existing description across toggles',
    (tester) async {
      final repo = PhotoDraftCommunity();
      repo.post = Adoption({
        ...repo.post.data,
        'special_care': 'Medicación por la mañana',
      });
      await startPublication(tester, repo, '/my-adoptions/${repo.post.id}');
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      final care = find.byKey(const ValueKey('publication-special-care'));
      await tester.ensureVisible(care);
      await tester.pumpAndSettle();
      expect(tester.widget<PublicationTraitCheck>(care).value, isTrue);
      await tester.tap(care);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar borrador'));
      await tester.pumpAndSettle();
      expect(repo.savedPayload?['special_care'], '');
      await tester.ensureVisible(care);
      await tester.pumpAndSettle();
      await tester.tap(care);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar borrador'));
      await tester.pumpAndSettle();
      expect(repo.savedPayload?['special_care'], 'Medicación por la mañana');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'age expression saves real months and invalid age preserves draft',
    (tester) async {
      final repo = PhotoDraftCommunity();
      await startPublication(tester, repo, '/my-adoptions/${repo.post.id}');
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      final age = find.byKey(const ValueKey('publication-field-age_months'));
      await tester.ensureVisible(age);
      await tester.enterText(age, '1 año y 6 meses');
      await tester.tap(find.text('Guardar borrador'));
      await tester.pumpAndSettle();
      expect(repo.savedPayload?['age_months'], 18);
      await tester.enterText(age, 'edad desconocida');
      await tester.tap(find.text('Guardar borrador'));
      await tester.pumpAndSettle();
      expect(repo.savedPayload?['age_months'], 18);
      expect(
        tester.widget<TextFormField>(age).controller!.text,
        'edad desconocida',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'health checkbox preserves yes no and unknown in the real draft',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repo = PhotoDraftCommunity();
      await startPublication(tester, repo, '/my-adoptions/${repo.post.id}');
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      final control = find.byKey(
        const ValueKey('publication-trait-vaccinated'),
      );
      expect(tester.widget<PublicationTraitCheck>(control).value, isNull);
      for (final value in <bool?>[true, false, null]) {
        final checkbox = find.descendant(
          of: control,
          matching: find.byType(Checkbox),
        );
        await Scrollable.ensureVisible(tester.element(checkbox), alignment: .1);
        await tester.pumpAndSettle();
        await tester.tap(checkbox);
        await tester.pumpAndSettle();
        expect(tester.widget<PublicationTraitCheck>(control).value, value);
        await tester.tap(find.text('Guardar borrador'));
        await tester.pumpAndSettle();
        expect(repo.savedPayload?['vaccinated'], value);
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();
        final summary = find.byKey(
          const ValueKey('publication-review-trait-vaccinated'),
        );
        await tester.ensureVisible(summary);
        await tester.pumpAndSettle();
        expect(tester.widget<PublicationTraitCheck>(summary).value, value);
        final readOnlyBox = find.descendant(
          of: summary,
          matching: find.byType(Checkbox),
        );
        expect(tester.widget<Checkbox>(readOnlyBox).onChanged, isNull);
        await tester.tap(readOnlyBox);
        await tester.pumpAndSettle();
        expect(tester.widget<PublicationTraitCheck>(summary).value, value);
        expect(repo.savedPayload?['vaccinated'], value);
        final social = find.byKey(
          const ValueKey('publication-review-trait-social_children'),
        );
        await Scrollable.ensureVisible(tester.element(social), alignment: 1);
        await tester.pumpAndSettle();
        final label = find.descendant(
          of: social,
          matching: find.text('Social con niñas y niños'),
        );
        final viewport = tester.getRect(find.byType(Scrollable).first);
        final labelRect = tester.getRect(label);
        expect(labelRect.top, greaterThanOrEqualTo(viewport.top));
        expect(labelRect.bottom, lessThanOrEqualTo(viewport.bottom));
        final socialValue = repo.savedPayload?['social_children'];
        expect(tester.widget<PublicationTraitCheck>(social).value, socialValue);
        final socialBox = find.descendant(
          of: social,
          matching: find.byType(Checkbox),
        );
        expect(tester.widget<Checkbox>(socialBox).onChanged, isNull);
        await tester.tap(socialBox);
        await tester.pumpAndSettle();
        expect(tester.widget<PublicationTraitCheck>(social).value, socialValue);
        expect(repo.savedPayload?['social_children'], socialValue);
        final back = find.byKey(const ValueKey('publication-header-back'));
        await tester.scrollUntilVisible(
          back,
          -300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(back);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'review links preserve authored data and expose no editing when submitted',
    (tester) async {
      tester.view.physicalSize = const Size(377, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = PhotoDraftCommunity();
      await startPublication(tester, repo, '/my-adoptions/${repo.post.id}');
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      final name = find.byKey(const ValueKey('publication-field-pet_name'));
      await tester.enterText(name, 'Mora revisada');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Mora revisada'), findsOneWidget);
      final edit = find.byTooltip('Editar Información básica');
      await Scrollable.ensureVisible(tester.element(edit), alignment: .2);
      await tester.pumpAndSettle();
      final editButton = find.descendant(
        of: edit,
        matching: find.byType(TextButton),
      );
      expect(tester.getSize(editButton).height, greaterThanOrEqualTo(48));
      final editRect = tester.getRect(editButton);
      await tester.tapAt(Offset(editRect.center.dx, editRect.bottom - 2));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(name).controller!.text,
        'Mora revisada',
      );
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      final photosEdit = find.byTooltip('Editar Fotos');
      await Scrollable.ensureVisible(tester.element(photosEdit), alignment: .2);
      await tester.pumpAndSettle();
      await tester.tap(photosEdit);
      await tester.pumpAndSettle();
      expect(find.byType(PublicationPhotoThumbnail), findsOneWidget);
      repo.post = Adoption({...repo.post.data, 'status': 'submitted'});
      final reload = find.text('Descartar cambios y cargar versión guardada');
      await Scrollable.ensureVisible(tester.element(reload), alignment: .2);
      await tester.pumpAndSettle();
      await tester.tap(reload);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Editar Fotos'), findsNothing);
      expect(find.byTooltip('Editar Información básica'), findsNothing);
      expect(find.text('Retirar de revisión para editar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'publication choices persist real enums and are locked during review',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repo = PhotoDraftCommunity();
      await startPublication(tester, repo, '/my-adoptions/${repo.post.id}');
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      for (final label in ['Hembra', 'Gato']) {
        final target = find.widgetWithText(OutlinedButton, label);
        await Scrollable.ensureVisible(tester.element(target), alignment: .2);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Guardar borrador'));
      await tester.pumpAndSettle();
      expect(repo.savedPayload?['sex'], 'female');
      expect(repo.savedPayload?['species'], 'cat');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PublicationChoiceRow(
              label: 'Sexo',
              options: {'male': 'Macho', 'female': 'Hembra'},
              value: 'female',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Hembra'),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'removing a cover promotes the next real photo and persists the draft',
    (tester) async {
      tester.view.physicalSize = const Size(377, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = PhotoDraftCommunity();
      repo.post = Adoption({
        ...repo.post.data,
        'photos': ['fixture/first', 'fixture/second'],
      });
      await startPublication(tester, repo, '/my-adoptions/${repo.post.id}');
      final first = find.byKey(const ValueKey('fixture/first'));
      final second = find.byKey(const ValueKey('fixture/second'));
      expect(tester.getSize(first), const Size(167, 167));
      expect(tester.getTopLeft(second).dy - tester.getTopLeft(first).dy, 179);
      expect(find.text('Principal'), findsOneWidget);
      await tester.ensureVisible(first);
      await tester.tap(
        find.descendant(of: first, matching: find.byType(IconButton)),
      );
      await tester.pumpAndSettle();
      expect(first, findsNothing);
      expect(
        tester.widget<PublicationPhotoThumbnail>(second).principal,
        isTrue,
      );
      await tester.tap(find.text('Guardar borrador'));
      await tester.pumpAndSettle();
      expect(repo.savedPayload?['photos'], ['fixture/second']);
      expect(tester.takeException(), isNull);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'camera and gallery preserve a private draft at text scale $scale',
      (tester) async {
        tester.view.physicalSize = scale == 1
            ? const Size(390, 844)
            : const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final repo = FakeCommunity();
        final sources = <int>[];
        const channel = MethodChannel('plugins.flutter.io/image_picker');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method != 'pickImage') return null;
          final args = Map<String, dynamic>.from(call.arguments as Map);
          sources.add(args['source'] as int);
          expect(args['requestFullMetadata'], isFalse);
          expect(args['maxWidth'], 1600);
          expect(args['maxHeight'], 1600);
          expect(repo.post.status, 'draft');
          expect(repo.savedPayload, isNotNull);
          final preferences = await SharedPreferences.getInstance();
          expect(preferences.getString(pendingPhotoKey('one')), repo.post.id);
          return null; // The user cancels the platform picker; no photo is invented.
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        await startPublication(tester, repo, '/my-adoptions/new');
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Continuar'),
              )
              .onPressed,
          isNull,
        );
        await tester.ensureVisible(find.text('Tomar foto'));
        await tester.pumpAndSettle();
        expect(find.text('Tomar foto').hitTestable(), findsOneWidget);
        await tester.tap(find.text('Tomar foto'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Subir desde galería'));
        await tester.pumpAndSettle();
        expect(find.text('Subir desde galería').hitTestable(), findsOneWidget);
        await tester.tap(find.text('Subir desde galería'));
        await tester.pumpAndSettle();
        expect(sources, [0, 1]);
        expect(
          (await SharedPreferences.getInstance()).getString(
            pendingPhotoKey('one'),
          ),
          isNull,
        );
        expect(repo.post.photos, isEmpty);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Continuar'),
              )
              .onPressed,
          isNull,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'keyboard at 320px and 200% keeps authored text and restores full footer',
    (tester) async {
      tester.view.physicalSize = const Size(640, 1280);
      tester.view.devicePixelRatio = 2;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repo = PhotoDraftCommunity();
      await startPublication(tester, repo, '/my-adoptions/${repo.post.id}');
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      final name = find.byKey(const ValueKey('publication-field-pet_name'));
      await tester.ensureVisible(name);
      await tester.enterText(name, 'Mora desde el teclado');
      tester.view.viewInsets = const FakeViewPadding(bottom: 600);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(name).controller!.text,
        'Mora desde el teclado',
      );
      expect(tester.testTextInput.isVisible, isTrue);
      expect(find.text('Guardar borrador'), findsNothing);
      expect(tester.takeException(), isNull);
      FocusManager.instance.primaryFocus?.unfocus();
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(find.text('Guardar borrador'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(name).controller!.text,
        'Mora desde el teclado',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
