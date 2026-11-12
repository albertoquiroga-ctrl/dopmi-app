import 'dart:async';

import 'package:dopmi_mobile/app.dart';
import 'package:dopmi_mobile/core/config/adoption_only_build.dart';
import 'package:dopmi_mobile/features/store/store_repository.dart';
import 'package:dopmi_mobile/features/store/store_review_amazon_listings.dart';
import 'package:dopmi_mobile/features/store/store_review_catalog.dart';
import 'package:dopmi_mobile/features/store/store_review_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
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
    'each visible Amazon presentation has a photo and a direct tagged link',
    () async {
      String? actor;
      final repository = StoreReviewRepository(
        currentUser: () => actor,
        changes: const Stream.empty(),
      );
      expect((await repository.catalog()).enabled, false);
      expect(
        await repository.productLink(storeReviewAmazonListings.keys.first),
        isNull,
      );

      actor = 'review-actor';
      final review = await repository.catalog();
      expect(review.preview, true);
      expect(review.externalLinksEnabled, true);
      expect(review.amazonProductLinks, true);
      expect(
        review.products.map((product) => product.id).toSet(),
        storeReviewAmazonListings.keys.toSet(),
      );
      for (final product in review.products) {
        final listing = storeReviewAmazonListings[product.id]!;
        final link = await repository.productLink(product.id);
        expect(link?.host, 'www.amazon.com.mx');
        expect(link?.path, '/dp/${listing.asin}');
        expect(link?.queryParameters, {'tag': 'albertoquir0f-20'});
        final image = storeReviewAmazonArtworkFor(product.id)?.image;
        expect(image, isA<NetworkImage>());
        expect((image as NetworkImage).url, listing.imageUri.toString());
      }
      expect(
        storeReviewAmazonListings.values.map((listing) => listing.asin).toSet(),
        hasLength(storeReviewAmazonListings.length),
      );
      expect(await repository.productLink('not-in-the-catalog'), isNull);

      actor = null;
      expect((await repository.catalog()).products, isEmpty);
      expect(
        await repository.productLink(storeReviewAmazonListings.keys.first),
        isNull,
      );
    },
  );

  test('missing and unsafe listings cannot appear or open a link', () async {
    final sample = storeReviewProducts.first;
    for (final invalid in [
      const StoreReviewAmazonListing(
        'not-an-asin',
        'https://m.media-amazon.com/images/I/photo.jpg',
      ),
      const StoreReviewAmazonListing(
        'B000000001',
        'http://m.media-amazon.com/images/I/photo.jpg',
      ),
      const StoreReviewAmazonListing(
        'B000000001',
        'https://m.media-amazon.com.example.test/images/I/photo.jpg',
      ),
      const StoreReviewAmazonListing(
        'B000000001',
        'https://user@m.media-amazon.com/images/I/photo.jpg',
      ),
      const StoreReviewAmazonListing(
        'B000000001',
        'https://m.media-amazon.com/search',
      ),
    ]) {
      final repository = StoreReviewRepository(
        currentUser: () => 'review-actor',
        changes: const Stream.empty(),
        listings: {sample.id: invalid},
      );
      final review = await repository.catalog();
      expect(review.enabled, false);
      expect(review.products, isEmpty);
      expect(await repository.productLink(sample.id), isNull);
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
      'amazon_product_links': true,
      'items': <Object>[],
    });
    expect(catalog.externalLinksEnabled, true);
    expect(catalog.amazonProductLinks, false);
  });
}
