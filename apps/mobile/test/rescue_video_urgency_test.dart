import 'package:dopmi_mobile/core/media/video_repository.dart';
import 'package:dopmi_mobile/core/media/video_upload.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_videos.dart';
import 'package:dopmi_mobile/features/rescue/urgency_complement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class UrgencyVideoRepository extends VideoRepository {
  UrgencyVideoRepository()
    : super(
        identity: () => 'owner:session',
        invoke: (_) async => throw const VideoFailure('not_uploading'),
      );
  bool allowed = true;
  List<Map<String, dynamic>> assets = [];
  final canceled = <String>[];
  int policies = 0;
  @override
  Future<VideoPolicy> policy(String parentId) async {
    policies++;
    return VideoPolicy(
      enabled: true,
      thanksRequired: false,
      urgencyAllowed: allowed,
      assets: List.of(assets),
    );
  }

  @override
  Future<void> cancel(VideoUploadTask task) async {
    canceled.add(task.assetId!);
    assets = [];
    task.cancel();
  }
}

RescueRecord urgencyRecord({String kind = 'case'}) =>
    RescueRecord({'id': 'case', 'kind': kind, 'status': 'draft', 'version': 3});

void main() {
  testWidgets(
    'six photos disable new camera/gallery but allow an existing urgency photo and cancel preserves it',
    (tester) async {
      final files = [
        for (var i = 0; i < 6; i++)
          <String, dynamic>{'role': 'public', 'path': 'owner/case/photo-$i'},
      ];
      var selected = 'owner/case/photo-0';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  final value = await showModalBottomSheet<String>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => UrgencyPhotoChoices(files: files),
                  );
                  if (value != null) selected = value;
                },
                child: const Text('Cambiar complemento'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Cambiar complemento'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Ya tienes 6 fotos. Elige una foto del caso o retira una para añadir otra.',
        ),
        findsOneWidget,
      );
      for (final label in ['Tomar foto', 'Elegir de galería']) {
        final tile = tester.widget<ListTile>(
          find.widgetWithText(ListTile, label),
        );
        expect(tile.enabled, isFalse);
        expect(tile.onTap, isNull);
      }
      await tester.scrollUntilVisible(
        find.text('Usar foto del caso 6'),
        100,
        scrollable: find.descendant(
          of: find.byType(UrgencyPhotoChoices),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usar foto del caso 6'));
      await tester.pumpAndSettle();
      expect(selected, 'owner/case/photo-5');
      expect(files.length, 6);
      await tester.tap(find.text('Cambiar complemento'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(UrgencyPhotoChoices))).pop();
      await tester.pumpAndSettle();
      expect(selected, 'owner/case/photo-5');
      expect(
        files.map((file) => file.keys.toSet()),
        everyElement({'role', 'path'}),
      );
    },
  );
  test('only urgent veterinary or medicine needs enable a complement and the pointer must remain in public attachments', () {
    expect(
      hasUrgentCaseNeed([
        {'type': 'food', 'urgent': true},
      ], []),
      isFalse,
    );
    expect(
      hasUrgentCaseNeed([
        {'type': 'medicine', 'urgent': false},
      ], []),
      isFalse,
    );
    expect(
      hasUrgentCaseNeed([
        {'type': 'veterinary', 'urgent': true},
      ], []),
      isTrue,
    );
    expect(
      hasUrgentCaseNeed([], [
        RescueRecord({
          'id': 'expense',
          'kind': 'expense',
          'status': 'draft',
          'public_data': {'category': 'medicine'},
          'private_data': {'urgency_reason': 'Atención inmediata'},
        }),
      ]),
      isTrue,
    );
    expect(
      validUrgencyPhoto('photo', [
        {'role': 'public', 'path': 'photo'},
      ]),
      'photo',
    );
    expect(
      validUrgencyPhoto('photo', [
        {'role': 'proof', 'path': 'photo'},
      ]),
      isNull,
    );
    expect(validUrgencyPhoto('photo', []), isNull);
  });
  Future<void> mount(
    WidgetTester tester,
    UrgencyVideoRepository repository, {
    bool eligible = true,
    String kind = 'case',
    Future<void> Function()? onPhoto,
  }) async {
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rescueVideosRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: UrgencyComplement(
                record: urgencyRecord(kind: kind),
                eligible: eligible,
                photoPath: null,
                onSave: () async {},
                onPhoto: onPhoto ?? () async {},
                onRemovePhoto: () async {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'server policy can deny urgency despite the local draft condition',
    (tester) async {
      final repository = UrgencyVideoRepository()..allowed = false;
      await mount(tester, repository);
      expect(find.text('Añadir foto de urgencia'), findsNothing);
      expect(find.text('Añadir video de urgencia'), findsNothing);
      expect(find.byType(VideoUpload), findsNothing);
    },
  );
  testWidgets('ineligible cases and expenses do not offer urgency media', (
    tester,
  ) async {
    final repo = UrgencyVideoRepository();
    await mount(tester, repo, eligible: false);
    expect(find.text('Añadir video de urgencia'), findsNothing);
    expect(repo.policies, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final expense = UrgencyVideoRepository();
    await mount(tester, expense, kind: 'expense');
    expect(find.text('Añadir foto de urgencia'), findsNothing);
    expect(expense.policies, 0);
  });
  testWidgets(
    'an empty optional complement offers either photo or video and respects the server gate',
    (tester) async {
      final repo = UrgencyVideoRepository();
      var photos = 0;
      await mount(
        tester,
        repo,
        onPhoto: () async {
          photos++;
        },
      );
      expect(find.text('Añadir foto de urgencia'), findsOneWidget);
      expect(find.text('Añadir video de urgencia'), findsOneWidget);
      await tester.tap(find.text('Añadir foto de urgencia'));
      await tester.pumpAndSettle();
      expect(photos, 1);
      expect(find.byType(VideoUpload), findsNothing);
      await tester.tap(find.text('Añadir video de urgencia'));
      await tester.pumpAndSettle();
      expect(find.byType(VideoUpload), findsOneWidget);
      expect(find.text('Añadir foto de urgencia'), findsNothing);
    },
  );
  testWidgets('a video is canceled before the photo option becomes available', (
    tester,
  ) async {
    final repo = UrgencyVideoRepository()
      ..assets = [
        {
          'id': 'clip',
          'parent_id': 'case',
          'parent_version': 3,
          'purpose': 'urgency',
          'technical_state': 'processing',
          'moderation_state': 'pending',
          'request_key': '00000000-0000-0000-0000-000000000001',
          'bytes': 3,
          'matches_current_content': true,
        },
      ];
    await mount(tester, repo);
    expect(find.text('Añadir foto de urgencia'), findsNothing);
    await tester.ensureVisible(find.text('Quitar video y cambiar a foto'));
    await tester.tap(find.text('Quitar video y cambiar a foto'));
    await tester.pumpAndSettle();
    expect(repo.canceled, ['clip']);
    expect(find.text('Añadir foto de urgencia'), findsOneWidget);
  });
}
