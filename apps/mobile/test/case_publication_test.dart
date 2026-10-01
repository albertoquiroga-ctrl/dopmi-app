import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/adoption/publication_frame.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dopmi_mobile/features/adoption/photo_recovery.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'community_test.dart' show FakeCommunity;
import 'publication_frame_test.dart' show startPublication;
import 'rescue_test.dart' show FakeRescue;

class DraftCaseRescue extends FakeRescue {
  Json? publicSaved;
  @override
  Future<Json> detail(String id) async => {
    'record': {
      ...caseRecord.data,
      'owner_id': 'one',
      'status': 'draft',
      'public_data':
          publicSaved ??
          {'pet_name': 'Mora', 'species': 'dog', 'sex': 'unknown'},
      'files': <Json>[
        {'role': 'public', 'path': 'one/case-one/photo.jpg'},
      ],
    },
    'history': <Json>[],
  };
  @override
  Future<RescueRecord> save(
    String kind,
    Json publicData,
    Json privateData,
    List<Json> files, {
    RescueRecord? record,
    String? parent,
  }) async {
    saveCalls++;
    publicSaved = publicData;
    return RescueRecord({
      ...record!.data,
      'public_data': publicData,
      'private_data': privateData,
      'files': files,
      'version': record.version + 1,
    });
  }
}

class SubmittingCaseRescue extends DraftCaseRescue {
  SubmittingCaseRescue(this.reject);
  final bool reject;
  int submits = 0;
  RescueRecord? submitted;
  @override
  Future<RescueRecord> transition(RescueRecord record, String action) async {
    submits++;
    if (reject) throw const FormatException('No se pudo enviar. Reintenta.');
    submitted = RescueRecord({
      ...record.data,
      'status': 'submitted',
      'version': record.version + 1,
    });
    return submitted!;
  }

  @override
  Future<DataPage<RescueRecord>> mine(
    String kind,
    int page, {
    String? parent,
  }) async => DataPage(
    submitted == null ? <RescueRecord>[] : [submitted!],
    submitted == null ? 0 : 1,
  );
}

