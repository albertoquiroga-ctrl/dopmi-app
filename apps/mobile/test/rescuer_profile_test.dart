import 'package:dopmi_mobile/features/profile/phone_verification_repository.dart';

import 'profile_test_identity.dart';

import 'dart:async';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/profile/rescuer_profile_repository.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fake_identity_repository.dart';
import 'community_test.dart' show FakeCommunity;

class FakeRescuerProfile implements RescuerProfileRepository {
  Json value = {
    'id': 'profile-one',
    'owner_id': 'owner-one',
    'display_name': 'Refugio Luna',
    'bio': 'Rescate responsable.',
    'city': 'Monterrey',
    'region': 'Nuevo León',
    'instagram_url': '',
    'facebook_url': '',
    'avatar_path': '',
    'status': 'changes_requested',
    'review_feedback': 'Aclara la ciudad.',
    'version': 3,
  };
  int saves = 0;
  bool failLoad = false;
  @override
  String? get userId => 'owner-one';
  @override
  Future<Json?> load() async {
    if (failLoad) throw StateError('offline');
    return value;
  }

  @override
  Future<Json> save(Json payload, {int? version}) async {
    saves++;
    value = {...value, ...payload, 'status': 'draft', 'version': version! + 1};
    return value;
  }

  @override
  Future<Json> transition(int version, String action) async {
    value = {
      ...value,
      'status': action == 'submit' ? 'submitted' : 'draft',
      'version': version + 1,
      'review_feedback': '',
    };
    return value;
  }

  @override
  Future<String> avatarUrl(String path) async => 'https://example.test/avatar';
  @override
  Future<String> uploadAvatar(Uint8List bytes) async => 'owner/avatar.jpg';
}

