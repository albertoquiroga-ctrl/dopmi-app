import 'package:flutter/foundation.dart';

/// A distribution profile that exposes the adoption experience only.
const adoptionOnlyBuild = bool.fromEnvironment('DOPMI_ADOPTION_ONLY');

const _storeReviewRequested = bool.fromEnvironment('DOPMI_STORE_REVIEW');
const _storeAmazonPublicRequested = bool.fromEnvironment(
  'DOPMI_STORE_AMAZON_PUBLIC',
);
const _storeProductionProfile =
    adoptionOnlyBuild &&
    String.fromEnvironment('DOPMI_ENVIRONMENT') == 'production';

/// Selects the Amazon México catalog for the internal Android review build.
const storeReviewBuild =
    _storeProductionProfile &&
    _storeReviewRequested &&
    !_storeAmazonPublicRequested;

bool get storeReviewAvailable =>
    storeReviewBuild &&
    !kIsWeb &&
    defaultTargetPlatform == TargetPlatform.android;

/// Selects the public Amazon México catalog in the production adoption app.
const storeAmazonPublicBuild =
    _storeProductionProfile &&
    _storeAmazonPublicRequested &&
    !_storeReviewRequested;

bool get storeAmazonPublicAvailable =>
    storeAmazonPublicBuild &&
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

bool get storeAmazonAvailable =>
    storeAmazonPublicAvailable || storeReviewAvailable;
