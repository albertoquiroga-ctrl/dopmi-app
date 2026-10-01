import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/adoption/publication_frame.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