void main() {
  testWidgets(
    'photo picker prevents duplicate taps and retains draft on cancellation and failure',
    (tester) async {
      final repo = FakeRescuerProfile();
      repo.failLoad = true;
      final identity = FakeIdentityRepository()
        ..user = const Identity('owner-one', 'ana@example.test', verified: true)
        ..profile = const Profile(
          id: 'owner-one',
          name: 'Ana',
          phone: '',
          city: 'Monterrey',
          mode: 'rescuer',
          intent: 'rescue',
          status: 'active',
          termsVersion: currentTermsVersion,
          privacyVersion: currentPrivacyVersion,
          adultConfirmed: true,
        );
      addTearDown(() async => identity.changes.close());
      const channel = MethodChannel('plugins.flutter.io/image_picker');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var calls = 0;
      var selection = Completer<String?>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method != 'pickImage') return null;
        calls++;
        final args = Map<String, dynamic>.from(call.arguments as Map);
        expect(args['source'], 1);
        expect(args['imageQuality'], 90);
        expect(args['requestFullMetadata'], isFalse);
        return selection.future;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            phoneVerificationRepositoryProvider.overrideWithValue(
              EditorTestPhone(),
            ),
            rescuerProfileRepositoryProvider.overrideWithValue(repo),
            identityRepositoryProvider.overrideWithValue(identity),
            communityRepositoryProvider.overrideWithValue(FakeCommunity()),
            routerInitialLocationProvider.overrideWithValue(
              '/rescuer/profile/edit',
            ),
          ],
          child: const DopmiApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('public-profile-photo')), findsNothing);
      expect(find.text('Guardar borrador'), findsNothing);
      expect(repo.saves, 0);
      repo.failLoad = false;
      await tester.tap(find.text('Volver a intentar'));
      await tester.pumpAndSettle();
      final name = find.byKey(const ValueKey('public-profile-Nombre'));
      await tester.scrollUntilVisible(
        name,
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(tester.element(name), alignment: .5);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(name).controller!.text, 'Refugio Luna');
      await tester.enterText(name, 'Borrador conservado');
      final editor = find.descendant(
        of: name,
        matching: find.byType(EditableText),
      );
      expect(tester.widget<EditableText>(editor).focusNode.hasFocus, isTrue);
      await tester.drag(find.byType(ListView).first, const Offset(0, -80));
      await tester.pumpAndSettle();
      expect(tester.widget<EditableText>(editor).focusNode.hasFocus, isFalse);
      final photo = find.byKey(const ValueKey('public-profile-photo'));
      await tester.scrollUntilVisible(
        photo,
        -160,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(tester.element(photo), alignment: .5);
      await tester.pumpAndSettle();
      final tap = tester.widget<InkWell>(photo).onTap!;
      tap();
      tap();
      await tester.pump();
      expect(calls, 1);
      selection.complete(null);
      await tester.pumpAndSettle();
      expect(repo.saves, 0);
      expect(tester.widget<InkWell>(photo).onTap, isNotNull);
      selection = Completer<String?>();
      await tester.tap(photo);
      await tester.pump();
      selection.completeError(PlatformException(code: 'photo_access_denied'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(repo.saves, 0);
      await tester.scrollUntilVisible(
        name,
        160,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester.widget<TextField>(name).controller!.text,
        'Borrador conservado',
      );
      await tester.scrollUntilVisible(
        photo,
        -160,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(tester.element(photo), alignment: .5);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.widget<InkWell>(photo).onTap, isNotNull);
      selection = Completer<String?>();
      await tester.tap(photo);
      await tester.pump();
      selection.complete(null);
      await tester.pumpAndSettle();
      expect(calls, 3);
      expect(repo.saves, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('corrige, guarda y envía el perfil público sin datos privados', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeRescuerProfile();
    final identity = FakeIdentityRepository()
      ..user = const Identity('owner-one', 'ana@example.test', verified: true)
      ..profile = const Profile(
        id: 'owner-one',
        name: 'Ana',
        phone: '',
        city: 'Monterrey',
        mode: 'rescuer',
        intent: 'rescue',
        status: 'active',
        termsVersion: currentTermsVersion,
        privacyVersion: currentPrivacyVersion,
        adultConfirmed: true,
      );
    addTearDown(() async => identity.changes.close());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          phoneVerificationRepositoryProvider.overrideWithValue(
            EditorTestPhone(),
          ),
          rescuerProfileRepositoryProvider.overrideWithValue(repo),
          identityRepositoryProvider.overrideWithValue(identity),
          communityRepositoryProvider.overrideWithValue(FakeCommunity()),
          routerInitialLocationProvider.overrideWithValue(
            '/rescuer/profile/edit',
          ),
        ],
        child: const DopmiApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Aclara la ciudad.'), findsOneWidget);
    expect(find.text('ana@example.test'), findsOneWidget);
    final publicPhone = find.byKey(
      const ValueKey('public-profile-Tel\u00e9fono p\u00fablico'),
    );
    await tester.scrollUntilVisible(
      publicPhone,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.widget<TextField>(publicPhone).controller!.text, isEmpty);
    expect(repo.value['public_email'], isNull);
    expect(repo.value['public_phone'], isNull);
    final name = find.byKey(const ValueKey('public-profile-Nombre'));
    await tester.scrollUntilVisible(
      name,
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(name, 'Érika');
    await tester.pumpAndSettle();
    final photoCard = find.byKey(const ValueKey('public-profile-photo'));
    await tester.scrollUntilVisible(
      photoCard,
      -160,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(tester.element(photoCard), alignment: .5);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: photoCard, matching: find.text('É')),
      findsOneWidget,
    );
    final city = find.byKey(const ValueKey('public-profile-Ciudad'));
    await tester.scrollUntilVisible(
      city,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(city, 'San Pedro Garza García');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final submit = find.text('Enviar a revisión');
    await tester.scrollUntilVisible(
      submit,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    expect(submit.hitTestable(), findsOneWidget);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(repo.saves, 1);
    expect(repo.value['display_name'], 'Érika');
    expect(repo.value['city'], 'San Pedro Garza García');
    expect(repo.value['status'], 'submitted');
    final submittedStatus = find.textContaining('Estado: En revisión');
    await tester.scrollUntilVisible(
      submittedStatus,
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(submittedStatus),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    expect(submittedStatus.hitTestable(), findsOneWidget);
    final withdraw = find.text('Retirar de revisión');
    await tester.scrollUntilVisible(
      withdraw,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(tester.element(withdraw), alignment: .5);
    await tester.pumpAndSettle();
    expect(withdraw.hitTestable(), findsOneWidget);
    final cancel = find.widgetWithText(OutlinedButton, 'Cancelar');
    await tester.scrollUntilVisible(
      cancel,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final cancelContext = tester.element(cancel);
    await Scrollable.of(cancelContext).position
        .ensureVisible(cancelContext.findRenderObject()!, alignment: .5);
    await tester.pumpAndSettle();
    final receipt = find.byType(SnackBar);
    expect(receipt, findsOneWidget);
    expect(find.text('Enviamos tu perfil a revisión.'), findsOneWidget);
    expect(tester.getRect(receipt).overlaps(tester.getRect(cancel)), isTrue);
    // The visible submission receipt temporarily covers the last list action.
    await tester.pump(
      tester.widget<SnackBar>(receipt).duration +
          const Duration(milliseconds: 500),
    );
    await tester.pumpAndSettle();
    expect(receipt, findsNothing);
    expect(cancel.hitTestable(), findsOneWidget);
    final router = GoRouter.of(tester.element(cancel));
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/profile');
    expect(repo.saves, 1);
    expect(repo.value['status'], 'submitted');
  });
}
