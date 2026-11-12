import 'dart:async';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/core/config/adoption_only_build.dart';
import 'package:dopmi_mobile/features/store/store_repository.dart';
import 'package:dopmi_mobile/features/store/store_review_amazon_links.dart';
import 'package:dopmi_mobile/features/store/store_review_catalog.dart';
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

  test('every review presentation resolves to local product artwork', () {
    final artworkById = {
      for (final product in storeReviewProducts)
        product.id: storeReviewArtworkFor(product.id),
    };
    expect(artworkById, hasLength(128));
    expect(artworkById.values, everyElement(isNotNull));

    Set<String> idsFor(StorePreviewArtworkKind kind) => artworkById.entries
        .where((entry) => entry.value?.kind == kind)
        .map((entry) => entry.key)
        .toSet();

    final photoIds = idsFor(StorePreviewArtworkKind.photo);
    expect(photoIds, hasLength(19));
    expect(photoIds, storeReviewPhotoSources.keys.toSet());
    expect(idsFor(StorePreviewArtworkKind.illustration), {
      'whiskas-adult-3-1500',
    });
    expect(idsFor(StorePreviewArtworkKind.template), hasLength(108));
    expect(storeReviewArtworkFor('unknown-review-product'), isNull);
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
      expect(review.products, hasLength(128));
      expect(
        review.products.every((product) => product.imageUrl.isEmpty),
        true,
      );
      expect(review.externalLinksEnabled, false);
      expect(review.amazonAffiliateSearch, false);
      expect(await repository.productLink(review.products.first.id), isNull);
      actor = null;
      expect((await repository.catalog()).products, isEmpty);
    },
  );

  test(
    'signed-in review testers get the original link for each family',
    () async {
      String? actor;
      final repository = StoreReviewRepository(
        currentUser: () => actor,
        changes: const Stream.empty(),
        amazonLinks: storeReviewAmazonLinks,
      );
      final sample = storeReviewProducts.first;
      expect((await repository.catalog()).amazonAffiliateSearch, false);
      expect(await repository.productLink(sample.id), isNull);

      actor = 'review-actor';
      final review = await repository.catalog();
      expect(review.preview, true);
      expect(review.externalLinksEnabled, true);
      expect(review.amazonAffiliateSearch, true);
      expect(storeReviewAmazonLinks.keys.toSet(), {
        for (final product in review.products) product.familyId,
      });
      for (final product in review.products) {
        final link = await repository.productLink(product.id);
        expect(link?.toString(), storeReviewAmazonLinks[product.familyId]);
      }
      expect(await repository.productLink(sample.familyId!), isNull);
      expect(await repository.productLink('not-in-the-catalog'), isNull);

      actor = null;
      expect(await repository.productLink(sample.id), isNull);
    },
  );

  test('a missing or unsafe family link disables the catalog action', () async {
    final sample = storeReviewProducts.first;
    for (final unsafe in [
      null,
      'http://www.amazon.com.mx/s?k=mascotas&tag=albertoquir0f-20',
      'https://www.amazon.com.mx.ejemplo.test/s?tag=albertoquir0f-20',
      'https://user@www.amazon.com.mx/s?tag=albertoquir0f-20',
      'https://www.amazon.com.mx:443/s?tag=albertoquir0f-20',
      'https://www.amazon.com.mx/dp/B000000001?tag=albertoquir0f-20',
      'https://www.amazon.com.mx/s?k=mascotas&tag=albertoquir0f-20#otro',
      'https://www.amazon.com.mx/s?k=mascotas&tag=otro-20',
      'https://www.amazon.com.mx/s?tag=albertoquir0f-20&tag=otro-20',
    ]) {
      final links = Map.of(storeReviewAmazonLinks)..remove(sample.familyId);
      if (unsafe != null) links[sample.familyId!] = unsafe;
      final repository = StoreReviewRepository(
        currentUser: () => 'review-actor',
        changes: const Stream.empty(),
        amazonLinks: links,
      );
      final review = await repository.catalog();
      expect(review.enabled, true);
      expect(review.amazonAffiliateSearch, false, reason: unsafe);
      expect(review.externalLinksEnabled, false, reason: unsafe);
      expect(await repository.productLink(sample.id), isNull, reason: unsafe);
    }
  });

  test('server catalog JSON cannot set the internal affiliate mode', () {
    final catalog = StoreCatalog.fromJson({
      'enabled': true,
      'preview': true,
      'expires_at': DateTime.now()
          .add(const Duration(hours: 1))
          .toIso8601String(),
      'external_links_enabled': true,
      'amazon_affiliate_search': true,
      'items': <Object>[],
    });
    expect(catalog.externalLinksEnabled, true);
    expect(catalog.amazonAffiliateSearch, false);
  });
}
