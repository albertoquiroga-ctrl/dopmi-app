import 'dart:async';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/core/config.dart';
import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/identity/auth_screens.dart';
import 'package:dopmi_mobile/features/identity/experience_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_controller.dart';
import 'package:dopmi_mobile/features/identity/identity_repository.dart';
import 'package:dopmi_mobile/features/profile/account_photo_repository.dart';
import 'package:dopmi_mobile/features/profile/profile_screen.dart'
    show ConsentScreen;
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_test.dart' show FakeCommunity;
import 'fake_account_photo_repository.dart';
import 'fake_identity_repository.dart';
import 'rescue_test.dart' show FakeRescue;

const _account = Identity('one', 'ana@example.test', verified: true);
const _socialConfig = AppConfig(
  url: 'https://example.supabase.co',
  key: 'test',
  redirect: 'io.dopmi.app://auth/callback',
  googleEnabled: true,
);

Profile _profile({
  String id = 'one',
  String mode = 'donor',
  String intent = 'adopt',
  bool accepted = true,
}) => Profile(
  id: id,
  name: 'Ana',
  phone: '555',
  city: 'Monterrey',
  mode: mode,
  intent: intent,
  status: 'active',
  termsVersion: accepted ? currentTermsVersion : null,
  privacyVersion: accepted ? currentPrivacyVersion : null,
  adultConfirmed: accepted,
);

class _SocialIdentity extends FakeIdentityRepository {
  final providers = <String>[];
  bool failOAuth = false;

  @override
  Future<void> oauth(String provider) async {
    providers.add(provider);
    if (failOAuth) throw StateError('provider_not_configured');
    // A browser launch returns before the authentication callback arrives.
  }
}

Future<void> _tasks() => Future<void>.delayed(Duration.zero);

