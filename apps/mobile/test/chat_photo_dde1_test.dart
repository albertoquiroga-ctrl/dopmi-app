import 'dart:async';

import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/communication/chat_photo_repository.dart';
import 'package:dopmi_mobile/features/communication/message_screens.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import 'community_test.dart' show DetailThreadCommunity;
import 'fake_identity_repository.dart';

class PhotoCommunity extends DetailThreadCommunity {
  bool closed = false;
  @override
  Future<Json> thread(String id) async => {
    ...await super.thread(id),
    'status': closed ? 'closed' : 'active',
  };
}

class FakeChatPhotos implements ChatPhotoRepository {
  @override
  String? userId = 'one';
  final uploads = <String>[];
  final sends = <(String, String, String)>[];
  final discarded = <String>[];
  Completer<String>? pendingUpload;
  bool failSend = false;
  bool failUpload = false;
  @override
  Future<String> upload(
    String threadId,
    String messageId,
    Uint8List bytes,
  ) async {
    uploads.add(messageId);
    if (failUpload) throw const FormatException('Carga interrumpida');
    if (pendingUpload != null) {
      return pendingUpload!.future;
    }
    return '$userId/$threadId/$messageId.jpg';
  }

  @override
  Future<Json> send(
    String threadId,
    String messageId,
    String body,
    String path,
  ) async {
    sends.add((messageId, body, path));
    if (failSend) throw const FormatException('Sin conexión');
    return {'id': messageId};
  }

  @override
  Future<String> photoUrl(String path) async =>
      throw const FormatException('Foto privada no disponible');
  @override
  Future<void> discard(String path) async {
    discarded.add(path);
  }
}

