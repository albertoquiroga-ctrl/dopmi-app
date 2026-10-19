import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class StoreProduct {
  const StoreProduct({
    required this.id,
    required this.name,
    required this.brand,
    required this.species,
    required this.age,
    required this.size,
    required this.weightKg,
    required this.imageUrl,
    required this.merchantName,
  });
  factory StoreProduct.fromJson(Map<String, dynamic> value) => StoreProduct(
    id: value['id'] as String,
    name: value['name'] as String,
    brand: value['brand'] as String,
    species: value['species'] as String,
    age: value['age'] as String,
    size: value['size'] as String,
    weightKg: (value['weight_kg'] as num).toDouble(),
    imageUrl: value['image_url'] as String,
    merchantName: value['merchant_name'] as String,
  );
  final String id, name, brand, species, age, size, imageUrl, merchantName;
  final double weightKg;
}

class StoreCatalog {
  const StoreCatalog({required this.enabled, required this.products});
  factory StoreCatalog.fromJson(Map<String, dynamic> value) {
    final enabled = value['enabled'] == true;
    // A disabled response never exposes inventory, even if a stale proxy supplies it.
    return StoreCatalog(
      enabled: enabled,
      products: enabled
          ? (value['items'] as List)
                .map(
                  (item) => StoreProduct.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ),
                )
                .toList(growable: false)
          : const [],
    );
  }
  final bool enabled;
  final List<StoreProduct> products;
}

abstract class StoreRepository {
  String? get userId;
  Stream<String?> get actorChanges;
  Future<StoreCatalog> catalog();
  Future<Uri?> productLink(String productId);
}

class SupabaseStoreRepository implements StoreRepository {
  SupabaseStoreRepository(this.client);
  final SupabaseClient client;
  @override
  String? get userId => client.auth.currentUser?.id;
  @override
  Stream<String?> get actorChanges => client.auth.onAuthStateChange
      .map((event) => event.session?.user.id)
      .distinct();
  @override
  Future<StoreCatalog> catalog() async => StoreCatalog.fromJson(
    Map<String, dynamic>.from(await client.rpc('dopmi_store_catalog') as Map),
  );
  @override
  Future<Uri?> productLink(String productId) async {
    final value = await client.rpc(
      'dopmi_store_product_link',
      params: {'product_id': productId},
    );
    if (value == null) return null;
    final uri = Uri.tryParse(value as String);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        (uri.hasPort && uri.port != 443)) {
      throw const FormatException('Enlace comercial inválido');
    }
    return uri;
  }
}

final storeRepositoryProvider = Provider<StoreRepository>(
  (ref) => SupabaseStoreRepository(Supabase.instance.client),
);
final storeActorProvider = StreamProvider<String?>((ref) async* {
  final repository = ref.watch(storeRepositoryProvider);
  yield repository.userId;
  yield* repository.actorChanges;
});
final storeCatalogProvider = FutureProvider.autoDispose<StoreCatalog>((ref) {
  ref.watch(storeActorProvider);
  return ref.watch(storeRepositoryProvider).catalog();
});
final storeLinkOpenerProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

List<StoreProduct> filterStoreProducts(
  List<StoreProduct> source, {
  required String species,
  String? age,
  String? size,
  Set<String> brands = const {},
  bool descending = false,
}) {
  final result = source
      .where(
        (item) =>
            item.species == species &&
            (age == null || item.age == age) &&
            (size == null || item.size == size) &&
            (brands.isEmpty || brands.contains(item.brand)),
      )
      .toList();
  result.sort((a, b) {
    final order = a.weightKg.compareTo(b.weightKg) * (descending ? -1 : 1);
    return order == 0 ? a.id.compareTo(b.id) : order;
  });
  return result;
}