void main() {
  Future<ProviderContainer> start(
    WidgetTester tester,
    FakeIdentityRepository repo,
    String location,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        configProvider.overrideWithValue(_socialConfig),
        identityRepositoryProvider.overrideWithValue(repo),
        accountPhotoRepositoryProvider.overrideWithValue(
          emptyAccountPhotoRepository(repo),
        ),
        communityRepositoryProvider.overrideWithValue(FakeCommunity()),
        rescueRepositoryProvider.overrideWithValue(FakeRescue()),
        routerInitialLocationProvider.overrideWithValue(location),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await repo.changes.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DopmiApp()),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> login(WidgetTester tester, {bool settle = true}) async {
    await tester.enterText(
      find.byType(TextFormField).first,
      'ana@example.test',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'Password1234');
    final button = find.widgetWithText(FilledButton, 'Inicia sesión');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  for (final entry in [
    (intent: 'rescue', saved: 'donor', expected: 'rescuer', route: '/rescuer'),
    (intent: 'adopt', saved: 'rescuer', expected: 'donor', route: '/adoptions'),
    (
      intent: 'donate',
      saved: 'rescuer',
      expected: 'donor',
      route: '/adoptions',
    ),
  ]) {
    testWidgets('login honors the current explicit ${entry.intent} choice', (
      tester,
    ) async {
      final repo = FakeIdentityRepository()
        ..profile = _profile(mode: entry.saved);
      final container = await start(
        tester,
        repo,
        '/login?intent=${entry.intent}',
      );
      await login(tester);
      expect(repo.experienceRequests, [entry.expected]);
      expect(repo.profile.mode, entry.expected);
      expect(repo.profile.name, 'Ana');
      expect(repo.profile.city, 'Monterrey');
      expect(container.read(routerProvider).state.uri.path, entry.route);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('login without a choice retains the saved mode', (tester) async {
    final repo = FakeIdentityRepository()
      ..profile = _profile(mode: 'rescuer', intent: 'adopt');
    final container = await start(tester, repo, '/login');
    await login(tester);
    expect(repo.experienceRequests, isEmpty);
    expect(repo.profile.mode, 'rescuer');
    expect(container.read(routerProvider).state.uri.path, '/rescuer');
    expect(tester.takeException(), isNull);
  });

  for (final location in ['/onboarding', '/onboarding?intent=garbage']) {
    testWidgets('onboarding cannot manufacture an adopt choice: $location', (
      tester,
    ) async {
      final repo = FakeIdentityRepository()
        ..profile = _profile(mode: 'rescuer', intent: 'adopt');
      final container = await start(tester, repo, location);
      final header = find.widgetWithText(TextButton, 'Ya tengo cuenta');
      await tester.ensureVisible(header);
      await tester.tap(header);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AuthFormScreen>(find.byType(AuthFormScreen))
            .experienceIntent,
        isNull,
      );
      await login(tester);
      expect(repo.experienceRequests, isEmpty);
      expect(repo.profile.mode, 'rescuer');
      expect(container.read(routerProvider).state.uri.path, '/rescuer');
      expect(tester.takeException(), isNull);
    });
  }

  for (final entry in [
    (
      intent: 'rescue',
      saved: 'donor',
      expected: 'rescuer',
      route: '/rescuer',
      cta: 'Empezar',
    ),
    (
      intent: 'adopt',
      saved: 'rescuer',
      expected: 'donor',
      route: '/adoptions',
      cta: 'Quiero adoptar',
    ),
  ]) {
    testWidgets(
      'onboarding and account bridges preserve explicit ${entry.intent}',
      (tester) async {
        final repo = FakeIdentityRepository()
          ..profile = _profile(mode: entry.saved);
        final container = await start(
          tester,
          repo,
          '/onboarding?intent=${entry.intent}',
        );
        final next = find.widgetWithText(FilledButton, 'Continuar');
        await tester.ensureVisible(next);
        await tester.tap(next);
        await tester.pumpAndSettle();
        final finish = find.widgetWithText(FilledButton, entry.cta);
        await tester.ensureVisible(finish);
        await tester.tap(finish);
        await tester.pumpAndSettle();
        expect(container.read(routerProvider).state.uri.path, '/start');
        final signIn = find.widgetWithText(TextButton, 'Inicia sesión');
        await tester.ensureVisible(signIn);
        await tester.tap(signIn);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<AuthFormScreen>(find.byType(AuthFormScreen))
              .experienceIntent,
          entry.intent,
        );
        await login(tester);
        expect(repo.experienceRequests, [entry.expected]);
        expect(repo.profile.mode, entry.expected);
        expect(container.read(routerProvider).state.uri.path, entry.route);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'donate onboarding header preserves its explicit account choice',
    (tester) async {
      final repo = FakeIdentityRepository()
        ..profile = _profile(mode: 'rescuer');
      final container = await start(tester, repo, '/onboarding?intent=donate');
      final header = find.widgetWithText(TextButton, 'Ya tengo cuenta');
      await tester.ensureVisible(header);
      await tester.tap(header);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AuthFormScreen>(find.byType(AuthFormScreen))
            .experienceIntent,
        'donate',
      );
      await login(tester);
      expect(repo.experienceRequests, ['donor']);
      expect(container.read(routerProvider).state.uri.path, '/adoptions');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('switching auth forms cannot manufacture an adopt choice', (
    tester,
  ) async {
    final repo = FakeIdentityRepository()..profile = _profile(mode: 'rescuer');
    final container = await start(tester, repo, '/login');
    final signup = find.widgetWithText(TextButton, 'Crear cuenta');
    await tester.ensureVisible(signup);
    await tester.tap(signup);
    await tester.pumpAndSettle();
    final signIn = find.widgetWithText(TextButton, 'Inicia sesión');
    await tester.ensureVisible(signIn);
    await tester.tap(signIn);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AuthFormScreen>(find.byType(AuthFormScreen))
          .experienceIntent,
      isNull,
    );
    await login(tester);
    expect(repo.experienceRequests, isEmpty);
    expect(container.read(routerProvider).state.uri.path, '/rescuer');
  });

  for (final route in ['/start', '/login', '/signup']) {
    testWidgets('deferred social callback honors the choice from $route', (
      tester,
    ) async {
      final repo = _SocialIdentity()..profile = _profile();
      final container = await start(tester, repo, '$route?intent=rescue');
      final google = find.byTooltip('Continuar con Google');
      await tester.ensureVisible(google);
      await tester.tap(google);
      await tester.pumpAndSettle();
      expect(repo.providers, ['google']);
      expect(repo.current, isNull);
      expect(repo.experienceRequests, isEmpty);
      repo.emit(const IdentityEvent(_account));
      await tester.pumpAndSettle();
      expect(repo.experienceRequests, ['rescuer']);
      expect(container.read(routerProvider).state.uri.path, '/rescuer');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'selected home waits for persistence and retries the real failure',
    (tester) async {
      final repo = FakeIdentityRepository()
        ..profile = _profile()
        ..failSave = true;
      final container = await start(tester, repo, '/login?intent=rescue');
      await login(tester);
      final experience = container.read(experienceProvider);
      expect(container.read(routerProvider).state.uri.path, '/home');
      expect(experience.value, AccountExperience.donor);
      expect(repo.profile.mode, 'donor');
      expect(experience.authenticationError, isNotNull);
      expect(find.text('Reintentar'), findsOneWidget);
      repo.failSave = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(repo.experienceRequests, ['rescuer', 'rescuer']);
      expect(experience.authenticationError, isNull);
      expect(experience.value, AccountExperience.rescuer);
      expect(container.read(routerProvider).state.uri.path, '/rescuer');
    },
  );

  testWidgets('pending mode never renders a false selected home', (
    tester,
  ) async {
    final response = Completer<Profile>();
    final repo = FakeIdentityRepository()
      ..profile = _profile()
      ..experienceResult = response.future;
    final container = await start(tester, repo, '/login?intent=rescue');
    await login(tester, settle: false);
    await tester.pump();
    final experience = container.read(experienceProvider);
    expect(repo.experienceRequests, ['rescuer']);
    expect(experience.loading, isTrue);
    expect(experience.value, AccountExperience.donor);
    expect(container.read(routerProvider).state.uri.path, '/home');
    repo.profile = _profile(mode: 'rescuer');
    response.complete(repo.profile);
    await tester.pumpAndSettle();
    expect(container.read(routerProvider).state.uri.path, '/rescuer');
    expect(experience.value, AccountExperience.rescuer);
  });

  testWidgets('a social choice cannot bypass current legal consent', (
    tester,
  ) async {
    final repo = _SocialIdentity()..profile = _profile(accepted: false);
    final container = await start(tester, repo, '/start?intent=rescue');
    final google = find.byTooltip('Continuar con Google');
    await tester.ensureVisible(google);
    await tester.tap(google);
    await tester.pumpAndSettle();
    repo.emit(const IdentityEvent(_account));
    await tester.pumpAndSettle();
    expect(container.read(routerProvider).state.uri.path, '/consent');
    expect(find.byType(ConsentScreen), findsOneWidget);
    expect(repo.consentCount, 0);
    expect(repo.profile.adultConfirmed, isFalse);
  });

  testWidgets('returning from recovery preserves only its visual context', (
    tester,
  ) async {
    final repo = FakeIdentityRepository()..profile = _profile();
    final container = await start(tester, repo, '/login?intent=rescue');
    final forgot = find.widgetWithText(TextButton, 'Olvidé mi contraseña');
    await tester.ensureVisible(forgot);
    await tester.tap(forgot);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    final screen = tester.widget<AuthFormScreen>(find.byType(AuthFormScreen));
    expect(screen.intent, 'rescue');
    expect(screen.experienceIntent, isNull);
    await login(tester);
    expect(repo.experienceRequests, isEmpty);
    expect(container.read(routerProvider).state.uri.path, '/adoptions');
  });

  for (final leave in [false, true]) {
    testWidgets(
      'an abandoned social choice cannot affect a later account: $leave',
      (tester) async {
        final repo = _SocialIdentity()
          ..profile = _profile()
          ..failOAuth = !leave;
        final container = await start(tester, repo, '/login?intent=rescue');
        final google = find.byTooltip('Continuar con Google');
        await tester.ensureVisible(google);
        await tester.tap(google);
        await tester.pumpAndSettle();
        if (leave) {
          container.read(routerProvider).go('/welcome');
          await tester.pumpAndSettle();
        }
        repo.emit(const IdentityEvent(_account));
        await tester.pumpAndSettle();
        expect(repo.experienceRequests, isEmpty);
        expect(
          container.read(experienceProvider).value,
          AccountExperience.donor,
        );
      },
    );
  }

  test('unverified identities cannot persist a pending choice', () async {
    final repo = FakeIdentityRepository()..profile = _profile();
    final identity = IdentityController(repo);
    await identity.initialize();
    final experience = ExperienceController(identity);
    addTearDown(() async {
      experience.dispose();
      identity.dispose();
      await repo.changes.close();
    });
    experience.prepareAuthentication('rescue');
    repo.emit(
      const IdentityEvent(Identity('one', 'ana@example.test', verified: false)),
    );
    await _tasks();
    expect(repo.loads, 0);
    expect(repo.experienceRequests, isEmpty);
    repo.emit(const IdentityEvent(_account));
    await _tasks();
    expect(repo.experienceRequests, ['rescuer']);
    expect(experience.value, AccountExperience.rescuer);
  });

  test(
    'an old owner and request cannot replace a newer account mode',
    () async {
      final response = Completer<Profile>();
      final repo = FakeIdentityRepository()
        ..profile = _profile()
        ..experienceResult = response.future;
      final identity = IdentityController(repo);
      await identity.initialize();
      final experience = ExperienceController(identity);
      addTearDown(() async {
        experience.dispose();
        identity.dispose();
        await repo.changes.close();
      });
      final oldRequest = experience.prepareAuthentication('adopt');
      experience.prepareAuthentication('rescue');
      experience.cancelAuthentication(oldRequest);
      repo.emit(const IdentityEvent(_account));
      await _tasks();
      expect(repo.experienceRequests, ['rescuer']);
      repo
        ..profile = _profile(id: 'two', intent: 'rescue')
        ..experienceResult = null;
      repo.emit(
        const IdentityEvent(
          Identity('two', 'bea@example.test', verified: true),
        ),
      );
      await _tasks();
      response.complete(_profile(mode: 'rescuer'));
      await _tasks();
      expect(experience.profile?.id, 'two');
      expect(experience.value, AccountExperience.donor);
      expect(experience.authenticationError, isNull);
      expect(repo.experienceRequests, ['rescuer']);
    },
  );

  test(
    'consumed choice never overwrites later switches or a reopened session',
    () async {
      final repo = FakeIdentityRepository()
        ..profile = _profile(intent: 'rescue');
      final identity = IdentityController(repo);
      await identity.initialize();
      var experience = ExperienceController(identity);
      addTearDown(() async {
        experience.dispose();
        identity.dispose();
        await repo.changes.close();
      });
      experience.prepareAuthentication('rescue');
      repo.emit(const IdentityEvent(_account));
      await _tasks();
      expect(experience.value, AccountExperience.rescuer);
      final switched = await repo.setExperience('donor');
      experience.applyProfile(switched);
      expect(experience.value, AccountExperience.donor);
      experience.dispose();
      experience = ExperienceController(identity);
      await _tasks();
      expect(experience.value, AccountExperience.donor);
      expect(repo.experienceRequests, ['rescuer', 'donor']);
      expect(experience.profile?.intent, 'rescue');
    },
  );
}
