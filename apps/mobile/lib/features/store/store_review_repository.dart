import 'store_repository.dart';
import 'store_review_amazon_listings.dart';
import 'store_review_catalog.dart';

/// Serves the internal review catalog locally for a signed-in Play tester.
class StoreReviewRepository implements StoreRepository {
  StoreReviewRepository({
    required this.currentUser,
    required Stream<String?> changes,
    Map<String, StoreReviewAmazonListing> listings = storeReviewAmazonListings,
  }) : actorChanges = changes,
       _linksByProduct = {
         for (final product in storeReviewProducts)
           product.id: ?listings[product.id]?.productUri,
       };

  final String? Function() currentUser;
  final Map<String, Uri> _linksByProduct;

  @override
  String? get userId => currentUser();

  @override
  final Stream<String?> actorChanges;

  @override
  Future<StoreCatalog> catalog() async {
    final enabled = userId != null && _linksByProduct.isNotEmpty;
    return StoreCatalog(
      enabled: enabled,
      products: enabled
          ? [
              for (final product in storeReviewProducts)
                if (_linksByProduct.containsKey(product.id)) product,
            ]
          : const [],
      preview: true,
      expiresAt: enabled ? DateTime.now().add(const Duration(hours: 1)) : null,
      externalLinksEnabled: enabled,
      amazonProductLinks: enabled,
    );
  }

  @override
  Future<Uri?> productLink(String productId) async =>
      userId == null ? null : _linksByProduct[productId];
}
