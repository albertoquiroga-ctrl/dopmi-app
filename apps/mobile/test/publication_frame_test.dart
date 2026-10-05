import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/adoption/publication_frame.dart';
import 'package:dopmi_mobile/features/adoption/photo_recovery.dart';
import 'package:dopmi_mobile/features/adoption/adoption_detail_layout.dart';
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

Future<void> tapPublication(WidgetTester tester, Finder target) async {
  await tester.pumpAndSettle();
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'three step preview keeps the footer reachable at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final font = FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
        await tester.runAsync(font.load);
        final repo = PhotoDraftCommunity();
        await startPublication(tester, repo, '/my-adoptions/post');
        await tapPublication(tester, find.text('Continuar'));
        await tapPublication(tester, find.text('Continuar'));
        expect(
          tester
              .widget<AdoptionDetailLayout>(find.byType(AdoptionDetailLayout))
              .preview,
          isTrue,
        );
        expect(find.text('Quiero saber más'), findsNothing);
        final submit = find.widgetWithText(FilledButton, 'Enviar a revisión');
        expect(tester.getRect(submit).bottom, lessThanOrEqualTo(640));
        final notice = find.text(
          'Al enviar, el equipo revisará fotos, información y privacidad antes de publicar.',
        );
        await tester.ensureVisible(notice);
        await tester.pumpAndSettle();
        expect(notice.hitTestable(), findsOneWidget);
        expect(
          find.byKey(const ValueKey('publication-header-back')).hitTestable(),
          findsOneWidget,
        );
        expect(find.text('Valida tu caso').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'camera and gallery cancellation retain a private draft at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
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
          expect(
            (await SharedPreferences.getInstance()).getString(
              pendingPhotoKey('one'),
            ),
            repo.post.id,
          );
          return null;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        await startPublication(tester, repo, '/my-adoptions/new');
        for (final label in ['Tomar foto', 'Subir desde galería']) {
          await tapPublication(
            tester,
            find.byTooltip('Editar foto de la mascota'),
          );
          await tapPublication(tester, find.text(label));
        }
        expect(sources, [0, 1]);
        expect(repo.post.photos, isEmpty);
        expect(
          (await SharedPreferences.getInstance()).getString(
            pendingPhotoKey('one'),
          ),
          isNull,
        );
        expect(
          tester
              .widget<PublicationFooter>(find.byType(PublicationFooter))
              .onContinue,
          isNull,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'special care can be toggled without losing the existing description',
    (tester) async {
      final repo = PhotoDraftCommunity();
      repo.post = Adoption({
        ...repo.post.data,
        'special_care': 'Medicación por la mañana',
      });
      await startPublication(tester, repo, '/my-adoptions/post');
      await tapPublication(tester, find.text('Continuar'));
      final care = find.byKey(const ValueKey('publication-special-care'));
      expect(tester.widget<PublicationTraitCheck>(care).value, isTrue);
      await tapPublication(tester, care);
      await tapPublication(tester, find.text('Guardar borrador'));
      expect(repo.savedPayload?['special_care'], '');
      await tapPublication(tester, care);
      await tapPublication(tester, find.text('Guardar borrador'));
      expect(repo.savedPayload?['special_care'], 'Medicación por la mañana');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'age and coexistence persist separately from precise legacy age',
    (tester) async {
      final repo = PhotoDraftCommunity();
      await startPublication(tester, repo, '/my-adoptions/post');
      await tapPublication(
        tester,
        find.widgetWithText(OutlinedButton, 'Senior'),
      );
      await tapPublication(tester, find.text('Continuar'));
      await tapPublication(
        tester,
        find.byKey(const ValueKey('publication-coexistence-children')),
      );
      await tapPublication(
        tester,
        find.byKey(const ValueKey('publication-coexistence-yard')),
      );
      await tapPublication(tester, find.text('Guardar borrador'));
      expect(repo.savedPayload?['age_band'], 'senior');
      expect(repo.savedPayload?['age_months'], 24);
      expect(repo.savedPayload?['coexistence'], ['children', 'yard']);
      expect(repo.savedPayload?['social_children'], isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'precise age remains valid and an invalid edit preserves the saved draft',
    (tester) async {
      final repo = PhotoDraftCommunity();
      await startPublication(tester, repo, '/my-adoptions/post');
      await tapPublication(
        tester,
        find.text('Presentación pública y edad precisa'),
      );
      final age = find.byKey(const ValueKey('publication-field-age_months'));
      await tester.ensureVisible(age);
      await tester.enterText(age, '1 año y 6 meses');
      FocusManager.instance.primaryFocus?.unfocus();
      await tapPublication(tester, find.text('Guardar borrador'));
      expect(repo.savedPayload?['age_months'], 18);
      await tester.enterText(age, 'edad desconocida');
      FocusManager.instance.primaryFocus?.unfocus();
      await tapPublication(tester, find.text('Guardar borrador'));
      expect(repo.savedPayload?['age_months'], 18);
      expect(
        tester.widget<TextFormField>(age).controller!.text,
        'edad desconocida',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'principal plus five additional photos stops adding and preserves the first',
    (tester) async {
      final repo = PhotoDraftCommunity();
      repo.post = Adoption({
        ...repo.post.data,
        'photos': [for (var i = 0; i < 6; i++) 'fixture/photo-$i'],
      });
      await startPublication(tester, repo, '/my-adoptions/post');
      await tapPublication(tester, find.text('Continuar'));
      expect(find.byType(PublicationPhotoThumbnail), findsNWidgets(5));
      expect(find.byType(PublicationPhotoPicker), findsNothing);
      final remove = find.byTooltip('Quitar foto del borrador').first;
      await tapPublication(tester, remove);
      await tapPublication(tester, find.text('Guardar borrador'));
      expect((repo.savedPayload?['photos'] as List).first, 'fixture/photo-0');
      expect((repo.savedPayload?['photos'] as List).length, 5);
      expect(find.byType(PublicationPhotoPicker), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'actual sex/species choices and keyboard editing survive frame rebuilds',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repo = PhotoDraftCommunity();
      await startPublication(tester, repo, '/my-adoptions/post');
      final name = find.byKey(const ValueKey('publication-field-pet_name'));
      await tester.ensureVisible(name);
      await tester.enterText(name, 'Mora corregida');
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);
      expect(
        tester.widget<TextFormField>(name).controller!.text,
        'Mora corregida',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      for (final label in ['Hembra', 'Gato']) {
        await tapPublication(
          tester,
          find.widgetWithText(OutlinedButton, label),
        );
      }
      await tapPublication(tester, find.text('Continuar'));
      expect(repo.savedPayload?['pet_name'], 'Mora corregida');
      expect(repo.savedPayload?['sex'], 'female');
      expect(repo.savedPayload?['species'], 'cat');
      expect(tester.takeException(), isNull);
    },
  );
}
