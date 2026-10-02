import 'features/rescue/publish_choice_screen.dart';
import 'features/adoption/community_ui.dart';
import 'features/payments/guardian_repository.dart';
import 'features/payments/guardian_promotion_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/ui.dart';
import 'core/navigation.dart';
import 'core/measurement.dart';
import 'features/identity/experience_controller.dart';
import 'features/identity/experience_landing.dart';
import 'features/identity/auth_screens.dart';
import 'features/identity/identity_controller.dart';
import 'features/identity/identity_repository.dart';
import 'features/identity/onboarding_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/profile/profile_overview.dart';
import 'features/profile/account_privacy_screen.dart';
import 'features/profile/impact_screen.dart';
import 'features/profile/information_screens.dart';
import 'features/profile/rescuer_profile_edit_screen.dart';
import 'features/adoption/catalog_screens.dart';
import 'features/adoption/discovery_screen.dart';
import 'features/adoption/saved_screen.dart';
import 'features/adoption/publication_screens.dart';
import 'features/communication/message_screens.dart';
import 'features/rescue/rescue_screens.dart';
import 'features/rescue/case_update_screens.dart';
import 'features/payments/payment_screens.dart';
import 'features/payments/guardian_screen.dart';
import 'features/payments/guardian_history_screen.dart';
import 'features/adoption/community_repository.dart' show Json;

final routerInitialLocationProvider = Provider<String>((ref) => '/welcome');

