import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/ui.dart';
import 'features/identity/auth_screens.dart';
import 'features/identity/identity_controller.dart';
import 'features/identity/identity_repository.dart';
import 'features/identity/onboarding_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/adoption/catalog_screens.dart';
import 'features/adoption/publication_screens.dart';
import 'features/communication/message_screens.dart';
import 'features/rescue/rescue_screens.dart';
import 'features/payments/payment_screens.dart';
import 'features/payments/guardian_screen.dart';
import 'features/payments/guardian_history_screen.dart';
import 'features/adoption/community_repository.dart' show Json;

final routerInitialLocationProvider = Provider<String>((ref) => '/welcome');

final routerProvider = Provider<GoRouter>((ref) {
  final identity = ref.watch(identityControllerProvider);
  String? restoringPath;
  final router = GoRouter(
    initialLocation: ref.watch(routerInitialLocationProvider),
    overridePlatformDefaultLocation: false,
    refreshListenable: identity,
    redirect: (_, state) {
      if (identity.loading && state.uri.path != '/loading') {
        restoringPath = state.uri.toString();
      }
      final desired = identity.loading
          ? state.uri.path
          : Uri.parse(restoringPath ?? state.uri.toString()).path;
      final target = identity.redirect(desired);
      if (!identity.loading && restoringPath != null) {
        final restored = restoringPath;
        restoringPath = null;
        return target ?? (restored != state.uri.toString() ? restored : null);
      }
      return target;
    },
    routes: [
      GoRoute(
        path: '/guardian/history',
        builder: (_, _) =>
            GuardianHistoryScreen(key: ValueKey(identity.identity?.id)),
      ),
      GoRoute(
        path: '/guardian',
        builder: (_, _) => GuardianScreen(key: ValueKey(identity.identity?.id)),
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
          attempt: state.extra is Json ? state.extra! as Json : null,
          key: ValueKey('${identity.identity?.id}:${state.uri}'),
        ),
      ),
      GoRoute(
        path: '/rescuer',
        builder: (_, state) => RescueHomeScreen(
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
        path: '/rescue-cases',
        builder: (_, state) => RescueCatalogScreen(
          key: ValueKey('${identity.identity?.id}:${state.uri}'),
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
        path: '/adoptions',
        builder: (_, state) => CatalogScreen(
          key: ValueKey('${identity.identity?.id}:${state.uri}'),
          owner: state.uri.queryParameters['owner'],
        ),
      ),
      GoRoute(
        path: '/saved',
        builder: (_, _) =>
            CatalogScreen(key: ValueKey(identity.identity?.id), saved: true),
      ),
      GoRoute(
        path: '/adoptions/:id',
        builder: (_, state) => AdoptionDetailScreen(
          state.pathParameters['id']!,
          key: ValueKey('${identity.identity?.id}:${state.uri}'),
        ),
      ),
      GoRoute(
        path: '/people/:id',
        builder: (_, state) => PublicProfileScreen(state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/my-adoptions',
        builder: (_, _) =>
            MyAdoptionsScreen(key: ValueKey(identity.identity?.id)),
      ),
      GoRoute(
        path: '/my-adoptions/:id',
        builder: (_, state) => PublicationScreen(
          state.pathParameters['id']!,
          key: ValueKey('${identity.identity?.id}:${state.uri}'),
        ),
      ),
      GoRoute(
        path: '/messages',
        builder: (_, _) => ThreadsScreen(key: ValueKey(identity.identity?.id)),
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
        path: '/signup',
        builder: (_, state) => AuthFormScreen(
          mode: AuthFormMode.signup,
          intent: safeIntent(state.uri.queryParameters['intent']),
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const AuthFormScreen(mode: AuthFormMode.login),
      ),
      GoRoute(
        path: '/forgot',
        builder: (_, _) => const AuthFormScreen(mode: AuthFormMode.forgot),
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
      GoRoute(
        path: '/profile',
        builder: (_, _) => ProfileScreen(key: ValueKey(identity.identity?.id)),
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
  ref.onDispose(router.dispose);
  return router;
});

class DopmiApp extends ConsumerWidget {
  const DopmiApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'Dopmi',
    debugShowCheckedModeBanner: false,
    theme: dopmiTheme(),
    locale: const Locale('es', 'MX'),
    supportedLocales: const [Locale('es', 'MX')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    routerConfig: ref.watch(routerProvider),
  );
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
