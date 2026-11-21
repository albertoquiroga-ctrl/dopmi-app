import 'dart:async';

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
import 'core/android_rescuer_acquisition.dart';
import 'core/ios_cpp_acquisition.dart';
import 'core/ios_cpp_enrollment.dart';
import 'core/ios_cpp_link_capture.dart';
import 'core/adoption_measurement_consent.dart';
import 'core/config.dart';
import 'core/storage.dart';
import 'core/measurement.dart';
import 'core/ui.dart';
import 'core/content_links.dart';
import 'core/media/photo_runtime.dart';
import 'core/media/video_repository.dart';
import 'features/rescue/rescue_videos.dart';
import 'core/media/photo_store_factory.dart';
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
  late final Future<SharedPreferences> preferencesFuture;
  late final Future<IosCppAcquisition?> iosAcquisition;
  IosCppLinkCapture? cppCapture;
  MeasurementController? activeMeasurement;
  bool cppReceived = false;
  late Future<
    ({
      IdentityRepository identity,
      MeasurementController measurement,
      IosCppAcquisition? ios,
    })
  >
  connection;

  @override
  void initState() {
    super.initState();
    preferencesFuture = SharedPreferences.getInstance();
    iosAcquisition = preferencesFuture.then((preferences) {
      if (!supportsIosCppAcquisition || !config.isValid) return null;
      return IosCppAcquisition(preferences, Uri.parse(config.url).host);
    });
    if (supportsIosCppAcquisition) {
      cppCapture = IosCppLinkCapture(
        events: contentLinks.events,
        readInitial: contentLinks.links.getInitialLink,
        acquisition: iosAcquisition,
        onCaptured: () {
          cppReceived = true;
          final measurement = activeMeasurement;
          final owner = measurement?.ownerId;
          if (owner != null && measurement!.analyticsConsentCurrent) {
            unawaited(measurement.prepareAttributableAction(owner));
          }
        },
      )..start();
    }
    connection = connect();
  }

  @override
  void dispose() {
    activeMeasurement = null;
    unawaited(cppCapture?.dispose());
    super.dispose();
  }

  Future<
    ({
      IdentityRepository identity,
      MeasurementController measurement,
      IosCppAcquisition? ios,
    })
  >
  connect() async {
    if (!config.isValid) throw StateError('missing_config');
    final preferences = await preferencesFuture;
    final ios = await iosAcquisition;
    await Firebase.initializeApp();
    final namespace = Uri.parse(config.url).host;
    final acquisitionDiagnostics = config.environment == 'test';
    final acquisition = AndroidRescuerAcquisition(
      preferences,
      namespace,
      readInstall: () =>
          readAndroidPlayInstall(diagnosticsEnabled: acquisitionDiagnostics),
      onDiagnostic: acquisitionDiagnostics
          ? (message) => debugPrint('DopmiAcquisition $message')
          : null,
    );
    late final MeasurementController measurement;
    AdoptionMeasurementConsent? consentTransport;
    IosCppEnrollment? iosEnrollment;

    measurement = MeasurementController(
      preferences,
      namespace,
      FirebaseProductAnalytics(FirebaseAnalytics.instance),
      FirebaseErrorDiagnostics(FirebaseCrashlytics.instance),
      prepareAcquisition: ios == null
          ? null
          : (owner) async {
              await iosEnrollment?.record(owner);
            },
      prepareAdoptionConsent: (owner, consent) {
        if (!consent) {
          iosEnrollment?.revoke(owner);
        }
        final client = Supabase.instance.client;
        final analyticsRevision = measurement.analyticsRevision;
        final request =
            (consentTransport ??= AdoptionMeasurementConsent(client)).prepare(
              owner,
              consent,
              stillEligible: () =>
                  measurement.ownerId == owner &&
                  measurement.analyticsConsentCurrent &&
                  measurement.analyticsRevision == analyticsRevision,
              onAcceptedRevision: (revision) {
                if (consent) {
                  iosEnrollment?.consentAccepted(
                    owner,
                    localRevision: analyticsRevision,
                    serverRevision: revision,
                  );
                }
              },
            );
        if (request == null) return null;

        return () async {
          final accepted = await request();
          if (!accepted || !consent) return;
          if (ios != null) {
            await iosEnrollment?.record(owner);
            return;
          }
          if (!supportsPlayInstallReferrer) return;

          // A stalled acquisition request must not hold a later explicit
          // opt-out behind it. Its server-side consent lock also handles an
          // already-dispatched request that arrives after this wait expires.
          await acquisition
              .record(
                owner: owner,
                sessionStillEligible: () =>
                    measurement.ownerId == owner &&
                    measurement.analyticsConsentCurrent &&
                    measurement.analyticsRevision == analyticsRevision &&
                    client.auth.currentSession?.user.id == owner,
                send: (variant, clickedAt) async {
                  final current = await client.auth.getSession();
                  if (current == null ||
                      current.user.id != owner ||
                      client.auth.currentSession?.user.id != owner ||
                      measurement.ownerId != owner ||
                      !measurement.analyticsConsentCurrent ||
                      measurement.analyticsRevision != analyticsRevision) {
                    throw StateError('Acquisition session changed');
                  }
                  await client
                      .rpc(
                        'dopmi_record_android_rescuer_acquisition',
                        params: {
                          'p_variant': variant,
                          'p_clicked_at': clickedAt.toIso8601String(),
                        },
                      )
                      .setHeader(
                        'Authorization',
                        'Bearer ${current.accessToken}',
                      );
                },
              )
              .timeout(const Duration(seconds: 10), onTimeout: () {});
        };
      },
    );
    activeMeasurement = measurement;
    await measurement.prepareStartup();
    {
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
    if (ios != null) {
      iosEnrollment = IosCppEnrollment(
        client: Supabase.instance.client,
        acquisition: ios,
        measurement: () => measurement,
        captureReady: () async {
          await cppCapture?.ready;
        },
      );
    }
    await cppCapture?.ready;
    return (
      identity: SupabaseIdentityRepository(
        Supabase.instance.client,
        config,
        preferences,
      ),
      measurement: measurement,
      ios: ios,
    );
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<
        ({
          IdentityRepository identity,
          MeasurementController measurement,
          IosCppAcquisition? ios,
        })
      >(
        future: connection,
        builder: (_, snapshot) {
          if (snapshot.hasData) {
            return ProviderScope(
              overrides: [
                configProvider.overrideWithValue(config),
                contentLinkSourceProvider.overrideWithValue(contentLinks),
                iosCppAcquisitionProvider.overrideWithValue(snapshot.data!.ios),
                if (cppReceived)
                  routerInitialLocationProvider.overrideWithValue(
                    '/my-adoptions',
                  ),
                identityRepositoryProvider.overrideWithValue(
                  snapshot.data!.identity,
                ),
                measurementControllerProvider.overrideWith(
                  (ref) => snapshot.data!.measurement,
                ),
                rescueVideosRepositoryProvider.overrideWith((ref) {
                  final repository = VideoRepository.supabase(
                    Supabase.instance.client,
                  );
                  ref.onDispose(repository.dispose);
                  return repository;
                }),
                photoRuntimeProvider.overrideWith((ref) {
                  final identity = ref.watch(identityControllerProvider);
                  final runtime = PhotoRuntime(
                    store: createPhotoStore(),
                    environment: Uri.parse(config.url).host,
                    actor: identity.identity?.id ?? 'anonymous',
                    ready: false,
                  );
                  void synchronize() => runtime.scope(
                    identity.identity?.id ?? 'anonymous',
                    ready: !identity.loading && identity.error == null,
                  );
                  identity.addListener(synchronize);
                  synchronize();
                  ref.onDispose(() {
                    identity.removeListener(synchronize);
                    runtime.dispose();
                  });
                  return runtime;
                }),
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