final routerProvider = Provider<GoRouter>((ref) {
  final identity = ref.watch(identityControllerProvider);
  final experience = ref.read(experienceProvider);
  final session = ref.watch(navigationSessionProvider);
  String? restoringPath;
  final router = GoRouter(
    initialLocation: session == 0
        ? ref.watch(routerInitialLocationProvider)
        : ref.read(navigationSessionProvider.notifier).location,
    overridePlatformDefaultLocation: session != 0,
    refreshListenable: Listenable.merge([identity, experience]),
    redirect: (_, state) {
      // Supabase restores an existing local session synchronously. Keep the
      // requested route mounted while the server validates it so a concurrent
      // profile refresh cannot replace it with the loading route.
      if (identity.loading && identity.repository.current != null) return null;
      if (identity.loading && state.uri.path != '/loading') {
        restoringPath ??= state.uri.toString();
      }
      final desired = identity.loading
          ? state.uri.path
          : Uri.parse(restoringPath ?? state.uri.toString()).path;
      var target = identity.redirect(desired);
      if (target == null &&
          identity.identity?.verified == true &&
          experience.profile != null) {
        final profile = experience.profile;
        final accepted =
            profile?.termsVersion == currentTermsVersion &&
            profile?.privacyVersion == currentPrivacyVersion &&
            profile?.adultConfirmed == true;
        final consentExempt =
            desired == '/consent' ||
            desired == '/terms' ||
            desired == '/account-privacy' ||
            desired == '/guardian' ||
            desired == '/guardian/history';
        if (!accepted && !consentExempt) target = '/consent';
        if (accepted && desired == '/consent') target = '/home';
      }
      if (target == '/adoptions' && identity.identity?.verified == true) {
        target = '/home';
      }
      if (!identity.loading && restoringPath != null) {
        final restored = restoringPath;
        restoringPath = null;
        return target ?? (restored != state.uri.toString() ? restored : null);
      }
      return target;
    },
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, _) => const ExperienceLandingScreen(),
      ),
      GoRoute(
        path: '/basic-info',
        builder: (_, _) =>
            BasicInfoScreen(key: ValueKey(identity.identity?.id)),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) =>
            DopmiNavigationHost(shell: shell, child: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/adoptions',
                builder: (_, state) {
                  final owner = state.uri.queryParameters['owner'];
                  return owner == null
                      ? DiscoveryScreen(
                          key: ValueKey(
                            '${identity.identity?.id}:${state.uri}',
                          ),
                        )
                      : CatalogScreen(
                          key: ValueKey(
                            '${identity.identity?.id}:${state.uri}',
                          ),
                          owner: owner,
                        );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/rescue-cases',
                builder: (_, state) => RescueCatalogScreen(
                  key: ValueKey('${identity.identity?.id}:${state.uri}'),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) =>
                    ProfileScreen(key: ValueKey(identity.identity?.id)),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/rescuer',
                builder: (_, state) => RescueHomeScreen(
                  key: ValueKey('${identity.identity?.id}:${state.uri}'),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/my-cases',
                builder: (_, _) =>
                    MyRescueCasesScreen(key: ValueKey(identity.identity?.id)),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/publish',
                builder: (_, _) =>
                    PublishChoiceScreen(key: ValueKey(identity.identity?.id)),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/messages',
                builder: (_, _) =>
                    ThreadsScreen(key: ValueKey(identity.identity?.id)),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        builder: (_, _) => SettingsScreen(key: ValueKey(identity.identity?.id)),
      ),
      GoRoute(
        path: '/settings/account',
        builder: (_, _) =>
            RescuerAccountOptionsScreen(key: ValueKey(identity.identity?.id)),
      ),
      GoRoute(
        path: '/consent',
        builder: (_, _) => ConsentScreen(key: ValueKey(identity.identity?.id)),
      ),
      GoRoute(
        path: '/account-privacy',
        builder: (_, _) =>
            AccountPrivacyScreen(key: ValueKey(identity.identity?.id)),
      ),
      GoRoute(
        path: '/rescuer/profile/edit',
        builder: (_, _) => RescuerPublicProfileEditScreen(
          key: ValueKey(identity.identity?.id),
        ),
      ),
      GoRoute(path: '/help', builder: (_, _) => const HelpScreen()),
      GoRoute(path: '/about', builder: (_, _) => const AboutScreen()),
      GoRoute(
        path: '/transparency',
        builder: (_, _) => const TransparencyScreen(),
      ),
      GoRoute(
        path: '/my-adoptions',
        builder: (_, _) =>
            MyAdoptionsScreen(key: ValueKey(identity.identity?.id)),
      ),
      GoRoute(
        path: '/guardian/history',
        builder: (_, _) =>
            GuardianHistoryScreen(key: ValueKey(identity.identity?.id)),
      ),
      GoRoute(
        path: '/guardian',
        builder: (_, state) => GuardianScreen(
          key: ValueKey(identity.identity?.id),
          initialEnrollment: state.uri.queryParameters['enroll'] == '1',
        ),
      ),
      GoRoute(
        path: '/payments',
        builder: (_, _) =>
            PaymentHistoryScreen(key: ValueKey(identity.identity?.id)),
      ),
      GoRoute(
        path: '/connect',
        builder: (_, _) => ConnectScreen(key: ValueKey(identity.identity?.id)),
      ),
      GoRoute(
        path: '/contribute/:id',
        builder: (_, state) => ContributeScreen(
          state.pathParameters['id']!,
          caseId: state.uri.queryParameters['case'],
          initialCents: int.tryParse(
            state.uri.queryParameters['amount_cents'] ?? '',
          ),
          attempt: state.extra is Json ? state.extra! as Json : null,
          key: ValueKey('${identity.identity?.id}:${state.uri}'),
        ),
      ),
      GoRoute(
        path: '/rescue/:id',
        builder: (_, state) => RescueEditorScreen(
          state.pathParameters['id']!,
          kind:
              [
                'verification',
                'case',
                'expense',
              ].contains(state.uri.queryParameters['kind'])
              ? state.uri.queryParameters['kind']!
              : 'case',
          parent: state.uri.queryParameters['case'],
          showRecord: state.uri.queryParameters['record'] == '1',
          key: ValueKey('${identity.identity?.id}:${state.uri}'),
        ),
      ),
      GoRoute(
        path: '/rescue-file',
        builder: (_, state) => state.extra is String
            ? RescueFileScreen(
                state.extra! as String,
                key: ValueKey('${identity.identity?.id}:${state.extra}'),
              )
            : const PageFrame(
                children: [Notice('Abre el archivo desde su solicitud.')],
              ),
      ),
      GoRoute(
        path: '/rescue-cases/:id',
        builder: (_, state) => RescueCatalogScreen(
          caseId: state.pathParameters['id'],
          key: ValueKey('${identity.identity?.id}:${state.uri}'),
        ),
      ),
      GoRoute(
        path: '/rescue-cases/:id/updates',
        builder: (_, state) => CaseUpdatesManageScreen(
          state.pathParameters['id']!,
          key: ValueKey('${identity.identity?.id}:${state.uri}'),
        ),
        routes: [
          GoRoute(
            path: ':updateId',
            builder: (_, state) => CaseUpdateEditorScreen(
              state.pathParameters['id']!,
              updateId: state.pathParameters['updateId'] == 'new'
                  ? null
                  : state.pathParameters['updateId'],
              key: ValueKey('${identity.identity?.id}:${state.uri}'),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/saved',
        builder: (_, state) => SavedScreen(
          key: ValueKey('${identity.identity?.id}:${state.uri}'),
          initialKind: switch (state.uri.queryParameters['kind']) {
            'donation' => SavedKind.donation,
            'rescuer' => SavedKind.rescuer,
            _ => SavedKind.adoption,
          },
        ),
      ),
      GoRoute(
        path: '/impact/guardian',
        builder: (_, _) => GuardianPromotionScreen(
          key: ValueKey(identity.identity?.id),
          available: ref.read(guardianEnabledProvider),
          navigation: const CommunityNav(3),
        ),
      ),
      GoRoute(
        path: '/impact',
        builder: (_, state) => state.uri.queryParameters['history'] == '1'
            ? ImpactScreen(key: ValueKey(identity.identity?.id))
            : ImpactEntryScreen(key: ValueKey(identity.identity?.id)),
      ),
      GoRoute(
        path: '/adoptions/:id',
        builder: (_, state) => AdoptionDetailScreen(
          state.pathParameters['id']!,
          distanceKm: state.extra is num ? state.extra as num : null,
          key: ValueKey('${identity.identity?.id}:${state.uri}'),
        ),
      ),
      GoRoute(
        path: '/people/:id',
        builder: (_, state) => PublicProfileScreen(state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/my-adoptions/:id',
        builder: (_, state) => PublicationScreen(
          state.pathParameters['id']!,
          rescueCaseId: state.uri.queryParameters['case'],
          key: ValueKey('${identity.identity?.id}:${state.uri}'),
        ),
      ),
      GoRoute(
        path: '/messages/:id',
        builder: (_, state) => ThreadScreen(
          state.pathParameters['id']!,
          key: ValueKey('${identity.identity?.id}:${state.uri}'),
        ),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, _) =>
            NotificationsScreen(key: ValueKey(identity.identity?.id)),
      ),
      GoRoute(
        path: '/loading',
        builder: (_, _) => const PageFrame(
          back: false,
          children: [
            Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Restaurando sesión',
              ),
            ),
          ],
        ),
      ),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (_, state) => OnboardingScreen(
          intent: safeIntent(state.uri.queryParameters['intent']),
        ),
      ),
      GoRoute(
        path: '/start',
        builder: (_, state) => AccountStartScreen(
          intent: safeIntent(state.uri.queryParameters['intent']),
        ),
      ),
      GoRoute(
        path: '/signup',
        builder: (_, state) => AuthFormScreen(
          mode: AuthFormMode.signup,
          intent: safeIntent(state.uri.queryParameters['intent']),
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (_, state) => AuthFormScreen(
          mode: AuthFormMode.login,
          intent: safeIntent(state.uri.queryParameters['intent']),
        ),
      ),
      GoRoute(
        path: '/forgot',
        builder: (_, state) => AuthFormScreen(
          mode: AuthFormMode.forgot,
          intent: safeIntent(state.uri.queryParameters['intent']),
          initialEmail: state.extra is String ? state.extra! as String : null,
        ),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (_, _) => const AuthFormScreen(mode: AuthFormMode.reset),
      ),
      GoRoute(
        path: '/confirm',
        builder: (_, state) => ConfirmationScreen(
          email: state.extra is String ? state.extra! as String : '',
        ),
      ),
      GoRoute(
        path: '/confirm-recovery',
        builder: (_, state) => ConfirmationScreen(
          email: state.extra is String ? state.extra! as String : '',
          recovery: true,
        ),
      ),
      GoRoute(
        path: '/auth/callback',
        builder: (_, _) => const PageFrame(
          back: false,
          children: [Notice('Procesando el enlace…')],
        ),
      ),
      GoRoute(
        path: '/auth-error',
        builder: (_, _) => AuthErrorScreen(identity: identity),
      ),
      GoRoute(path: '/terms', builder: (_, _) => const TermsScreen()),
    ],
    errorBuilder: (context, _) => PageFrame(
      children: [
        const Heading(
          'No encontramos esa página.',
          'Puedes regresar al inicio y continuar.',
        ),
        ActionButton('Ir al inicio', onPressed: () => context.go('/welcome')),
      ],
    ),
  );
  void rememberLocation() {
    if (router.routerDelegate.currentConfiguration.isNotEmpty) {
      ref
          .read(navigationSessionProvider.notifier)
          .rememberLocation(router.state.uri.toString());
    }
  }

  router.routerDelegate.addListener(rememberLocation);
  ref.onDispose(() {
    router.routerDelegate.removeListener(rememberLocation);
    router.dispose();
  });
  return router;
});

