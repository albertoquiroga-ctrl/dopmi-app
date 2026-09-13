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

final routerProvider = Provider<GoRouter>((ref) {
  final identity = ref.watch(identityControllerProvider);
  final router = GoRouter(
    initialLocation: '/welcome',
    overridePlatformDefaultLocation: true,
    refreshListenable: identity,
    redirect: (_, state) => identity.redirect(state.uri.path),
    routes: [
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
