import 'dart:async';

import 'package:flutter/widgets.dart';
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
    this.assetKey,
  });
  factory StoreProduct.fromJson(Map<String, dynamic> value) => StoreProduct(
    id: value['id'] as String,
    name: value['name'] as String,
    brand: value['brand'] as String,
    species: value['species'] as String,
    age: value['age'] as String,
    size: value['size'] as String,
    weightKg: (value['weight_kg'] as num).toDouble(),
    imageUrl: value['image_url'] as String? ?? '',
    merchantName: value['merchant_name'] as String,
    assetKey: value['asset_key'] as String?,
  );
  final String id, name, brand, species, age, size, imageUrl, merchantName;
  final double weightKg;
  final String? assetKey;
}

class StoreCatalog {
  const StoreCatalog({
    required bool enabled,
    required this.products,
    this.preview = false,
    this.expiresAt,
    this.externalLinksEnabled = true,
    // Preserve the public named argument; the stored flag excludes expiry.
    // ignore: prefer_initializing_formals
  }) : _enabled = enabled;
  factory StoreCatalog.fromJson(Map<String, dynamic> value) {
    final preview = value['preview'] == true;
    final expiry = DateTime.tryParse(value['expires_at'] as String? ?? '');
    final enabled =
        value['enabled'] == true &&
        (!preview || (expiry != null && expiry.isAfter(DateTime.now())));
    // A disabled response never exposes inventory, even if a stale proxy supplies it.
    return StoreCatalog(
      enabled: enabled,
      preview: preview,
      expiresAt: expiry,
      externalLinksEnabled: !preview || value['external_links_enabled'] == true,
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
  final bool _enabled, preview, externalLinksEnabled;
  final DateTime? expiresAt;
  bool get enabled =>
      _enabled &&
      (!preview || (expiresAt != null && expiresAt!.isAfter(DateTime.now())));
  final List<StoreProduct> products;
}

abstract class StoreRepository {
  String? get userId;
  Stream<String?> get actorChanges;
  Future<StoreCatalog> catalog();
  Future<Uri?> productLink(String productId);
}

/// Both catalog modes remain server-authorized; this adapter never grants access.
class RpcStoreRepository implements StoreRepository {
  RpcStoreRepository({
    required this.currentUser,
    required this.changes,
    required this.rpc,
  });
  final String? Function() currentUser;
  final Stream<String?> changes;
  final Future<dynamic> Function(String, Map<String, dynamic>) rpc;
  StoreCatalog? _lastCatalog;
  String? _catalogActor;
  int _revision = 0;
  @override
  String? get userId => currentUser();
  @override
  Stream<String?> get actorChanges => changes;
  @override
  Future<StoreCatalog> catalog() async {
    final actor = userId;
    final revision = ++_revision;
    _lastCatalog = null;
    var result = StoreCatalog.fromJson(
      Map<String, dynamic>.from(await rpc('dopmi_store_catalog', {}) as Map),
    );
    if (actor != userId || revision != _revision) {
      throw StateError('Store request superseded');
    }
    if (!result.enabled && actor != null) {
      final value = Map<String, dynamic>.from(
        await rpc('dopmi_store_preview_catalog', {'p_filters': {}}) as Map,
      );
      if (actor != userId || revision != _revision) {
        throw StateError('Store request superseded');
      }
      // A preview response must identify itself. Never interpret it as commerce.
      if (value['preview'] != true) {
        throw const FormatException('Vista inválida');
      }
      result = StoreCatalog.fromJson(value);
      if (result.enabled &&
          result.products.any(
            (p) =>
                p.assetKey != 'croquetas-banner-pet' ||
                !RegExp(r'\bTEST\b').hasMatch(p.name) ||
                !RegExp(r'\bTEST\b').hasMatch(p.brand),
          )) {
        throw const FormatException('Catálogo TEST inválido');
      }
    }
    _catalogActor = actor;
    _lastCatalog = result;
    return result;
  }

  @override
  Future<Uri?> productLink(String productId) async {
    final actor = userId;
    final catalog = _lastCatalog;
    if (_catalogActor != actor || catalog == null || !catalog.enabled) {
      return null;
    }
    if (catalog.preview &&
        (!catalog.externalLinksEnabled ||
            actor == null ||
            !catalog.products.any((product) => product.id == productId))) {
      return null;
    }
    final value = await rpc(
      catalog.preview
          ? 'dopmi_store_preview_product_link'
          : 'dopmi_store_product_link',
      {(catalog.preview ? 'p_id' : 'product_id'): productId},
    );
    if (actor != userId ||
        !identical(_lastCatalog, catalog) ||
        !catalog.enabled) {
      return null;
    }
    if (value == null) return null;
    final uri = Uri.tryParse(value as String);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        (uri.hasPort && uri.port != 443) ||
        (catalog.preview && uri.hasQuery)) {
      throw const FormatException('Enlace comercial inválido');
    }
    return uri;
  }
}

class SupabaseStoreRepository extends RpcStoreRepository {
  SupabaseStoreRepository(SupabaseClient client)
    : super(
        currentUser: () => client.auth.currentUser?.id,
        changes: client.auth.onAuthStateChange
            .map((event) => event.session?.user.id)
            .distinct(),
        rpc: (name, params) async => client.rpc(name, params: params),
      );
}

final storeRepositoryProvider = Provider<StoreRepository>(
  (ref) => SupabaseStoreRepository(Supabase.instance.client),
);
final storeActorProvider = StreamProvider<String?>((ref) async* {
  final repository = ref.watch(storeRepositoryProvider);
  yield repository.userId;
  yield* repository.actorChanges;
});
final storeCatalogProvider = FutureProvider.autoDispose<StoreCatalog>((
  ref,
) async {
  ref.watch(storeActorProvider);
  final repository = ref.watch(storeRepositoryProvider);
  final actor = repository.userId;
  final observer = _StoreLifecycle(() => ref.invalidateSelf());
  WidgetsBinding.instance.addObserver(observer);
  Timer? expiry;
  var disposed = false;
  ref.onDispose(() {
    disposed = true;
    WidgetsBinding.instance.removeObserver(observer);
    expiry?.cancel();
  });
  final result = await repository.catalog();
  if (disposed) throw StateError('Store request superseded');
  if (repository.userId != actor) throw StateError('Store identity changed');
  if (result.preview && result.enabled && result.expiresAt != null) {
    expiry = Timer(
      result.expiresAt!.difference(DateTime.now()),
      ref.invalidateSelf,
    );
  }
  return result;
});

class _StoreLifecycle extends WidgetsBindingObserver {
  _StoreLifecycle(this.refresh);
  final VoidCallback refresh;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }
}

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
