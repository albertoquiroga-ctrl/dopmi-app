import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef PlayInstall = ({
  String referrer,
  int clickedAtSeconds,
  int installedAtSeconds,
});

bool get supportsPlayInstallReferrer =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

Future<PlayInstall?> readAndroidPlayInstall() async {
  if (!supportsPlayInstallReferrer) return null;

  const channel = MethodChannel('io.dopmi.app/play_install_referrer');
  final details = await channel.invokeMapMethod<String, Object?>('read');
  final referrer = details?['referrer'];
  final clickedAt = details?['clickedAtSeconds'];
  final installedAt = details?['installedAtSeconds'];
  if (referrer is! String || clickedAt is! int || installedAt is! int) {
    return null;
  }
  return (
    referrer: referrer,
    clickedAtSeconds: clickedAt,
    installedAtSeconds: installedAt,
  );
}

class AndroidRescuerAcquisition {
  AndroidRescuerAcquisition(
    this.preferences,
    this.namespace, {
    this.readInstall = readAndroidPlayInstall,
    this.now = DateTime.now,
  });

  final SharedPreferences preferences;
  final String namespace;
  final Future<PlayInstall?> Function() readInstall;
  final DateTime Function() now;

  Future<void> _pending = Future.value();
  String get _claimedByKey => 'dopmi.$namespace.play_acquisition_owner';
  String get _completedKey => 'dopmi.$namespace.play_acquisition_processed';

  static const _variants = {'personal-a', 'personal-b', 'pagina-a', 'pagina-b'};
  static const _window = Duration(days: 14);

  static String? _variant(PlayInstall install, DateTime now) {
    final currentSeconds = now.millisecondsSinceEpoch ~/ 1000;
    final clickedAt = install.clickedAtSeconds;
    final installedAt = install.installedAtSeconds;
    final referrer = install.referrer;
    if (clickedAt <= 0 ||
        clickedAt > installedAt ||
        installedAt > currentSeconds ||
        currentSeconds - clickedAt >= _window.inSeconds ||
        referrer.length > 512 ||
        referrer.contains('#')) {
      return null;
    }

    final params = Uri.parse('?$referrer').queryParametersAll;
    if (params.length != 4 ||
        params.values.any((values) => values.length != 1)) {
      return null;
    }

    final variant = params['utm_content']?.single;
    if (!_variants.contains(variant) ||
        params['utm_source']?.single != 'facebook' ||
        params['utm_medium']?.single != 'organic_comment' ||
        params['utm_campaign']?.single != 'dopmi_rescatistas_mty_$variant') {
      return null;
    }
    return variant;
  }

  Future<void> record({
    required String owner,
    required bool Function() sessionStillEligible,
    required Future<void> Function(String variant, DateTime clickedAt) send,
  }) {
    _pending = _pending
        .then((_) async {
          if (preferences.getBool(_completedKey) == true ||
              !sessionStillEligible()) {
            return;
          }

          final claimedBy = preferences.getString(_claimedByKey);
          if (claimedBy != null && claimedBy != owner) return;

          final install = await readInstall();
          if (!sessionStillEligible()) return;

          if (install != null) {
            final variant = _variant(install, now());
            if (variant != null) {
              // Keep an ambiguous network retry tied to the same opted-in account.
              if (claimedBy == null &&
                  !await preferences.setString(_claimedByKey, owner)) {
                return;
              }
              if (!sessionStillEligible()) return;
              await send(
                variant,
                DateTime.fromMillisecondsSinceEpoch(
                  install.clickedAtSeconds * 1000,
                  isUtc: true,
                ),
              );
            }
          }
          if (await preferences.setBool(_completedKey, true)) {
            await preferences.remove(_claimedByKey);
          }
        })
        .catchError((Object _) {
          // Optional attribution must never interrupt consent or normal app use.
        });
    return _pending;
  }
}
