import 'dart:async';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/core/config/adoption_only_build.dart';
import 'package:dopmi_mobile/features/store/store_review_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'the adoption-only build exposes only the explicit Store review route',
    () {
      expect(adoptionOnlyRouteRedirect(Uri.parse('/store')), '/home');
      expect(
        adoptionOnlyRouteRedirect(Uri.parse('/store'), allowStoreReview: true),
        isNull,
      );
      for (final path in [
        '/store/?next=/contribute',
        '/store/item',
        '/apoya-causa',
        '/rescuer/apoya-causa',
        '/contribute',
        '/connect',
        '/guardian',
      ]) {
        expect(
          adoptionOnlyRouteRedirect(Uri.parse(path), allowStoreReview: true),
          '/home',
          reason: path,
        );
      }
    },
  );

  test('the opt-in also requires Android, production and adoption-only', () {
    final expected =
        const bool.fromEnvironment('DOPMI_STORE_REVIEW') &&
        const bool.fromEnvironment('DOPMI_ADOPTION_ONLY') &&
        const String.fromEnvironment('DOPMI_ENVIRONMENT') == 'production';
    expect(storeReviewBuild, expected);
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(storeReviewAvailable, false);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(storeReviewAvailable, expected);
  });

  test(
    'the review catalog is authenticated, local and cannot launch a merchant',
    () async {
      String? actor;
      final repository = StoreReviewRepository(
        currentUser: () => actor,
        changes: const Stream.empty(),
      );
      expect((await repository.catalog()).enabled, false);
      actor = 'review-actor';
      final review = await repository.catalog();
      expect(review.enabled, true);
      expect(review.preview, true);
      expect(review.products, hasLength(127));
      expect(
        review.products.every((product) => product.imageUrl.isEmpty),
        true,
      );
      expect(review.externalLinksEnabled, false);
      expect(await repository.productLink(review.products.first.id), isNull);
      actor = null;
      expect((await repository.catalog()).products, isEmpty);
    },
  );
}
