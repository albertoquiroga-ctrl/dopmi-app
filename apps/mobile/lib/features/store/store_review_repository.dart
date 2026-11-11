import 'store_repository.dart';
import 'store_review_catalog.dart';

/// Serves the internal review catalog locally for a signed-in Play tester.
class StoreReviewRepository implements StoreRepository {
  const StoreReviewRepository({
    required this.currentUser,
    required Stream<String?> changes,
  }) : actorChanges = changes;

  final String? Function() currentUser;

  @override
  String? get userId => currentUser();

  @override
  final Stream<String?> actorChanges;

  @override
  Future<StoreCatalog> catalog() async {
    final signedIn = userId != null;
    return StoreCatalog(
      enabled: signedIn,
      products: signedIn ? storeReviewProducts : const [],
      preview: true,
      expiresAt: signedIn ? DateTime.now().add(const Duration(hours: 1)) : null,
      externalLinksEnabled: false,
    );
  }

  @override
  Future<Uri?> productLink(String productId) async => null;
}
