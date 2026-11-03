import 'dart:async';
import 'dart:typed_data';

import 'package:dopmi_mobile/core/design_tokens.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/adoption/photo_recovery.dart';
import 'package:dopmi_mobile/features/adoption/publication_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'community_test.dart' show PhotoDraftCommunity;
import 'publication_frame_test.dart' show startPublication, tapPublication;

class BatchPublicationPicker extends ImagePicker {
  List<XFile> files = [];
  Completer<List<XFile>>? pending;
  int? requestedLimit;
  bool? metadata;
  int calls = 0;

  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async {
    calls++;
    requestedLimit = limit;
    metadata = requestFullMetadata;
    return pending == null ? files : pending!.future;
  }
}

class BatchPublicationCommunity extends PhotoDraftCommunity {
  String actor = 'one';
  int uploads = 0, saves = 0;
  int? failUpload;
  bool published = false;

  @override
  String? get userId => actor;

  @override
  Future<String> uploadPhoto(String postId, Uint8List bytes) async {
    uploads++;
    if (uploads == failUpload) {
      throw const FormatException('No se pudo subir la foto.');
    }
    return 'one/$postId/photo-$uploads.jpg';
  }

  @override
  Future<Adoption> save(Json payload, {String? id, int? version}) async {
    saves++;
    savedPayload = payload;
    post = Adoption({
      ...payload,
      'id': id ?? 'post',
      'owner_id': 'one',
      'version': (version ?? 0) + 1,
      'status': published ? 'published' : 'draft',
      if (published) '_has_private_draft': true,
    });
    return post;
  }
}

List<XFile> selectedPhotos(int count) => [
  for (var i = 0; i < count; i++)
    XFile.fromData(Uint8List.fromList([i]), name: 'photo-$i.jpg'),
];

void main() {
  testWidgets(
    'health checks are binary and do not assert unknown legacy data',
    (tester) async {
      bool? value;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => PublicationTraitCheck(
                label: 'Vacunado',
                value: value,
                onChanged: (next) => setState(() => value = next),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Por confirmar'), findsNothing);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
      expect(value, isNull);
      await tester.tap(find.text('Vacunado'));
      await tester.pump();
      expect(value, isTrue);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
      await tester.tap(find.text('Vacunado'));
      await tester.pump();
      expect(value, isFalse);
      expect(find.text('Por confirmar'), findsNothing);
    },
  );

  testWidgets(
    'one gallery selection attaches up to five additional photos and preserves the cover',
    (tester) async {
      final repo = BatchPublicationCommunity();
      final picker = BatchPublicationPicker()..files = selectedPhotos(7);
      final cover = repo.post.photos.first;
      await startPublication(
        tester,
        repo,
        '/my-adoptions/post',
        photoPicker: picker,
      );
      await tapPublication(tester, find.text('Continuar'));
      await tapPublication(
        tester,
        find.widgetWithText(OutlinedButton, 'Subir desde galería'),
      );
      expect(picker.calls, 1);
      expect(picker.requestedLimit, 5);
      expect(picker.metadata, isFalse);
      expect(repo.uploads, 5);
      expect(repo.post.photos.length, 6);
      expect(repo.post.photos.first, cover);
      expect(
        find.widgetWithText(OutlinedButton, 'Subir desde galería'),
        findsNothing,
      );
      expect(
        (await SharedPreferences.getInstance()).getString(
          pendingPhotoKey('one'),
        ),
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a later batch failure retains already saved photos and reports the error',
    (tester) async {
      final repo = BatchPublicationCommunity()..failUpload = 3;
      final picker = BatchPublicationPicker()..files = selectedPhotos(4);
      final cover = repo.post.photos.first;
      await startPublication(
        tester,
        repo,
        '/my-adoptions/post',
        photoPicker: picker,
      );
      await tapPublication(tester, find.text('Continuar'));
      await tapPublication(
        tester,
        find.widgetWithText(OutlinedButton, 'Subir desde galería'),
      );
      expect(repo.uploads, 3);
      expect(repo.post.photos.length, 3);
      expect(repo.post.photos.first, cover);
      expect(find.textContaining('No se pudo subir la foto.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cancelling multi-selection adds no photos', (tester) async {
    final repo = BatchPublicationCommunity();
    final picker = BatchPublicationPicker();
    await startPublication(
      tester,
      repo,
      '/my-adoptions/post',
      photoPicker: picker,
    );
    await tapPublication(tester, find.text('Continuar'));
    await tapPublication(
      tester,
      find.widgetWithText(OutlinedButton, 'Subir desde galería'),
    );
    expect(repo.uploads, 0);
    expect(repo.post.photos.length, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an obsolete picker result cannot upload into another account', (
    tester,
  ) async {
    final repo = BatchPublicationCommunity();
    final picker = BatchPublicationPicker()..pending = Completer<List<XFile>>();
    await startPublication(
      tester,
      repo,
      '/my-adoptions/post',
      photoPicker: picker,
    );
    await tapPublication(tester, find.text('Continuar'));
    final gallery = find.widgetWithText(OutlinedButton, 'Subir desde galería');
    await tester.ensureVisible(gallery);
    await tester.tap(gallery);
    await tester.pump();
    repo.actor = 'two';
    picker.pending!.complete(selectedPhotos(2));
    await tester.pumpAndSettle();
    expect(repo.uploads, 0);
    expect(repo.post.photos.length, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'published editor saves a private proposal without duplicate lifecycle actions',
    (tester) async {
      final repo = BatchPublicationCommunity()..published = true;
      repo.post = Adoption({...repo.post.data, 'status': 'published'});
      await startPublication(tester, repo, '/my-adoptions/post');
      expect(find.text('Marcar adopción realizada'), findsNothing);
      expect(find.text('Retirar publicación'), findsNothing);
      expect(find.textContaining('Descartar cambios y cargar'), findsNothing);
      expect(
        find.textContaining('La versión aprobada sigue activa.'),
        findsOneWidget,
      );
      await tapPublication(tester, find.text('Guardar cambios'));
      expect(repo.post.status, 'published');
      expect(repo.post.data['_has_private_draft'], isTrue);
      expect(
        find.textContaining('Guardamos tus cambios privados.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'submission confirmation uses white frost and accessible orange actions',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showPublicationSubmittedDialog(context),
                child: const Text('Enviar'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Enviar'));
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(
        tester.widget<AlertDialog>(find.byType(AlertDialog)).backgroundColor,
        Colors.white,
      );
      final check = tester.widget<Icon>(
        find.byIcon(Icons.check_circle_outline),
      );
      expect(check.color, DopmiTokens.orange);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Entendido'),
      );
      expect(
        button.style!.backgroundColor!.resolve({}),
        DopmiTokens.orangeButton,
      );
      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
