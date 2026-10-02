import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config.dart';
import 'core/storage.dart';
import 'core/measurement.dart';
import 'core/ui.dart';
import 'core/content_links.dart';
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
  final contentLinks = PlatformContentLinkSource();
  late Future<
    ({IdentityRepository identity, MeasurementController measurement})
  >
  connection = connect();
  Future<({IdentityRepository identity, MeasurementController measurement})>
  connect() async {
    if (!config.isValid) throw StateError('missing_config');
    final preferences = await SharedPreferences.getInstance();
    await Firebase.initializeApp();
    final measurement = MeasurementController(
      preferences,
      Uri.parse(config.url).host,
      FirebaseProductAnalytics(FirebaseAnalytics.instance),
      FirebaseErrorDiagnostics(FirebaseCrashlytics.instance),
    );
    await measurement.owner(null);
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
    return (
      identity: SupabaseIdentityRepository(
        Supabase.instance.client,
        config,
        preferences,
      ),
      measurement: measurement,
    );
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<
        ({IdentityRepository identity, MeasurementController measurement})
      >(
        future: connection,
        builder: (_, snapshot) {
          if (snapshot.hasData) {
            return ProviderScope(
              overrides: [
                configProvider.overrideWithValue(config),
                contentLinkSourceProvider.overrideWithValue(contentLinks),
                identityRepositoryProvider.overrideWithValue(
                  snapshot.data!.identity,
                ),
                measurementControllerProvider.overrideWith(
                  (ref) => snapshot.data!.measurement,
                ),
              ],
              child: const ContentLinkListener(child: DopmiApp()),
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