void main() {
  Future<void> start(
    WidgetTester tester,
    PhotoCommunity community,
    FakeChatPhotos photos,
    Future<XFile?> Function() picker,
  ) async {
    final identity = FakeIdentityRepository()
      ..user = const Identity('one', 'qa@example.test', verified: true);
    addTearDown(identity.changes.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          communityRepositoryProvider.overrideWithValue(community),
          chatPhotoRepositoryProvider.overrideWithValue(photos),
          chatPhotoPickerProvider.overrideWithValue(picker),
        ],
        child: MaterialApp(
          theme: dopmiTheme(),
          home: const ThreadScreen('thread-one'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  XFile photo() => XFile.fromData(
    Uint8List.fromList(img.encodePng(img.Image(width: 8, height: 8))),
    name: 'qa.png',
    mimeType: 'image/png',
  );

  testWidgets(
    'canceling selection sends nothing and removing preview clears image',
    (tester) async {
      final photos = FakeChatPhotos();
      var choose = false;
      await start(
        tester,
        PhotoCommunity(),
        photos,
        () async => choose ? photo() : null,
      );
      await tester.tap(find.byTooltip('Adjuntar foto'));
      await tester.pumpAndSettle();
      expect(photos.uploads, isEmpty);
      expect(photos.sends, isEmpty);
      choose = true;
      await tester.tap(find.byTooltip('Adjuntar foto'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('chat-photo-preview')), findsOneWidget);
      await tester.tap(find.byTooltip('Quitar foto'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('chat-photo-preview')), findsNothing);
      expect(photos.uploads, isEmpty);
    },
  );

  testWidgets('photo-only retry uses same UUID and uploaded path', (
    tester,
  ) async {
    final photos = FakeChatPhotos()..failSend = true;
    await start(tester, PhotoCommunity(), photos, () async => photo());
    await tester.tap(find.byTooltip('Adjuntar foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Enviar mensaje'));
    await tester.pumpAndSettle();
    expect(photos.uploads, hasLength(1));
    expect(photos.sends.single.$2, '');
    expect(find.byKey(const ValueKey('chat-photo-preview')), findsOneWidget);
    photos.failSend = false;
    await tester.tap(find.widgetWithText(ActionButton, 'Reintentar envío'));
    await tester.pumpAndSettle();
    expect(photos.uploads, hasLength(1));
    expect(photos.sends, hasLength(2));
    expect(photos.sends.first, photos.sends.last);
    await tester.pumpWidget(const SizedBox());
    expect(photos.discarded, isEmpty);
    expect(find.byKey(const ValueKey('chat-photo-preview')), findsNothing);
  });

  testWidgets(
    'closed thread preserves reading and disables photo composition',
    (tester) async {
      final photos = FakeChatPhotos();
      await start(
        tester,
        PhotoCommunity()..closed = true,
        photos,
        () async => photo(),
      );
      expect(
        find.textContaining('Esta conversación está cerrada'),
        findsOneWidget,
      );
      expect(find.byTooltip('Adjuntar foto'), findsNothing);
      expect(find.byTooltip('Enviar mensaje'), findsNothing);
      expect(photos.uploads, isEmpty);
    },
  );

  testWidgets(
    'upload failure preserves selection and message UUID for retry with text',
    (tester) async {
      final photos = FakeChatPhotos()..failUpload = true;
      await start(tester, PhotoCommunity(), photos, () async => photo());
      await tester.enterText(find.byType(TextField), 'Foto de Luna');
      await tester.tap(find.byTooltip('Adjuntar foto'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Enviar mensaje'));
      await tester.pumpAndSettle();
      expect(photos.sends, isEmpty);
      expect(find.byKey(const ValueKey('chat-photo-preview')), findsOneWidget);
      photos.failUpload = false;
      await tester.tap(find.widgetWithText(ActionButton, 'Reintentar envío'));
      await tester.pumpAndSettle();
      expect(photos.uploads, hasLength(2));
      expect(photos.uploads.first, photos.uploads.last);
      expect(photos.sends.single.$2, 'Foto de Luna');
    },
  );
  testWidgets(
    'leaving during upload discards pending private object in the same account',
    (tester) async {
      final photos = FakeChatPhotos()..pendingUpload = Completer<String>();
      await start(tester, PhotoCommunity(), photos, () async => photo());
      await tester.tap(find.byTooltip('Adjuntar foto'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Enviar mensaje'));
      await tester.pump();
      expect(photos.uploads, hasLength(1));
      await tester.pumpWidget(const SizedBox());
      photos.pendingUpload!.complete('one/thread-one/pending.jpg');
      await tester.pump();
      await tester.pump();
      expect(photos.discarded, ['one/thread-one/pending.jpg']);
      expect(photos.sends, isEmpty);
    },
  );

  testWidgets(
    'late upload after account changes never discards using another actor',
    (tester) async {
      final photos = FakeChatPhotos()..pendingUpload = Completer<String>();
      await start(tester, PhotoCommunity(), photos, () async => photo());
      await tester.tap(find.byTooltip('Adjuntar foto'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Enviar mensaje'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      photos.userId = 'other';
      photos.pendingUpload!.complete('one/thread-one/pending.jpg');
      await tester.pump();
      await tester.pump();
      expect(photos.discarded, isEmpty);
      expect(photos.sends, isEmpty);
    },
  );
  testWidgets(
    '320 px at 200 percent keeps attachment reachable without truncating authored multiline text',
    (tester) async {
      final previousErrorHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        debugPrint(details.toString());
        previousErrorHandler?.call(details);
      };
      try {
        final inter = FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
        await tester.runAsync(inter.load);
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final photos = FakeChatPhotos();
        var picked = 0;
        final identity = FakeIdentityRepository()
          ..user = const Identity('one', 'qa@example.test', verified: true);
        addTearDown(identity.changes.close);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              identityRepositoryProvider.overrideWithValue(identity),
              communityRepositoryProvider.overrideWithValue(PhotoCommunity()),
              chatPhotoRepositoryProvider.overrideWithValue(photos),
              chatPhotoPickerProvider.overrideWithValue(() async {
                picked++;
                return null;
              }),
            ],
            child: MaterialApp(
              theme: dopmiTheme(),
              builder: (_, child) => MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 640),
                  textScaler: TextScaler.linear(2),
                ),
                child: child!,
              ),
              home: const ThreadScreen('thread-one'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final attachment = find.byKey(const ValueKey('chat-attach-photo'));
        expect(tester.getSize(attachment), const Size(40, 40));
        expect(attachment.hitTestable(), findsOneWidget);
        await tester.tap(attachment);
        await tester.pumpAndSettle();
        expect(picked, 1);
        await tester.enterText(find.byType(TextField), 'Linea uno\nLinea dos');
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Linea uno\nLinea dos',
        );
        final layoutError = tester.takeException();
        if (layoutError is FlutterError) {
          for (final diagnostic in layoutError.diagnostics) {
            debugPrint(diagnostic.toStringDeep());
          }
        }
        expect(layoutError, isNull);
      } finally {
        FlutterError.onError = previousErrorHandler;
      }
    },
  );
}