void main() {
  for (final reject in [false, true]) {
    testWidgets(
      'case submission returns to owned cases only on confirmation reject=$reject',
      (tester) async {
        final rescue = SubmittingCaseRescue(reject);
        await startPublication(
          tester,
          FakeCommunity(),
          '/rescue/case-one',
          rescue: rescue,
        );
        for (var i = 0; i < 2; i++) {
          await tester.tap(
            find.textContaining(RegExp(r'^Continuar( a revisión)?$')),
          );
          await tester.pumpAndSettle();
        }
        await tester.enterText(
          find.byKey(const ValueKey('case-field-need')),
          'Cuidados del borrador',
        );
        await tester.tap(find.text('Continuar a revisión'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Enviar a revisión'));
        await tester.pumpAndSettle();
        expect(rescue.submits, 1);
        final context = tester.element(find.byType(Scaffold).first);
        expect(
          GoRouter.of(context).routeInformationProvider.value.uri.path,
          reject ? '/rescue/case-one' : '/my-cases',
        );
        expect(rescue.publicSaved!['need'], 'Cuidados del borrador');
        if (reject) {
          expect(find.text('Enviar a revisión'), findsOneWidget);
          expect(find.textContaining('No se pudo enviar'), findsOneWidget);
        } else {
          expect(find.text('Enviar a revisión'), findsNothing);
          expect(rescue.submitted!.status, 'submitted');
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'medicine needs cancel, save, reopen and remove through the actual draft',
    (tester) async {
      final repo = DraftCaseRescue();
      await startPublication(
        tester,
        FakeCommunity(),
        '/rescue/case-one',
        rescue: repo,
      );
      for (var i = 0; i < 2; i++) {
        await tester.tap(
          find.textContaining(RegExp(r'^Continuar( a revisión)?$')),
        );
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Medicina'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.text('Necesidades agregadas'), findsNothing);
      await tester.tap(find.text('Medicina'));
      await tester.pumpAndSettle();
      for (final pair in [
        ('title', 'Medicina prescrita'),
        ('amount', '123.45'),
        ('detail', 'Seguimiento indicado'),
      ]) {
        final field = find.byKey(ValueKey('case-field-${pair.$1}'));
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();
        await tester.enterText(field, pair.$2);
      }
      FocusManager.instance.primaryFocus?.unfocus();
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      final add = find.text('Guardar medicina');
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar borrador'));
      await tester.pumpAndSettle();
      final saved = List<Json>.from(repo.publicSaved!['need_items'] as List);
      expect(saved.single['title'], 'Medicina prescrita');
      expect(saved.single['amount_cents'], 12345);
      expect(saved.single['type'], 'medicine');
      expect(saved.single['urgent'], false);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await startPublication(
        tester,
        FakeCommunity(),
        '/rescue/case-one',
        rescue: repo,
      );
      for (var i = 0; i < 2; i++) {
        await tester.tap(
          find.textContaining(RegExp(r'^Continuar( a revisión)?$')),
        );
        await tester.pumpAndSettle();
      }
      final restored = find.text('Medicina prescrita');
      await tester.ensureVisible(restored);
      await tester.pumpAndSettle();
      expect(restored, findsOneWidget);
      await tester.tap(
        find.textContaining(RegExp(r'^Continuar( a revisión)?$')),
      );
      await tester.pumpAndSettle();
      final review = find.text('Medicina prescrita');
      await tester.ensureVisible(review);
      await tester.pumpAndSettle();
      expect(review, findsOneWidget);
      final edit = find.byKey(const ValueKey('case-review-edit-Necesidades'));
      await tester.ensureVisible(edit);
      await tester.pumpAndSettle();
      await tester.tap(edit);
      await tester.pumpAndSettle();
      final remove = find.text('Eliminar');
      await tester.ensureVisible(remove);
      await tester.pumpAndSettle();
      await tester.tap(remove);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar borrador'));
      await tester.pumpAndSettle();
      expect(repo.publicSaved!['need_items'], isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('case needs keeps focus at large text and saves before review', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final repo = DraftCaseRescue();
    await startPublication(
      tester,
      FakeCommunity(),
      '/rescue/case-one',
      rescue: repo,
    );
    for (var i = 0; i < 2; i++) {
      await tester.tap(
        find.textContaining(RegExp(r'^Continuar( a revisión)?$')),
      );
      await tester.pumpAndSettle();
    }
    expect(
      tester
          .widget<PublicationStepper>(find.byType(PublicationStepper))
          .totalSteps,
      4,
    );
    final need = find.byKey(const ValueKey('case-field-need'));
    await tester.ensureVisible(need);
    await tester.pumpAndSettle();
    await tester.enterText(need, 'Comida y seguimiento');
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<EditableText>(
            find.descendant(of: need, matching: find.byType(EditableText)),
          )
          .focusNode
          .hasFocus,
      isTrue,
    );
    expect(tester.testTextInput.isVisible, isTrue);
    expect(
      tester.widget<TextField>(need).controller!.text,
      'Comida y seguimiento',
    );
    tester.view.resetViewInsets();
    tester.testTextInput.hide();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(RegExp(r'^Continuar( a revisión)?$')));
    await tester.pumpAndSettle();
    expect(repo.publicSaved!['need'], 'Comida y seguimiento');
    expect(find.text('Registrar gasto realizado'), findsNothing);
    expect(find.text('Recargar estado'), findsNothing);
    expect(find.text('Borrador guardado.'), findsNothing);
    expect(find.text('Enviar a revisión'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'case review displays saved data and editing preserves the draft',
    (tester) async {
      final repo = DraftCaseRescue();
      await startPublication(
        tester,
        FakeCommunity(),
        '/rescue/case-one',
        rescue: repo,
      );
      await tester.tap(
        find.textContaining(RegExp(r'^Continuar( a revisión)?$')),
      );
      await tester.pumpAndSettle();
      final story = find.byKey(const ValueKey('case-field-story'));
      await tester.ensureVisible(story);
      await tester.pumpAndSettle();
      await tester.enterText(story, 'Rescatada bajo la lluvia');
      FocusManager.instance.primaryFocus?.unfocus();
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.tap(
        find.textContaining(RegExp(r'^Continuar( a revisión)?$')),
      );
      await tester.pumpAndSettle();
      final need = find.byKey(const ValueKey('case-field-need'));
      expect(need, findsOneWidget);
      await tester.enterText(need, 'Seguimiento veterinario');
      FocusManager.instance.primaryFocus?.unfocus();
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.tap(
        find.textContaining(RegExp(r'^Continuar( a revisión)?$')),
      );
      await tester.pumpAndSettle();
      expect(repo.publicSaved!['need'], 'Seguimiento veterinario');
      expect(repo.publicSaved!['story'], 'Rescatada bajo la lluvia');
      expect(find.text('Revisa tu caso'), findsOneWidget);
      expect(
        tester.getSize(find.byType(PublicationPhotoThumbnail)),
        const Size(110, 110),
      );
      final review = find.text('Rescatada bajo la lluvia');
      await tester.ensureVisible(review);
      await tester.pumpAndSettle();
      expect(review, findsOneWidget);
      final edit = find.byKey(
        const ValueKey('case-review-edit-Información básica'),
      );
      await tester.ensureVisible(edit);
      await tester.pumpAndSettle();
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(story).controller!.text,
        'Rescatada bajo la lluvia',
      );
      await tester.tap(
        find.textContaining(RegExp(r'^Continuar( a revisión)?$')),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(need).controller!.text,
        'Seguimiento veterinario',
      );
      await tester.tap(
        find.textContaining(RegExp(r'^Continuar( a revisión)?$')),
      );
      await tester.pumpAndSettle();
      final editNeeds = find.byKey(
        const ValueKey('case-review-edit-Necesidades'),
      );
      await tester.ensureVisible(editNeeds);
      await tester.pumpAndSettle();
      await tester.tap(editNeeds);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(need).controller!.text,
        'Seguimiento veterinario',
      );
      await tester.tap(
        find.textContaining(RegExp(r'^Continuar( a revisión)?$')),
      );
      await tester.pumpAndSettle();
      final photos = find.byKey(const ValueKey('case-review-edit-Fotos'));
      await tester.ensureVisible(photos);
      await tester.pumpAndSettle();
      await tester.tap(photos);
      await tester.pumpAndSettle();
      expect(find.byType(PublicationPhotoPicker), findsOneWidget);
      expect(repo.publicSaved!['story'], 'Rescatada bajo la lluvia');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'case information keeps real enum values and authored text through the large keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repo = DraftCaseRescue();
      await startPublication(
        tester,
        FakeCommunity(),
        '/rescue/case-one',
        rescue: repo,
      );
      await tester.tap(
        find.textContaining(RegExp(r'^Continuar( a revisión)?$')),
      );
      await tester.pumpAndSettle();
      final name = find.byKey(const ValueKey('case-field-pet_name'));
      await tester.ensureVisible(name);
      await tester.pumpAndSettle();
      await tester.enterText(name, 'Mora corregida');
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(name).controller!.text, 'Mora corregida');
      expect(tester.testTextInput.isVisible, isTrue);
      expect(
        tester
            .widget<EditableText>(
              find.descendant(of: name, matching: find.byType(EditableText)),
            )
            .focusNode
            .hasFocus,
        isTrue,
      );
      expect(find.text('Guardar borrador'), findsNothing);
      tester.view.resetViewInsets();
      tester.testTextInput.hide();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      for (final label in ['Hembra', 'Gato', 'Por determinar']) {
        final choice = find.text(label);
        await tester.ensureVisible(choice);
        await tester.pumpAndSettle();
        await tester.tap(choice);
        await tester.pumpAndSettle();
      }
      await tester.tap(
        find.textContaining(RegExp(r'^Continuar( a revisión)?$')),
      );
      await tester.pumpAndSettle();
      expect(repo.publicSaved!['pet_name'], 'Mora corregida');
      expect(repo.publicSaved!['sex'], 'unknown');
      expect(repo.publicSaved!['species'], 'cat');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('tapping a case photo opens the existing private file route', (
    tester,
  ) async {
    await startPublication(
      tester,
      FakeCommunity(),
      '/rescue/case-one',
      rescue: DraftCaseRescue(),
    );
    final thumbnail = find.byType(PublicationPhotoThumbnail);
    await tester.ensureVisible(thumbnail);
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getTopLeft(thumbnail) + const Offset(20, 20));
    await tester.pumpAndSettle();
    final scaffold = find.byType(Scaffold).last;
    expect(GoRouterState.of(tester.element(scaffold)).uri.path, '/rescue-file');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'case camera and gallery save first and cancellation never adds a photo',
    (tester) async {
      final repo = DraftCaseRescue();
      final sources = <int>[];
      const channel = MethodChannel('plugins.flutter.io/image_picker');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method != 'pickImage') return null;
        final args = Map<String, dynamic>.from(call.arguments as Map);
        sources.add(args['source'] as int);
        expect(args['maxWidth'], 1600);
        expect(args['maxHeight'], 1600);
        expect(args['requestFullMetadata'], isFalse);
        expect(repo.saveCalls, sources.length);
        final preferences = await SharedPreferences.getInstance();
        expect(
          preferences.getString(pendingPhotoKey('one')),
          'rescue:case-one',
        );
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await startPublication(
        tester,
        FakeCommunity(),
        '/rescue/case-one',
        rescue: repo,
      );
      for (final label in ['Tomar foto', 'Subir desde galería']) {
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
      expect(sources, [0, 1]);
      expect(find.byType(PublicationPhotoThumbnail), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getString(
          pendingPhotoKey('one'),
        ),
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('a new case cannot continue without a real public photo', (
    tester,
  ) async {
    await startPublication(
      tester,
      FakeCommunity(),
      '/rescue/new?kind=case',
      rescue: DraftCaseRescue(),
    );
    expect(find.text('Publicar caso'), findsOneWidget);
    final footer = tester.widget<PublicationFooter>(
      find.byType(PublicationFooter),
    );
    expect(footer.onContinue, isNull);
    expect(footer.onSave, isNotNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'case continuation saves the real draft and back preserves its data at large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repo = DraftCaseRescue();
      await startPublication(
        tester,
        FakeCommunity(),
        '/rescue/case-one',
        rescue: repo,
      );
      await tester.tap(
        find.textContaining(RegExp(r'^Continuar( a revisión)?$')),
      );
      await tester.pumpAndSettle();
      expect(repo.publicSaved!['pet_name'], 'Mora');
      expect(repo.publicSaved!['sex'], 'unknown');
      await tester.tap(find.widgetWithText(TextButton, 'Publicar caso').first);
      await tester.pumpAndSettle();
      expect(find.text('Publicar caso'), findsOneWidget);
      expect(
        tester
            .widget<PublicationFooter>(find.byType(PublicationFooter))
            .onContinue,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
