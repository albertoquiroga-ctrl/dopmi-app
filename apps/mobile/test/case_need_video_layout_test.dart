import 'dart:io';
import 'dart:ui' as ui;

import 'package:dopmi_mobile/core/media/video_upload.dart';
import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/rescue/case_publication_need_editor.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_videos.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'case_publication_need_video_test.dart'
    show NeedSession, NeedRescue, NeedVideos;

// Real private need editor layout; policy/save adapters are synthetic TEST only.
// No picker, decoder, upload, submit, backend or device operation is invoked.
void main() {
  setUpAll(() async {
    final inter = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await inter.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  for (final view in [
    ('normal', const Size(377, 852), 1.0),
    ('samsung115', const Size(411, 891), 1.15),
    ('large', const Size(320, 740), 2.0),
  ]) {
    for (final keyboard in [false, true]) {
      testWidgets('private need video layout ${view.$1} keyboard=$keyboard', (
        tester,
      ) async {
        tester.view.physicalSize = view.$2;
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = FakeViewPadding(bottom: keyboard ? 260 : 0);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final session = NeedSession();
        final rescue = NeedRescue();
        final videos = NeedVideos(session);
        addTearDown(videos.dispose);
        final boundaryKey = GlobalKey();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              communityRepositoryProvider.overrideWithValue(session),
              rescueRepositoryProvider.overrideWithValue(rescue),
              rescueVideosRepositoryProvider.overrideWithValue(videos),
            ],
            child: MaterialApp(
              theme: dopmiTheme(rescuer: true),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(view.$3)),
                child: child!,
              ),
              home: RepaintBoundary(
                key: boundaryKey,
                child: const Scaffold(
                  body: CasePublicationNeedEditor(
                    caseId: 'case-draft',
                    type: 'veterinary',
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (keyboard) {
          await tester.tap(
            find.byKey(const ValueKey('publication-need-title')),
          );
          await tester.pumpAndSettle();
        }
        Future<void> capture(String position) async {
          final dir = Platform.environment['DOPMI_NEED_VIDEO_EVIDENCE_DIR'];
          if (dir == null || dir.isEmpty) return;
          await tester.runAsync(() async {
            final boundary =
                boundaryKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final output = Directory(dir);
            await output.create(recursive: true);
            await File(
              '${output.path}/need-video-${view.$1}-keyboard-$keyboard-$position.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }

        Future<void> visible(Finder finder) async {
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(finder.hitTestable(), findsOneWidget);
          final rect = tester.getRect(finder);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(view.$2.width));
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(
            rect.bottom,
            lessThanOrEqualTo(view.$2.height - (keyboard ? 260 : 0)),
          );
        }

        expect(tester.takeException(), isNull);
        await capture('context');
        final saveDraft = find.widgetWithText(
          OutlinedButton,
          'Guardar borrador para añadir videos',
        );
        await visible(saveDraft);
        expect(tester.widget<OutlinedButton>(saveDraft).onPressed, isNotNull);
        await capture('save-private-draft');
        await tester.tap(saveDraft);
        await tester.pumpAndSettle();
        expect(rescue.writes, hasLength(1));
        expect(rescue.writes.single['parent'], 'case-draft');
        final upload = tester.widget<VideoUpload>(find.byType(VideoUpload));
        expect(upload.purpose, 'expense_evidence');
        expect(upload.parentId, 'expense-new');
        final choose = find.widgetWithText(OutlinedButton, 'Elegir video');
        await visible(choose);
        expect(tester.widget<OutlinedButton>(choose).onPressed, isNotNull);
        expect(
          find.textContaining('Este video es evidencia privada.'),
          findsOneWidget,
        );
        await capture('private-video-control');
        final save = find.widgetWithText(FilledButton, 'Guardar servicio');
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final saveRect = tester.getRect(save);
        expect(saveRect.left, greaterThanOrEqualTo(0));
        expect(saveRect.right, lessThanOrEqualTo(view.$2.width));
        expect(
          saveRect.bottom,
          lessThanOrEqualTo(view.$2.height - (keyboard ? 260 : 0)),
        );
        // Incomplete TEST fields must keep final save disabled; never submit.
        expect(tester.widget<FilledButton>(save).onPressed, isNull);
        await capture('footer');
        expect(rescue.transitions, 0);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
