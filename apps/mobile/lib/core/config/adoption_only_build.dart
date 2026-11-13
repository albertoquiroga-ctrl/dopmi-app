import 'package:flutter/foundation.dart';

/// A distribution profile that exposes the adoption experience only.
const adoptionOnlyBuild = bool.fromEnvironment('DOPMI_ADOPTION_ONLY');

/// Selects the Amazon México catalog for the internal Android review build.
const storeReviewBuild =
    adoptionOnlyBuild &&
    bool.fromEnvironment('DOPMI_STORE_REVIEW') &&
    String.fromEnvironment('DOPMI_ENVIRONMENT') == 'production';

bool get storeReviewAvailable =>
    storeReviewBuild &&
    !kIsWeb &&
    defaultTargetPlatform == TargetPlatform.android;
