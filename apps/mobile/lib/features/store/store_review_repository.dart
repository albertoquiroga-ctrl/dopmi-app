import 'store_repository.dart';
import 'store_review_catalog.dart';

/// Serves the internal review catalog locally for a signed-in Play tester.
class StoreReviewRepository implements StoreRepository {
  StoreReviewRepository({
    required this.currentUser,
    required Stream<String?> changes,
    Map<String, String> amazonLinks = const {},
  }) : actorChanges = changes,
       _linksByProduct = _resolveProductLinks(amazonLinks);

  final String? Function() currentUser;
  final Map<String, Uri> _linksByProduct;

  @override
  String? get userId => currentUser();

  @override
  final Stream<String?> actorChanges;

  @override
  Future<StoreCatalog> catalog() async {
    final signedIn = userId != null;
    final hasLinks = signedIn && _linksByProduct.isNotEmpty;
    return StoreCatalog(
      enabled: signedIn,
      products: signedIn ? storeReviewProducts : const [],
      preview: true,
      expiresAt: signedIn ? DateTime.now().add(const Duration(hours: 1)) : null,
      externalLinksEnabled: hasLinks,
      amazonAffiliateSearch: hasLinks,
    );
  }

  @override
  Future<Uri?> productLink(String productId) async =>
      userId == null ? null : _linksByProduct[productId];
}

Map<String, Uri> _resolveProductLinks(Map<String, String> amazonLinks) {
  final linksByFamily = {
    for (final entry in amazonLinks.entries)
      entry.key: ?_parseAmazonSearch(entry.value),
  };
  final linksByProduct = <String, Uri>{};
  for (final product in storeReviewProducts) {
    final link = linksByFamily[product.familyId];
    // The detail action is enabled for the whole catalog.
    if (link == null) return const {};
    linksByProduct[product.id] = link;
  }
  return linksByProduct;
}

Uri? _parseAmazonSearch(String link) {
  // Match the literal origin and path to reject credentials and explicit ports.
  if (!link.startsWith('https://www.amazon.com.mx/s?')) return null;
  try {
    final uri = Uri.parse(link);
    final tags = uri.queryParametersAll['tag'];
    if (uri.hasFragment ||
        tags?.length != 1 ||
        tags?.single != 'albertoquir0f-20') {
      return null;
    }
    return uri;
  } on FormatException {
    return null;
  }
}