class DopmiApp extends ConsumerWidget {
  const DopmiApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final experience = ref.watch(experienceProvider);
    final identityController = ref.watch(identityControllerProvider);
    final identity = identityController.identity;
    final measurement = ref.watch(measurementControllerProvider);
    if (measurement != null && (!measurement.loading || identity != null)) {
      Future.microtask(() => measurement.owner(identity?.id));
    }
    return ListenableBuilder(
      listenable: experience,
      builder: (context, _) => MaterialApp.router(
        title: 'Dopmi',
        debugShowCheckedModeBanner: false,
        theme: dopmiTheme(
          rescuer: experience.value == AccountExperience.rescuer,
        ),
        locale: const Locale('es', 'MX'),
        supportedLocales: const [Locale('es', 'MX')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: router,
        builder: (context, child) {
          final currentIdentity = identityController.identity;
          final path = router.routerDelegate.currentConfiguration.isEmpty
              ? '/loading'
              : router.state.uri.path;
          final profile = experience.profile;
          final accepted =
              profile?.termsVersion == currentTermsVersion &&
              profile?.privacyVersion == currentPrivacyVersion &&
              profile?.adultConfirmed == true;
          final exempt =
              path == '/consent' ||
              path == '/terms' ||
              path == '/account-privacy' ||
              path == '/guardian' ||
              path == '/guardian/history';
          final checkingConsent =
              currentIdentity?.verified == true &&
              experience.loading &&
              profile == null;
          if (checkingConsent && !exempt) {
            return Stack(
              children: [
                if (child != null) Offstage(offstage: true, child: child),
                const Positioned.fill(
                  child: PageFrame(
                    back: false,
                    children: [
                      Center(
                        child: CircularProgressIndicator(
                          semanticsLabel: 'Restaurando sesión',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          // Fail closed in the widget tree as well as in GoRouter. This keeps
          // an authenticated profile from entering the product if its profile
          // request is delayed or fails before redirect reevaluation.
          if (currentIdentity?.verified == true && !accepted && !exempt) {
            return Stack(
              children: [
                if (child != null) Offstage(offstage: true, child: child),
                Positioned.fill(
                  child: ConsentScreen(
                    key: ValueKey(currentIdentity!.id),
                    onTerms: () => router.go('/terms'),
                    onPrivacy: () => router.go('/account-privacy'),
                  ),
                ),
              ],
            );
          }
          return child ?? const SizedBox.shrink();
        },
      ),
    );
  }
}

class AuthErrorScreen extends StatefulWidget {
  const AuthErrorScreen({super.key, required this.identity});
  final IdentityController identity;
  @override
  State<AuthErrorScreen> createState() => _AuthErrorScreenState();
}

class _AuthErrorScreenState extends State<AuthErrorScreen> {
  String? logoutError;
  @override
  Widget build(BuildContext context) => PageFrame(
    back: false,
    children: [
      const Heading(
        'Revisemos tu acceso.',
        'No pudimos restaurar la sesión o abrir el enlace.',
      ),
      Notice(
        identityError(widget.identity.error ?? StateError('auth_failed')),
        isError: true,
      ),
      ActionButton('Volver a intentar', onPressed: widget.identity.initialize),
      if (logoutError != null) Notice(logoutError!, isError: true),
      TextButton(
        onPressed: () async {
          try {
            await widget.identity.logout();
          } catch (cause) {
            if (mounted) setState(() => logoutError = identityError(cause));
          }
        },
        child: const Text('Volver a iniciar sesión'),
      ),
    ],
  );
}
