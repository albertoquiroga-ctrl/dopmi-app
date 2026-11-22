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

enum AndroidExperimentClaimResult {
  recorded,
  alreadyRecorded,
  ineligible,
  consentChanged,
  invalidPlacement,
}

Future<PlayInstall?> readAndroidPlayInstall({
  bool diagnosticsEnabled = false,
}) async {
  if (!supportsPlayInstallReferrer) return null;

  const channel = MethodChannel('io.dopmi.app/play_install_referrer');
  final details = await channel.invokeMapMethod<String, Object?>('read', {
    'diagnostics': diagnosticsEnabled,
  });
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

enum _AcquisitionState {
  alreadyProcessed,
  sessionIneligible,
  anotherOwner,
  readStarted,
  readNull,
  readUnavailable,
  readError,
  referrerAccepted,
  referrerRejected,
  claimNotSaved,
  sendAttempted,
  sendSucceeded,
  sendError,
  consentChanged,
  completed,
  completionNotSaved,
  processingError,
}

class AndroidRescuerAcquisition {
  AndroidRescuerAcquisition(
    this.preferences,
    this.namespace, {
    this.readInstall = readAndroidPlayInstall,
    this.now = DateTime.now,
    this.onDiagnostic,
  });

  final SharedPreferences preferences;
  final String namespace;
  final Future<PlayInstall?> Function() readInstall;
  final DateTime Function() now;
  final void Function(String)? onDiagnostic;

  Future<void> _pending = Future.value();
  String get _claimedByKey => 'dopmi.$namespace.play_acquisition_owner';
  String get _completedKey => 'dopmi.$namespace.play_acquisition_processed';

  static const _variants = {'personal-a', 'personal-b', 'pagina-a', 'pagina-b'};
  static const _placementCampaign = 'dopmi_rescatistas_mty_p60_v1';
  static final _placementPattern = RegExp(r'^[0-9a-f]{32}$');
  static const _utmKeys = {
    'utm_source',
    'utm_medium',
    'utm_campaign',
    'utm_content',
  };
  static const _window = Duration(days: 14);

  void _diagnose(_AcquisitionState state, {String? checks}) {
    try {
      onDiagnostic?.call(
        'state=${state.name}${checks == null ? '' : ' $checks'}',
      );
    } catch (_) {
      // A local diagnostic observer cannot affect attribution.
    }
  }

  static String _installChecks(PlayInstall install, DateTime now) {
    final currentSeconds = now.millisecondsSinceEpoch ~/ 1000;
    final positive = install.clickedAtSeconds > 0;
    final ordered = install.clickedAtSeconds <= install.installedAtSeconds;
    final notFuture = install.installedAtSeconds <= currentSeconds;
    final withinWindow =
        currentSeconds >= install.clickedAtSeconds &&
        currentSeconds - install.clickedAtSeconds < _window.inSeconds;
    final validShape =
        install.referrer.length <= 512 && !install.referrer.contains('#');
    var parsed = false;
    Map<String, List<String>> params = const {};
    if (validShape) {
      try {
        params = Uri.parse('?${install.referrer}').queryParametersAll;
        parsed = true;
      } catch (_) {
        // Report only the bounded parse result, never the malformed input.
      }
    }
    bool matches(String key, String value) =>
        params[key]?.length == 1 && params[key]!.single == value;
    String category(String key, Map<String, String> knownValues) {
      final values = params[key];
      if (values == null) return 'absent';
      if (values.length != 1) return 'other';
      if (values.single.isEmpty) return 'empty';
      return knownValues[values.single] ?? 'other';
    }

    final sourceClass = category('utm_source', const {
      'facebook': 'facebook',
      'google-play': 'google-play',
      '(not set)': 'not_set',
    });
    final mediumClass = category('utm_medium', const {
      'organic_comment': 'organic_comment',
      'organic': 'organic',
      '(not set)': 'not_set',
    });
    final campaignClass = category('utm_campaign', {
      for (final variant in _variants)
        'dopmi_rescatistas_mty_$variant': 'expected',
      _placementCampaign: 'experiment',
    });
    final contentClass = category('utm_content', {
      for (final variant in _variants) variant: 'expected',
    });
    final content = params['utm_content'];
    final variant = content?.length == 1 && _variants.contains(content!.single)
        ? content.single
        : null;
    final placement =
        matches('utm_campaign', _placementCampaign) &&
        content?.length == 1 &&
        _validPlacement(content!.single);
    // Counts saturate at 16. Neither parameter names nor arbitrary values leave.
    final unknown = params.keys
        .where((key) => !_utmKeys.contains(key))
        .length
        .clamp(0, 16);
    final duplicate = params.values
        .where((values) => values.length > 1)
        .length
        .clamp(0, 16);
    final parameters = params.values
        .fold<int>(0, (total, values) => total + values.length)
        .clamp(0, 16);
    return 'positive=$positive order=$ordered notFuture=$notFuture '
        'window=$withinWindow shape=$validShape parsed=$parsed '
        'source=${matches('utm_source', 'facebook')} '
        'medium=${matches('utm_medium', 'organic_comment')} '
        'campaign=${variant != null && matches('utm_campaign', 'dopmi_rescatistas_mty_$variant')} '
        'content=${variant != null} variant=${variant ?? 'none'} '
        'unknown=$unknown duplicate=$duplicate '
        'empty=${install.referrer.isEmpty} parameters=$parameters '
        'sourcePresent=${params.containsKey('utm_source')} '
        'mediumPresent=${params.containsKey('utm_medium')} '
        'campaignPresent=${params.containsKey('utm_campaign')} '
        'contentPresent=${params.containsKey('utm_content')} '
        'sourceClass=$sourceClass mediumClass=$mediumClass '
        'campaignClass=$campaignClass contentClass=$contentClass '
        'placement=$placement';
  }

  static bool _validPlacement(String value) =>
      value.length == 32 && _placementPattern.hasMatch(value);

  static ({String? variant, String? placementToken})? _claim(
    PlayInstall install,
    DateTime now,
  ) {
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

    if (params['utm_source']?.single != 'facebook' ||
        params['utm_medium']?.single != 'organic_comment') {
      return null;
    }
    final content = params['utm_content']?.single;
    final campaign = params['utm_campaign']?.single;
    if (campaign == _placementCampaign &&
        content != null &&
        _validPlacement(content)) {
      return (variant: null, placementToken: content);
    }
    if (_variants.contains(content) &&
        campaign == 'dopmi_rescatistas_mty_$content') {
      return (variant: content, placementToken: null);
    }
    return null;
  }

  Future<void> record({
    required String owner,
    required bool Function() sessionStillEligible,
    required Future<void> Function(String variant, DateTime clickedAt) send,
    Future<AndroidExperimentClaimResult> Function(
      String placementToken,
      DateTime clickedAt,
    )?
    sendPlacement,
  }) {
    _pending = _pending
        .then((_) async {
          if (preferences.getBool(_completedKey) == true) {
            _diagnose(_AcquisitionState.alreadyProcessed);
            return;
          }
          if (!sessionStillEligible()) {
            _diagnose(_AcquisitionState.sessionIneligible);
            return;
          }

          final claimedBy = preferences.getString(_claimedByKey);
          if (claimedBy != null && claimedBy != owner) {
            _diagnose(_AcquisitionState.anotherOwner);
            return;
          }

          _diagnose(_AcquisitionState.readStarted);
          PlayInstall? install;
          try {
            install = await readInstall();
          } catch (error) {
            _diagnose(
              error is PlatformException &&
                      error.code == 'play_referrer_unavailable'
                  ? _AcquisitionState.readUnavailable
                  : _AcquisitionState.readError,
            );
            return;
          }
          if (!sessionStillEligible()) {
            _diagnose(_AcquisitionState.sessionIneligible);
            return;
          }

          if (install != null) {
            final current = now();
            final checks = onDiagnostic == null
                ? null
                : _installChecks(install, current);
            ({String? variant, String? placementToken})? claim;
            try {
              claim = _claim(install, current);
            } catch (_) {
              _diagnose(_AcquisitionState.referrerRejected, checks: checks);
              rethrow;
            }
            _diagnose(
              claim == null
                  ? _AcquisitionState.referrerRejected
                  : _AcquisitionState.referrerAccepted,
              checks: checks,
            );
            if (claim != null) {
              // Keep an ambiguous network retry tied to the same opted-in account.
              if (claimedBy == null &&
                  !await preferences.setString(_claimedByKey, owner)) {
                _diagnose(_AcquisitionState.claimNotSaved);
                return;
              }
              if (!sessionStillEligible()) {
                _diagnose(_AcquisitionState.sessionIneligible);
                return;
              }
              _diagnose(_AcquisitionState.sendAttempted);
              try {
                final clickedAt = DateTime.fromMillisecondsSinceEpoch(
                  install.clickedAtSeconds * 1000,
                  isUtc: true,
                );
                final placement = claim.placementToken;
                if (placement != null) {
                  final dispatch = sendPlacement;
                  if (dispatch == null) {
                    _diagnose(_AcquisitionState.sendError);
                    return;
                  }
                  final result = await dispatch(placement, clickedAt);
                  if (result == AndroidExperimentClaimResult.consentChanged) {
                    _diagnose(_AcquisitionState.consentChanged);
                    return;
                  }
                } else {
                  await send(claim.variant!, clickedAt);
                }
              } catch (_) {
                _diagnose(_AcquisitionState.sendError);
                return;
              }
              _diagnose(_AcquisitionState.sendSucceeded);
            }
          } else {
            _diagnose(_AcquisitionState.readNull);
          }
          if (await preferences.setBool(_completedKey, true)) {
            await preferences.remove(_claimedByKey);
            _diagnose(_AcquisitionState.completed);
          } else {
            _diagnose(_AcquisitionState.completionNotSaved);
          }
        })
        .catchError((Object _) {
          _diagnose(_AcquisitionState.processingError);
          // Optional attribution must never interrupt consent or normal app use.
        });
    return _pending;
  }
}
