import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/adoption_only_build.dart';
import 'store_review_catalog.dart';
import 'store_review_repository.dart';

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
    this.familyId,
    this.familyName,
    this.flavor,
    this.sizes = const [],
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
    familyId: _storeMetadata(value['family_id']),
    familyName: _storeMetadata(value['family_name']),
    flavor: _storeMetadata(value['flavor']),
    sizes: switch (value['sizes']) {
      final List<dynamic> sizes => List.unmodifiable(sizes.whereType<String>()),
      _ => const [],
    },
  );
  final String id, name, brand, species, age, size, imageUrl, merchantName;
  final double weightKg;
  final String? assetKey;
  final String? familyId, familyName, flavor;
  final List<String> sizes;
}

String? _storeMetadata(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;

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
    if (_catalogActor != actor ||
        catalog == null ||
        !catalog.enabled ||
        !catalog.products.any((product) => product.id == productId)) {
      return null;
    }
    if (catalog.preview && (!catalog.externalLinksEnabled || actor == null)) {
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

final storeRepositoryProvider = Provider<StoreRepository>((ref) {
  final client = Supabase.instance.client;
  if (!storeReviewAvailable) return SupabaseStoreRepository(client);
  return StoreReviewRepository(
    currentUser: () => client.auth.currentUser?.id,
    changes: client.auth.onAuthStateChange
        .map((event) => event.session?.user.id)
        .distinct(),
  );
});
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

enum StorePreviewArtworkKind { photo, illustration, template }

class StorePreviewArtwork {
  const StorePreviewArtwork(
    this.image, {
    required this.kind,
    required this.credit,
  });

  final ImageProvider<Object> image;
  final StorePreviewArtworkKind kind;
  final String credit;
}

final _storeReviewProductIds = storeReviewProducts
    .map((product) => product.id)
    .toSet();

StorePreviewArtwork? storeReviewArtworkFor(String id) {
  final source = storeReviewPhotoSources[id];
  if (source != null) {
    final (barcode, author) = source;
    return StorePreviewArtwork(
      AssetImage('assets/store/review-photos/$barcode.jpg'),
      kind: StorePreviewArtworkKind.photo,
      credit: 'Foto de $author · Open Pet Food Facts · CC BY-SA 3.0',
    );
  }
  if (id == 'whiskas-adult-3-1500') {
    return const StorePreviewArtwork(
      AssetImage('assets/store/review-packshot.png'),
      kind: StorePreviewArtworkKind.illustration,
      credit: 'Imagen ilustrativa',
    );
  }
  if (!_storeReviewProductIds.contains(id)) return null;
  return const StorePreviewArtwork(
    AssetImage('assets/store/review-pack-template.png'),
    kind: StorePreviewArtworkKind.template,
    credit: 'Imagen ilustrativa',
  );
}

/// The local review can supply artwork without enabling catalog links.
/// Server-authorized previews never load remote product images.
final storePreviewImageProvider =
    Provider<StorePreviewArtwork? Function(String)>(
      (ref) => storeReviewAvailable ? storeReviewArtworkFor : (_) => null,
    );

List<StoreProduct> filterStoreProducts(
  List<StoreProduct> source, {
  required String species,
  String? age,
  String? size,
  Set<String> brands = const {},
  bool descending = false,
  String query = '',
  String? flavor,
  double? weightKg,
}) {
  final search = _storeSearchText(query);
  final weightPattern = RegExp(r'\b(\d+(?:\.\d+)?) *(kg|g)\b');
  final searchWeights = weightPattern
      .allMatches(search)
      .map((match) => double.parse(match[1]!) / (match[2] == 'g' ? 1000 : 1))
      .toList();
  final terms = search
      .replaceAll(weightPattern, ' ')
      .split(' ')
      .where((word) => word.isNotEmpty)
      .toList();
  final result = source
      .where(
        (item) =>
            item.species == species &&
            (age == null || item.age == age) &&
            (size == null || item.size == size || item.sizes.contains(size)) &&
            (brands.isEmpty || brands.contains(item.brand)) &&
            (flavor == null || item.flavor == flavor) &&
            (weightKg == null || item.weightKg == weightKg) &&
            searchWeights.every((weight) => weight == item.weightKg) &&
            (terms.isEmpty || _matchesStoreQuery(item, terms)),
      )
      .toList();
  result.sort((a, b) {
    final order = a.weightKg.compareTo(b.weightKg) * (descending ? -1 : 1);
    return order == 0 ? a.id.compareTo(b.id) : order;
  });
  return result;
}

class StoreProductGroup {
  const StoreProductGroup._(this.id, this.name, this.variants);

  final String id, name;
  final List<StoreProduct> variants;
  StoreProduct get primary => variants.first;
}

/// Accepts variants already filtered and ordered by presentation. Older catalog
/// rows without complete grouping metadata retain their individual cards.
List<StoreProductGroup> groupStoreProducts(List<StoreProduct> products) {
  final groups =
      <
        (String, String, String, String, String, String, String),
        List<StoreProduct>
      >{};
  for (final product in products) {
    final hasFamily = product.familyId != null && product.familyName != null;
    final key = (
      hasFamily ? 'family' : 'product',
      hasFamily ? product.familyId! : product.id,
      hasFamily ? product.familyName! : product.name,
      product.species,
      product.brand,
      product.age,
      product.merchantName,
    );
    (groups[key] ??= []).add(product);
  }
  return [
    for (final entry in groups.entries)
      StoreProductGroup._(
        entry.value.first.id,
        entry.key.$3,
        List.unmodifiable(entry.value),
      ),
  ];
}

String storeWeightLabel(double kg) => kg < 1
    ? '${(kg * 1000).round()} g'
    : '${kg.toString().replaceFirst(RegExp(r'\.0$'), '')} kg';

bool _matchesStoreQuery(StoreProduct product, Iterable<String> terms) {
  final weight = storeWeightLabel(product.weightKg);
  final grams = '${(product.weightKg * 1000).round()} g';
  final text = _storeSearchText(
    '${product.brand} ${product.name} ${product.familyName ?? ''} '
    '${product.flavor ?? ''} $weight ${weight.replaceAll(' ', '')} '
    '$grams ${grams.replaceAll(' ', '')}',
  );
  return terms.every(text.contains);
}

String _storeSearchText(String value) {
  const accents = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };
  return value
      .toLowerCase()
      .replaceAllMapped(RegExp('[áéíóúüñ]'), (match) => accents[match[0]]!)
      .replaceAllMapped(RegExp(r'(\d),(?=\d)'), (match) => '${match[1]}.')
      .replaceAll(RegExp(r'[^a-z0-9.]+'), ' ')
      .trim();
}
