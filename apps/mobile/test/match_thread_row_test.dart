import 'dart:ui' show PointerDeviceKind;
import 'dart:io';

import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/communication/match_thread_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:dopmi_mobile/core/media/photo_runtime.dart';
import 'package:dopmi_mobile/core/media/photo_store.dart';
import 'package:dopmi_mobile/features/adoption/community_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;

class ThumbnailCommunity extends FakeCommunity {
  ThumbnailCommunity() {
    post = Adoption({
      ...post.data,
      'photos': ['approved/photo.png'],
    });
  }
  bool fail = true;
  final paths = <String>[];
  @override
  Future<String> photoUrl(String path) async {
    paths.add(path);
    if (fail) throw const FormatException('Offline fixture');
    return 'https://example.test/thread-photo';
  }
}

void main() {
  testWidgets(
    'thread thumbnail retries signing within its circular target and renders a decoded photo',
    (tester) async {
      final repo = ThumbnailCommunity();
      final bytes = (await tester.runAsync(
        () => File('tool/fixtures/rocky.png').readAsBytes(),
      ))!;
      final runtime = (await tester.runAsync(
        () async => PhotoRuntime(
          store: MemoryPhotoStore(),
          download: (_, _) async => bytes,
        ),
      ))!;
      addTearDown(runtime.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            communityRepositoryProvider.overrideWithValue(repo),
            photoRuntimeProvider.overrideWithValue(runtime),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: MatchThreadRow({
                'post_id': 'post',
                'pet_name': 'Luna',
                'participant_name': 'Ana',
              }, open: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.paths, ['approved/photo.png', 'approved/photo.png']);
      final retry = find.byTooltip('Cargar foto');
      expect(retry, findsOneWidget);
      expect(tester.getSize(retry), const Size(48, 48));
      expect(tester.takeException(), isNull);

      repo.fail = false;
      await tester.runAsync(() async {
        await tester.tap(retry);
        await runtime.load(
          adoptionPhotoSource(repo, 'approved/photo.png'),
          width: 256,
        );
      });
      await tester.pumpAndSettle();
      final raw = find.byType(RawImage);
      expect(raw, findsOneWidget);
      final rendered = tester.renderObject<RenderImage>(raw);
      expect(rendered.image, isNotNull);
      expect(rendered.size, const Size(48, 48));
      expect(rendered.fit, BoxFit.cover);
      expect(
        find.ancestor(of: raw, matching: find.byType(ClipOval)),
        findsOneWidget,
      );
      expect(repo.paths.length, 3);
      expect(tester.takeException(), isNull);
    },
  );

  for (final large in [false, true]) {
    testWidgets(
      'donor thread hover, focus and activation preserve its callback; large=$large',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var opened = 0;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              communityRepositoryProvider.overrideWithValue(FakeCommunity()),
            ],
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  textScaler: TextScaler.linear(large ? 2 : 1),
                ),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: MatchThreadRow(
                      {
                        'id': 'real-thread',
                        'pet_name': 'Luna',
                        'participant_name': 'Patricia Hernandez',
                        'updated_at': '2025-09-30T18:30:00Z',
                        'unread_count': 3,
                        'last_message': 'Nos vemos el fin de semana.',
                      },
                      last: true,
                      open: () => opened++,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final row = find.byType(MatchThreadRow);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(tester.getCenter(row));
        await tester.pump();
        final material = find.descendant(
          of: row,
          matching: find.byType(Material),
        );
        expect(
          tester.widget<Material>(material).color,
          const Color(0xfffffbed),
        );
        expect(opened, 0);
        await mouse.moveTo(Offset.zero);
        await mouse.removePointer();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        final outline = find.byKey(
          const ValueKey('reference-keyboard-outline'),
        );
        expect(outline, findsOneWidget);
        expect(tester.getRect(outline), tester.getRect(row).inflate(5));
        expect(opened, 0);
        expect(find.text('30/9/2025'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(opened, 1);
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(opened, 2);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
