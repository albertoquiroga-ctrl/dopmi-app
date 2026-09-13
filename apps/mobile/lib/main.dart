import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config.dart';
import 'core/storage.dart';
import 'core/ui.dart';
import 'features/identity/identity_controller.dart';
import 'features/identity/identity_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Bootstrap());
}

class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});
  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  final config = AppConfig.environment();
  late Future<IdentityRepository> connection = connect();
  Future<IdentityRepository> connect() async {
    if (!config.isValid) throw StateError('missing_config');
    final preferences = await SharedPreferences.getInstance();
    {
      final namespace = Uri.parse(config.url).host;
      final callback = Uri.parse(config.redirect);
      await Supabase.initialize(
        url: config.url,
        publishableKey: config.key,
        debug: false,
        authOptions: FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          localStorage: kIsWeb ? null : SecureSessionStorage(namespace),
          pkceAsyncStorage: kIsWeb ? null : SecurePkceStorage(namespace),
          detectSessionInUriPredicate: (uri) =>
              uri.scheme == callback.scheme &&
              uri.host == callback.host &&
              uri.path == callback.path,
        ),
      );
    }
    return SupabaseIdentityRepository(
      Supabase.instance.client,
      config,
      preferences,
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<IdentityRepository>(
    future: connection,
    builder: (_, snapshot) {
      if (snapshot.hasData) {
        return ProviderScope(
          overrides: [
            configProvider.overrideWithValue(config),
            identityRepositoryProvider.overrideWithValue(snapshot.data!),
          ],
          child: const DopmiApp(),
        );
      }
      return MaterialApp(
        title: 'Dopmi',
        debugShowCheckedModeBanner: false,
        theme: dopmiTheme(),
        locale: const Locale('es', 'MX'),
        supportedLocales: const [Locale('es', 'MX')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: PageFrame(
          back: false,
          children: [
            if (!snapshot.hasError)
              const Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Conectando con Dopmi',
                ),
              ),
            if (snapshot.hasError) ...[
              Heading(
                config.isValid
                    ? 'No pudimos iniciar Dopmi.'
                    : 'Conecta tu app.',
                config.isValid
                    ? 'Comprueba tu conexión y vuelve a intentarlo.'
                    : 'Falta la configuración de desarrollo de Supabase. Sigue la guía del proyecto para iniciar la app.',
              ),
              if (config.isValid)
                ActionButton(
                  'Volver a intentar',
                  onPressed: () => setState(() => connection = connect()),
                ),
            ],
          ],
        ),
      );
    },
  );
}
