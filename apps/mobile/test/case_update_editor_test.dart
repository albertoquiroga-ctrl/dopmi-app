import 'dart:async';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/rescue/case_update_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_identity_repository.dart';
import 'rescue_test.dart' show FakeCaseUpdates, FakeRescue;

class EditorUpdates extends FakeCaseUpdates {
  bool fail = false;
  String status = 'changes_requested';
  Future<List<CaseUpdate>>? pending;
  final writes = <Json>[];
  CaseUpdate record([String? state]) => CaseUpdate({
    'id': 'update-one',
    'case_id': 'case-one',
    'body': 'Texto conservado.',
    'status': state ?? status,
    'version': 7,
    'photos': <String>[],
  });
  @override
  Future<List<CaseUpdate>> mine(String caseId) async {
    if (pending != null) return pending!;
    if (fail) throw const FormatException('offline');
    return [record()];
  }

  @override
  Future<CaseUpdate> save(
    String caseId,
    String body,
    List<String> photos, {
    CaseUpdate? update,
  }) async {
    writes.add({
      'case_id': caseId,
      'body': body,
      'id': update?.id,
      'version': update?.version,
    });
    return CaseUpdate({...record('draft').data, 'body': body, 'version': 8});
  }
}

void main() {
  Future<ProviderContainer> start(
    WidgetTester tester,
    EditorUpdates repo, {
    bool large = false,
    String path = '/rescue-cases/case-one/updates/update-one',
  }) async {
    tester.view.physicalSize = large
        ? const Size(320, 640)
        : const Size(377, 852);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = large ? 2 : 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final identity = FakeIdentityRepository()
      ..user = Identity('one', 'one@example.test', verified: true);
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        communityRepositoryProvider.overrideWithValue(FakeCommunity()),
        rescueRepositoryProvider.overrideWithValue(FakeRescue()),
        caseUpdateRepositoryProvider.overrideWithValue(repo),
        routerInitialLocationProvider.overrideWithValue(path),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await identity.changes.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DopmiApp()),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return container;
  }

  for (final large in [false, true]) {
    testWidgets(
      'new update question stays complete before and after typing: $large',
      (tester) async {
        final font = FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
        await tester.runAsync(font.load);
        final repo = EditorUpdates();
        await start(
          tester,
          repo,
          large: large,
          path: '/rescue-cases/case-one/updates/new',
        );
        final field = find.byType(TextField);
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();
        void checkLabel() {
          final label = find.text('¿Cómo sigue el rescate?').first;
          final paragraph = tester.renderObject<RenderParagraph>(label);
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(
            tester.getRect(field).contains(tester.getRect(label).center),
            isTrue,
          );
        }

        checkLabel();
        await tester.enterText(field, 'Luna terminó su tratamiento.');
        await tester.pumpAndSettle();
        checkLabel();
        expect(
          tester.widget<TextField>(field).controller!.text,
          'Luna terminó su tratamiento.',
        );
        expect(repo.writes, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'failed restore cannot create replacement; retry saves the original version: $large',
      (tester) async {
        final repo = EditorUpdates()..fail = true;
        await start(tester, repo, large: large);
        Future<void> reveal(Finder target, [double delta = 200]) async {
          await tester.scrollUntilVisible(
            target,
            delta,
            scrollable: find
                .descendant(
                  of: find.byType(ListView),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.ensureVisible(target);
          await tester.pumpAndSettle();
        }

        await reveal(find.byType(TextField));
        expect(tester.widget<TextField>(find.byType(TextField)).enabled, false);
        await reveal(find.byType(OutlinedButton));
        expect(
          tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
          isNull,
        );
        await reveal(find.text('Guardar borrador'));
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Guardar borrador'),
              )
              .onPressed,
          isNull,
        );
        await reveal(find.text('Enviar a revisión'));
        expect(
          tester
              .widget<TextButton>(
                find.widgetWithText(TextButton, 'Enviar a revisión'),
              )
              .onPressed,
          isNull,
        );
        expect(repo.writes, isEmpty);
        final retry = find.text('Volver a intentar');
        await reveal(retry, -200);
        await tester.tap(retry);
        await tester.pumpAndSettle();
        await reveal(find.byType(TextField));
        expect(tester.widget<TextField>(find.byType(TextField)).enabled, false);
        repo.fail = false;
        await reveal(retry, -200);
        await tester.tap(retry);
        await tester.pumpAndSettle();
        await reveal(find.byType(TextField));
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Texto conservado.',
        );
        await tester.enterText(
          find.byType(TextField),
          'Actualización corregida.',
        );
        final save = find.text('Guardar borrador');
        await reveal(save);
        expect(save.hitTestable(), findsOneWidget);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(repo.writes, [
          {
            'case_id': 'case-one',
            'body': 'Actualización corregida.',
            'id': 'update-one',
            'version': 7,
          },
        ]);
        expect(find.text('Borrador guardado.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final large in [false, true]) {
    testWidgets(
      'drag dismisses the editor keyboard while retaining its private draft: $large',
      (tester) async {
        final repo = EditorUpdates();
        await start(tester, repo, large: large);
        await tester.ensureVisible(find.byType(TextField));
        await tester.enterText(
          find.byType(TextField),
          'Borrador privado sin enviar.',
        );
        await tester.pump();
        expect(tester.testTextInput.isVisible, true);
        tester.view.viewInsets = const FakeViewPadding(bottom: 400);
        addTearDown(tester.view.resetViewInsets);
        await tester.pump();
        await tester.scrollUntilVisible(
          find.text('Guardar borrador'),
          200,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.ensureVisible(find.text('Guardar borrador'));
        await tester.pumpAndSettle();
        final scroll = tester.getRect(find.byType(ListView));
        await tester.dragFrom(
          Offset(scroll.left + 8, scroll.center.dy),
          const Offset(0, 60),
        );
        await tester.pumpAndSettle();
        expect(tester.testTextInput.isVisible, false);
        tester.view.resetViewInsets();
        await tester.pump();
        await tester.scrollUntilVisible(
          find.byType(TextField),
          -200,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Borrador privado sin enviar.',
        );
        expect(repo.writes, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final status in ['submitted', 'approved']) {
    testWidgets('direct editor respects locked $status state', (tester) async {
      final repo = EditorUpdates()..status = status;
      await start(tester, repo);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, false);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Guardar borrador'),
            )
            .onPressed,
        isNull,
      );
      expect(find.textContaining('no se puede editar'), findsOneWidget);
      expect(repo.writes, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('new advance remains saveable without an existing id', (
    tester,
  ) async {
    final repo = EditorUpdates();
    await start(tester, repo, path: '/rescue-cases/case-one/updates/new');
    await tester.enterText(find.byType(TextField), 'Nuevo avance real.');
    await tester.ensureVisible(find.text('Guardar borrador'));
    await tester.tap(find.text('Guardar borrador'));
    await tester.pumpAndSettle();
    expect(repo.writes.single, {
      'case_id': 'case-one',
      'body': 'Nuevo avance real.',
      'id': null,
      'version': null,
    });
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'late restoration after leaving cannot update disposed text input',
    (tester) async {
      final pending = Completer<List<CaseUpdate>>();
      final repo = EditorUpdates()..pending = pending.future;
      await start(tester, repo);
      await tester.pumpWidget(const SizedBox());
      pending.complete([repo.record()]);
      await tester.pump();
      expect(repo.writes, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
