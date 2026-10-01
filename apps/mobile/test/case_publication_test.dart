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
      'public_data': {'pet_name': 'Mora', 'species': 'dog', 'sex': 'unknown'},
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

void main() {
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
      await tester.tap(find.text('Continuar'));
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
      await tester.tap(find.text('Continuar'));
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
      await tester.tap(find.text('Continuar'));
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
