import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/design_tokens.dart';
import '../../core/donor_canvas.dart';
import '../../core/donor_notification_button.dart';
import '../../core/warm_filter_dialog.dart';
import 'store_kit_item.dart';
import 'store_repository.dart';

const _storeCream = Color(0xfffaf1e7);
const _storeBorder = Color(0xffeaded3);

/// Gate for every navigation entry/banner. This does not authorize the route:
/// StoreScreen and the link RPC independently enforce current availability.
class StoreEntry extends ConsumerWidget {
  const StoreEntry.visible({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actor = ref.watch(storeActorProvider).asData?.value;
    return ref
        .watch(storeCatalogProvider)
        .when(
          skipLoadingOnRefresh: false,
          skipLoadingOnReload: false,
          data: (catalog) =>
              catalog.enabled &&
                  ref.watch(storeActorProvider).hasValue &&
                  ref.watch(storeRepositoryProvider).userId == actor
              ? child
              : const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          loading: () => const SizedBox.shrink(),
        );
  }
}

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key, this.navigation});
  final Widget? navigation;
  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  String? selectionScope;
  _StoreSelection selection = _StoreSelection();
  @override
  Widget build(BuildContext context) {
    final actor = ref.watch(storeActorProvider).asData?.value;
    final catalog = ref.watch(storeCatalogProvider);
    final resolved = catalog.asData?.value;
    final actorCurrent =
        resolved != null &&
        ref.watch(storeActorProvider).hasValue &&
        ref.watch(storeRepositoryProvider).userId == actor;
    if (resolved != null) {
      final scope = '$actor:${resolved.preview}';
      if (selectionScope != scope) {
        selectionScope = scope;
        selection = _StoreSelection();
      }
    }
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: widget.navigation,
      body: DonorCanvas(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
                child: Row(
                  children: [
                    SvgPicture.asset(
                      'assets/profile/logo-paw-naranja.svg',
                      width: 30,
                      height: 30,
                      excludeFromSemantics:
                          resolved?.enabled == true && actorCurrent,
                      semanticsLabel: 'Dopmi',
                    ),
                    const SizedBox(width: 10),
                    if (resolved != null && resolved.enabled && actorCurrent)
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            resolved.preview
                                ? 'Vista previa de Tienda'
                                : 'Tienda Dopmi',
                            style: const TextStyle(
                              fontFamily: DopmiTokens.bodyFont,
                              fontSize: 24,
                              height: 1.12,
                              letterSpacing: -.6,
                              fontWeight: FontWeight.w800,
                              color: DopmiTokens.ink,
                            ),
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    const DonorNotificationButton(),
                  ],
                ),
              ),
              Expanded(
                child: catalog.when(
                  skipLoadingOnRefresh: false,
                  skipLoadingOnReload: false,
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'No pudimos cargar la Tienda. Intenta de nuevo.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () =>
                                ref.invalidate(storeCatalogProvider),
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (value) => value.enabled && actorCurrent
                      ? _StoreContent(
                          key: ValueKey('$actor:${value.preview}'),
                          catalog: value,
                          actor: actor,
                          selection: selection,
                        )
                      : const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'La Tienda Dopmi todavía no está disponible.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const storeAgeLabels = {
  'puppy': 'Cachorro',
  'adult': 'Adulto',
  'senior': 'Senior',
};
const _storeCatAgeLabels = {
  'puppy': 'Gatito',
  'adult': 'Adulto',
  'senior': 'Senior',
};
const storeSizeLabels = {
  'small': 'Chico',
  'medium': 'Mediano',
  'large': 'Grande',
};

bool _hasStoreFamily(StoreProductGroup group) =>
    group.primary.familyId != null && group.primary.familyName != null;

class _StoreSelection {
  String species = 'dog';
  String query = '';
  String? age, size, flavor;
  double? weightKg;
  Set<String> brands = {};
  bool descending = false;
  double offset = 0;
}

class _StoreContent extends ConsumerStatefulWidget {
  const _StoreContent({
    super.key,
    required this.catalog,
    required this.actor,
    required this.selection,
  });
  final StoreCatalog catalog;
  final String? actor;
  final _StoreSelection selection;
  @override
  ConsumerState<_StoreContent> createState() => _StoreContentState();
}

class _StoreContentState extends ConsumerState<_StoreContent> {
  late final ScrollController scroll;
  late final TextEditingController search;
  ModalRoute<Object?>? catalogOverlay;
  MaterialPageRoute<bool>? amazonHandoff;
  String get species => widget.selection.species;
  set species(String value) => widget.selection.species = value;
  String? get age => widget.selection.age;
  set age(String? value) => widget.selection.age = value;
  String? get size => widget.selection.size;
  set size(String? value) => widget.selection.size = value;
  String? get flavor => widget.selection.flavor;
  set flavor(String? value) => widget.selection.flavor = value;
  double? get weightKg => widget.selection.weightKg;
  set weightKg(double? value) => widget.selection.weightKg = value;
  Set<String> get brands => widget.selection.brands;
  set brands(Set<String> value) => widget.selection.brands = value;
  bool get descending => widget.selection.descending;
  set descending(bool value) => widget.selection.descending = value;
  String? opening;
  @override
  void initState() {
    super.initState();
    search = TextEditingController(text: widget.selection.query);
    scroll = ScrollController(
      initialScrollOffset: widget.selection.offset,
      keepScrollOffset: false,
    );
    scroll.addListener(() => widget.selection.offset = scroll.offset);
  }

  @override
  void dispose() {
    removeCatalogRoutes(catalogOverlay);
    search.dispose();
    scroll.dispose();
    super.dispose();
  }

  void removeCatalogRoutes(ModalRoute<Object?>? catalogRoute) {
    final routes = [amazonHandoff, catalogRoute];
    // Remove only routes owned by this catalog after the navigator frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final route in routes) {
        if (route != null && route.isActive) {
          route.navigator?.removeRoute(route);
        }
      }
    });
  }

  bool canOpenProduct(
    String productId,
    StoreCatalog catalog,
    BuildContext feedbackContext,
  ) {
    if (!mounted ||
        !feedbackContext.mounted ||
        ModalRoute.of(feedbackContext)?.isCurrent != true ||
        !catalog.enabled ||
        (catalog.preview && !catalog.externalLinksEnabled)) {
      return false;
    }
    final actor = ref.read(storeActorProvider).asData;
    return actor != null &&
        actor.value == widget.actor &&
        ref.read(storeRepositoryProvider).userId == widget.actor &&
        identical(ref.read(storeCatalogProvider).asData?.value, catalog) &&
        (catalog.products.any((product) => product.id == productId) ||
            catalog.kitItems.any((item) => item.id == productId));
  }

  Future<void> openProduct(
    String productId,
    BuildContext feedbackContext,
  ) async {
    final catalog = widget.catalog;
    if (opening != null ||
        !canOpenProduct(productId, catalog, feedbackContext)) {
      return;
    }
    setState(() => opening = productId);
    try {
      if (catalog.amazonProductLinks) {
        final confirmed = await confirmAmazonHandoff(feedbackContext);
        if (!confirmed ||
            !feedbackContext.mounted ||
            !canOpenProduct(productId, catalog, feedbackContext)) {
          return;
        }
      }
      final repository = ref.read(storeRepositoryProvider);
      final link = await repository.productLink(productId);
      if (!feedbackContext.mounted ||
          !canOpenProduct(productId, catalog, feedbackContext) ||
          repository.userId != widget.actor) {
        return;
      }
      if (link == null) throw StateError('not available');
      final opened = await ref.read(storeLinkOpenerProvider)(link);
      if (!opened) throw StateError('not opened');
      // Returning from the merchant is not a purchase confirmation.
    } catch (_) {
      if (feedbackContext.mounted &&
          canOpenProduct(productId, catalog, feedbackContext)) {
        ScaffoldMessenger.of(feedbackContext).showSnackBar(
          const SnackBar(
            content: Text(
              'No pudimos abrir el comercio. El producto puede haber dejado de estar disponible. Intenta de nuevo.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => opening = null);
    }
  }

  Future<bool> confirmAmazonHandoff(BuildContext sourceContext) async {
    final route = catalogPage<bool>(const _StoreAmazonHandoff());
    amazonHandoff = route;
    try {
      return await Navigator.of(
            sourceContext,
            rootNavigator: true,
          ).push(route) ??
          false;
    } finally {
      if (identical(amazonHandoff, route)) amazonHandoff = null;
    }
  }

  Future<T?> showCatalogOverlay<T>(ModalRoute<T> route) async {
    if (catalogOverlay != null || !widget.catalog.enabled) return null;
    FocusScope.of(context).unfocus();
    catalogOverlay = route;
    try {
      return await Navigator.of(context, rootNavigator: true).push(route);
    } finally {
      if (identical(catalogOverlay, route)) catalogOverlay = null;
    }
  }

  MaterialPageRoute<T> catalogPage<T>(Widget page) {
    final catalog = widget.catalog;
    final actor = widget.actor;
    return MaterialPageRoute<T>(
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          // Observe access in the visible route, even if the catalog is offstage.
          final currentActor = ref.watch(storeActorProvider).asData;
          final currentCatalog = ref.watch(storeCatalogProvider).asData?.value;
          if (currentActor == null ||
              currentActor.value != actor ||
              ref.watch(storeRepositoryProvider).userId != actor ||
              !identical(currentCatalog, catalog) ||
              !catalog.enabled) {
            removeCatalogRoutes(catalogOverlay);
            return Scaffold(
              appBar: AppBar(),
              body: const Center(
                child: Text('La ficha dejó de estar disponible.'),
              ),
            );
          }
          return child!;
        },
        child: page,
      ),
    );
  }

  Future<void> showCatalogPage(Widget page) async {
    await showCatalogOverlay(catalogPage<void>(page));
  }

  Future<void> showProductOptions(StoreProductGroup group) {
    final catalog = widget.catalog;
    return showCatalogPage(
      _StoreProductDetail(
        group: group,
        initialProduct: catalog.preview
            ? _selectStorePreviewArtwork(
                group.primary,
                group.variants.skip(1),
                ref.read(storePreviewImageProvider),
              ).product
            : group.primary,
        preview: catalog.preview,
        canOpen: !catalog.preview || catalog.externalLinksEnabled,
        amazonProductLinks: catalog.amazonProductLinks,
        onOpen: openProduct,
      ),
    );
  }

  Future<void> showFilters() async {
    if (catalogOverlay != null) return;
    final filterSpecies = species;
    String? draftAge = age, draftSize = size, draftFlavor = flavor;
    double? draftWeight = weightKg;
    final draftBrands = {...brands};
    final speciesProducts = widget.catalog.products.where(
      (item) => item.species == filterSpecies,
    );
    final availableBrands =
        speciesProducts.map((item) => item.brand).toSet().toList()..sort();
    final availableFlavors =
        speciesProducts
            .map((item) => item.flavor)
            .whereType<String>()
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final availableWeights =
        speciesProducts.map((item) => item.weightKg).toSet().toList()..sort();
    if (!availableFlavors.contains(draftFlavor)) draftFlavor = null;
    if (!availableWeights.contains(draftWeight)) draftWeight = null;
    final weightsByFlavor = <String, Set<double>>{};
    for (final item in speciesProducts) {
      final itemFlavor = item.flavor;
      if (itemFlavor != null) {
        weightsByFlavor.putIfAbsent(itemFlavor, () => {}).add(item.weightKg);
      }
    }
    final route = DialogRoute<bool>(
      context: context,
      barrierColor: const Color(0x29000000),
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          Widget choices(
            Map<String, String> labels,
            String? selected,
            ValueChanged<String?> select, {
            bool sizes = false,
          }) => LayoutBuilder(
            builder: (context, bounds) {
              final width = MediaQuery.textScalerOf(context).scale(14) > 21
                  ? bounds.maxWidth
                  : (bounds.maxWidth - 24) / 3;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: labels.entries
                    .map(
                      (entry) => SizedBox(
                        width: width,
                        child: _StoreFilterChoice(
                          label: entry.value,
                          selected: selected == entry.key,
                          sizeIcon: sizes
                              ? const {
                                  'small': 18.0,
                                  'medium': 24.0,
                                  'large': 30.0,
                                }[entry.key]
                              : null,
                          onPressed: () =>
                              select(selected == entry.key ? null : entry.key),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          );
          return WarmFilterDialog(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 361,
                maxHeight: MediaQuery.sizeOf(context).height * .88,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Filtros',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cerrar filtros',
                          onPressed: () => Navigator.pop(context, false),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Edad',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    choices(
                      filterSpecies == 'cat'
                          ? _storeCatAgeLabels
                          : storeAgeLabels,
                      draftAge,
                      (value) => update(() => draftAge = value),
                    ),
                    if (filterSpecies == 'dog') ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Tamaño de Raza',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      choices(
                        storeSizeLabels,
                        draftSize,
                        (value) => update(() => draftSize = value),
                        sizes: true,
                      ),
                    ],
                    const SizedBox(height: 20),
                    const Text(
                      'Marca',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableBrands
                          .map(
                            (brand) => _StoreFilterChoice(
                              label: brand,
                              selected: draftBrands.contains(brand),
                              onPressed: () => update(
                                () => draftBrands.contains(brand)
                                    ? draftBrands.remove(brand)
                                    : draftBrands.add(brand),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    if (availableFlavors.isNotEmpty)
                      _StoreOptionSection(
                        title: 'Sabor',
                        options: [
                          for (final option in availableFlavors)
                            _StoreFilterChoice(
                              label: option,
                              selected: draftFlavor == option,
                              onPressed: () => update(() {
                                draftFlavor = draftFlavor == option
                                    ? null
                                    : option;
                                if (draftFlavor != null &&
                                    weightsByFlavor[draftFlavor]?.contains(
                                          draftWeight,
                                        ) !=
                                        true) {
                                  draftWeight = null;
                                }
                              }),
                            ),
                        ],
                      ),
                    if (availableWeights.length > 1)
                      _StoreOptionSection(
                        title: 'Presentación',
                        options: [
                          for (final option in availableWeights)
                            if (draftFlavor == null ||
                                weightsByFlavor[draftFlavor]?.contains(
                                      option,
                                    ) ==
                                    true)
                              _StoreFilterChoice(
                                label: storeWeightLabel(option),
                                selected: draftWeight == option,
                                onPressed: () => update(() {
                                  draftWeight = draftWeight == option
                                      ? null
                                      : option;
                                }),
                              ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: DopmiTokens.orangeButton,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Aplicar filtros'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: DopmiTokens.ink,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        draftAge = null;
                        draftSize = null;
                        draftFlavor = null;
                        draftWeight = null;
                        draftBrands.clear();
                        Navigator.pop(context, true);
                      },
                      child: const Text('Limpiar filtros'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    final applied = await showCatalogOverlay(route);
    if (applied == true && mounted && widget.catalog.enabled) {
      setState(() {
        age = draftAge;
        if (filterSpecies == 'dog') size = draftSize;
        flavor = draftFlavor;
        weightKg = draftWeight;
        brands = draftBrands;
      });
    }
  }

  void selectSpecies(String value) {
    if (species == value) return;
    setState(() {
      species = value;
      brands = brands.intersection(
        widget.catalog.products
            .where((item) => item.species == value)
            .map((item) => item.brand)
            .toSet(),
      );
      flavor = null;
      weightKg = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final products = filterStoreProducts(
      widget.catalog.products,
      species: species,
      age: age,
      size: species == 'dog' ? size : null,
      brands: brands,
      descending: descending,
      query: widget.selection.query,
      flavor: flavor,
      weightKg: weightKg,
    );
    final groups = groupStoreProducts(products);
    final activeFilters =
        age != null ||
        (species == 'dog' && size != null) ||
        brands.isNotEmpty ||
        flavor != null ||
        weightKg != null;
    final resultLabel = groups.length == 1
        ? '1 producto'
        : '${groups.length} productos';
    final showVariantCount = groups.any(_hasStoreFamily);
    final kitItems = widget.catalog.kitItems
        .where((item) => item.species.contains(species))
        .toList(growable: false);
    final kitTitle = species == 'dog'
        ? 'Kit de adopción para perros'
        : 'Kit de adopción para gatos';
    return SingleChildScrollView(
      key: PageStorageKey(
        'store-scroll-${widget.actor}-${widget.catalog.preview}',
      ),
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StoreHero(),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('store-search'),
            controller: search,
            textInputAction: TextInputAction.search,
            onChanged: (value) =>
                setState(() => widget.selection.query = value),
            style: const TextStyle(fontSize: 14, color: DopmiTokens.ink),
            decoration: InputDecoration(
              labelText: species == 'dog'
                  ? 'Buscar para perros'
                  : 'Buscar para gatos',
              hintText: 'Nombre, marca, sabor o peso',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpiar búsqueda',
                      onPressed: () {
                        search.clear();
                        setState(() => widget.selection.query = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _storeBorder),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _StoreCatalogNotice(
            preview: widget.catalog.preview,
            externalLinksEnabled: widget.catalog.externalLinksEnabled,
            amazonProductLinks: widget.catalog.amazonProductLinks,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final choice in const [
                      ('dog', 'Perros'),
                      ('cat', 'Gatos'),
                    ])
                      Semantics(
                        selected: species == choice.$1,
                        button: true,
                        child: TextButton(
                          key: ValueKey('store-species-${choice.$1}'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            minimumSize: const Size(0, 44),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            backgroundColor: species == choice.$1
                                ? DopmiTokens.cafeStrong
                                : Colors.white,
                            foregroundColor: species == choice.$1
                                ? Colors.white
                                : DopmiTokens.ink,
                            side: BorderSide(
                              color: species == choice.$1
                                  ? DopmiTokens.cafeStrong
                                  : _storeBorder,
                            ),
                            textStyle: TextStyle(
                              fontFamily: DopmiTokens.bodyFont,
                              fontSize: 14,
                              height: 1.1,
                              fontWeight: species == choice.$1
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                          onPressed: () => selectSpecies(choice.$1),
                          child: Text(choice.$2),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                key: const ValueKey('store-sort'),
                tooltip:
                    'Ordenar: ${descending ? 'Mayor a menor kg' : 'Menor a mayor kg'}',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: DopmiTokens.ink,
                  side: const BorderSide(color: _storeBorder),
                ),
                onPressed: () => setState(() => descending = !descending),
                icon: const Icon(Icons.swap_vert_rounded, size: 21),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: activeFilters ? 'Filtros activos' : 'Filtros',
                style: IconButton.styleFrom(
                  backgroundColor: activeFilters
                      ? DopmiTokens.saffronSoft
                      : Colors.white,
                  foregroundColor: DopmiTokens.ink,
                  side: BorderSide(
                    color: activeFilters ? DopmiTokens.ink : _storeBorder,
                  ),
                ),
                onPressed: showFilters,
                icon: const Icon(Icons.tune_rounded, size: 20),
              ),
            ],
          ),
          if (kitItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            _StoreKitEntry(
              title: kitTitle,
              onTap: () => showCatalogPage(
                _StoreKitScreen(
                  title: kitTitle,
                  items: kitItems,
                  canOpen:
                      !widget.catalog.preview ||
                      widget.catalog.externalLinksEnabled,
                  onOpen: openProduct,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Semantics(
                header: true,
                child: Text(
                  species == 'dog'
                      ? 'Alimento para perros'
                      : 'Alimento para gatos',
                  style: const TextStyle(
                    fontFamily: DopmiTokens.legacyDisplayFont,
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                    height: 1.16,
                    color: DopmiTokens.ink,
                  ),
                ),
              ),
              Text(
                showVariantCount
                    ? '$resultLabel · ${products.length == 1 ? '1 variante' : '${products.length} variantes'}'
                    : resultLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: DopmiTokens.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (products.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No encontramos alimentos. Cambia la búsqueda o ajusta los filtros.',
              ),
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  MediaQuery.textScalerOf(context).scale(14) > 21 ||
                      constraints.maxWidth < 280
                  ? 1
                  : 2;
              final width =
                  (constraints.maxWidth - (columns - 1) * 14) / columns;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: groups
                    .map(
                      (group) => SizedBox(
                        width: width,
                        child: _StoreCard(
                          key: ValueKey('store-family-${group.id}'),
                          group: group,
                          preview: widget.catalog.preview,
                          busy: group.variants.any(
                            (variant) => opening == variant.id,
                          ),
                          onTap: opening == null
                              ? () => showProductOptions(group)
                              : null,
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StoreKitEntry extends StatelessWidget {
  const _StoreKitEntry({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _storeCream,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _storeBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('store-kit-entry'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.inventory_2_outlined, color: DopmiTokens.ink),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: DopmiTokens.ink,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: DopmiTokens.ink),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreKitScreen extends StatefulWidget {
  const _StoreKitScreen({
    required this.title,
    required this.items,
    required this.canOpen,
    required this.onOpen,
  });

  final String title;
  final List<StoreKitItem> items;
  final bool canOpen;
  final Future<void> Function(String, BuildContext) onOpen;

  @override
  State<_StoreKitScreen> createState() => _StoreKitScreenState();
}

class _StoreKitScreenState extends State<_StoreKitScreen> {
  String? openingId;

  Future<void> openItem(String id) async {
    if (openingId != null || !widget.canOpen) return;
    setState(() => openingId = id);
    try {
      await widget.onOpen(id, context);
    } finally {
      if (mounted) setState(() => openingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('store-kit-screen'),
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: DopmiTokens.ink,
        leading: const BackButton(),
      ),
      body: DonorCanvas(
        child: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontFamily: DopmiTokens.legacyDisplayFont,
                        fontSize: 27,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                        color: DopmiTokens.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Cada artículo se compra por separado en Amazon México. '
                    'Como afiliado de Amazon, DopMi puede recibir una '
                    'comisión por compras elegibles.',
                    style: TextStyle(height: 1.4, color: DopmiTokens.muted),
                  ),
                  for (final item in widget.items)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _StoreKitCard(
                        item: item,
                        opening: openingId == item.id,
                        onTap: widget.canOpen && openingId == null
                            ? () => openItem(item.id)
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StoreKitCard extends StatelessWidget {
  const _StoreKitCard({
    required this.item,
    required this.opening,
    required this.onTap,
  });

  final StoreKitItem item;
  final bool opening;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final image = item.imageUri;
    const missingImage = Icon(
      Icons.image_not_supported_outlined,
      color: DopmiTokens.muted,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _storeBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox.square(
                  dimension: 76,
                  child: image == null
                      ? missingImage
                      : Image.network(
                          image.toString(),
                          fit: BoxFit.contain,
                          excludeFromSemantics: true,
                          errorBuilder: (_, _, _) => missingImage,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.brand,
                        style: const TextStyle(
                          fontSize: 12,
                          color: DopmiTokens.muted,
                        ),
                      ),
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: DopmiTokens.ink,
                        ),
                      ),
                      Text(
                        item.presentation,
                        style: const TextStyle(color: DopmiTokens.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              key: ValueKey('store-kit-amazon-${item.id}'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                foregroundColor: DopmiTokens.cafeStrong,
                side: const BorderSide(color: _storeBorder),
              ),
              onPressed: onTap,
              child: Text(
                opening ? 'Abriendo Amazon México…' : 'Ver en Amazon México',
                textAlign: TextAlign.center,
              ),
            ),
            const Text(
              'Enlace de afiliado',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: DopmiTokens.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreHero extends StatelessWidget {
  const _StoreHero();

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
    return LayoutBuilder(
      builder: (context, bounds) {
        final photoWidth = largeText ? 0.0 : bounds.maxWidth * .43;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: _storeCream,
            border: Border.all(color: _storeBorder),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(1),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(23),
              child: Stack(
                children: [
                  if (photoWidth > 0)
                    Positioned(
                      top: 0,
                      bottom: 0,
                      right: 0,
                      width: photoWidth,
                      child: Image.asset(
                        'assets/store/store-home.png',
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: Color(0xffead8c6),
                          child: Center(
                            child: Icon(
                              Icons.pets_rounded,
                              size: 36,
                              color: DopmiTokens.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Container(
                    constraints: const BoxConstraints(minHeight: 132),
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.fromLTRB(16, 18, photoWidth + 12, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: const Text(
                            'Lo esencial para su nueva casa',
                            style: TextStyle(
                              fontFamily: DopmiTokens.legacyDisplayFont,
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -.5,
                              height: 1.02,
                              color: DopmiTokens.ink,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Alimento para cada etapa.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                            color: DopmiTokens.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StoreCatalogNotice extends StatelessWidget {
  const _StoreCatalogNotice({
    required this.preview,
    required this.externalLinksEnabled,
    required this.amazonProductLinks,
  });

  final bool preview;
  final bool externalLinksEnabled;
  final bool amazonProductLinks;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.only(top: 1, left: 2),
        child: Icon(
          Icons.info_outline_rounded,
          size: 17,
          color: DopmiTokens.muted,
        ),
      ),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          amazonProductLinks
              ? 'Fotos de Amazon México. Consulta disponibilidad y compra en Amazon.'
              : preview
              ? 'Catálogo TEST. No permite compras reales. Imágenes de referencia.'
                    '${externalLinksEnabled ? ' Sólo abre destinos de prueba autorizados.' : ''}'
              : 'Compra y paga en el comercio. Dopmi puede recibir una comisión por compras que cumplan los requisitos.',
          style: const TextStyle(
            fontFamily: DopmiTokens.bodyFont,
            fontSize: 12,
            height: 1.4,
            color: DopmiTokens.muted,
          ),
        ),
      ),
    ],
  );
}

class _StoreOptionSection extends StatelessWidget {
  const _StoreOptionSection({required this.title, required this.options});

  final String title;
  final List<Widget> options;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, children: options),
      ],
    ),
  );
}

class _StoreProductDetail extends StatefulWidget {
  const _StoreProductDetail({
    required this.group,
    required this.initialProduct,
    required this.preview,
    required this.canOpen,
    required this.amazonProductLinks,
    required this.onOpen,
  });

  final StoreProductGroup group;
  final StoreProduct initialProduct;
  final bool preview;
  final bool canOpen;
  final bool amazonProductLinks;
  final Future<void> Function(String, BuildContext) onOpen;

  @override
  State<_StoreProductDetail> createState() => _StoreProductDetailState();
}

class _StoreProductDetailState extends State<_StoreProductDetail> {
  final variantsByFlavor = <String?, List<StoreProduct>>{};
  late StoreProduct selected;
  bool opening = false;

  @override
  void initState() {
    super.initState();
    for (final product in widget.group.variants) {
      variantsByFlavor.putIfAbsent(product.flavor, () => []).add(product);
    }
    selected = widget.initialProduct;
  }

  Future<void> openSelected() async {
    if (opening || !widget.canOpen) return;
    setState(() => opening = true);
    try {
      await widget.onOpen(selected.id, context);
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flavor = selected.flavor;
    final options = variantsByFlavor[flavor]!;
    final weights = <double>{};
    final sameWeight = options.any((option) => !weights.add(option.weightKg));
    final weight = storeWeightLabel(selected.weightKg);
    final selection = flavor == null ? weight : '$flavor · $weight';
    final action = opening
        ? 'Abriendo comercio…'
        : !widget.canOpen
        ? 'Salida de prueba no habilitada'
        : widget.amazonProductLinks
        ? 'Ver producto en Amazon México'
        : widget.preview
        ? 'Abrir destino TEST'
        : 'Ver en ${selected.merchantName}';
    return Scaffold(
      key: const ValueKey('store-product-detail'),
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: DopmiTokens.ink,
        leading: IconButton(
          tooltip: 'Cerrar opciones',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          widget.preview ? 'Vista previa TEST' : 'Tienda Dopmi',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      body: DonorCanvas(
        child: SafeArea(
          top: false,
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      selected.brand,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: DopmiTokens.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Semantics(
                      header: true,
                      child: Text(
                        widget.group.name,
                        style: const TextStyle(
                          fontFamily: DopmiTokens.legacyDisplayFont,
                          fontSize: 29,
                          fontWeight: FontWeight.w600,
                          height: 1.12,
                          color: DopmiTokens.ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _StoreProductArtwork(
                      product: selected,
                      preview: widget.preview,
                      detail: true,
                    ),
                    if (variantsByFlavor.keys.any((value) => value != null))
                      _StoreOptionSection(
                        title: 'Sabor',
                        options: [
                          for (final option in variantsByFlavor.keys)
                            _StoreFilterChoice(
                              key: ValueKey('store-flavor-$option'),
                              label: option ?? 'Sin sabor especificado',
                              selected: flavor == option,
                              onPressed: opening
                                  ? null
                                  : () {
                                      if (flavor == option) return;
                                      final available =
                                          variantsByFlavor[option]!;
                                      final sameSize = available.where(
                                        (item) =>
                                            item.weightKg == selected.weightKg,
                                      );
                                      setState(() {
                                        selected =
                                            sameSize.firstOrNull ??
                                            available.first;
                                      });
                                    },
                            ),
                        ],
                      ),
                    _StoreOptionSection(
                      title: 'Presentación',
                      options: [
                        for (final option in options)
                          _StoreFilterChoice(
                            key: ValueKey('store-variant-${option.id}'),
                            label: sameWeight
                                ? '${storeWeightLabel(option.weightKg)} · ${option.name}'
                                : storeWeightLabel(option.weightKg),
                            selected: selected.id == option.id,
                            onPressed: opening
                                ? null
                                : () => setState(() => selected = option),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: _storeBorder)),
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(18, 10, 18, 12),
          child: Align(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 524),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      selection,
                      key: const ValueKey('store-selected-variant'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: DopmiTokens.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: DopmiTokens.cafeStrong,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    onPressed: widget.canOpen && !opening ? openSelected : null,
                    child: Text(action, textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    widget.amazonProductLinks
                        ? 'Enlace de afiliado. Como afiliado de Amazon, DopMi puede recibir una comisión por compras elegibles.'
                        : widget.preview
                        ? 'Catálogo TEST. No permite compras reales.'
                        : 'Consulta el precio y compra en ${selected.merchantName}.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: DopmiTokens.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StoreAmazonHandoff extends StatelessWidget {
  const _StoreAmazonHandoff();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('store-amazon-handoff'),
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: DopmiTokens.ink,
        leading: const BackButton(),
      ),
      body: DonorCanvas(
        child: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                children: [
                  Semantics(
                    header: true,
                    child: const Text(
                      '¿Dónde se paga?',
                      style: TextStyle(
                        fontFamily: DopmiTokens.legacyDisplayFont,
                        fontSize: 30,
                        height: 1.12,
                        fontWeight: FontWeight.w600,
                        color: DopmiTokens.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _StoreAmazonJourney(),
                  const SizedBox(height: 20),
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 21,
                        backgroundColor: DopmiTokens.saffronSoft,
                        foregroundColor: DopmiTokens.cafeStrong,
                        child: Icon(Icons.link_rounded, size: 23),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Código de afiliado incluido',
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.2,
                                fontWeight: FontWeight.w700,
                                color: DopmiTokens.ink,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Puedes pagar sin escribirlo.',
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.3,
                                color: DopmiTokens.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Como afiliado de Amazon, DopMi puede recibir una comisión por compras elegibles.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.3,
                      color: DopmiTokens.muted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: DopmiTokens.cafeStrong,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            'Ir a Amazon México',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.open_in_new_rounded, size: 18),
                      ],
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: DopmiTokens.cafeStrong,
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Seguir en DopMi'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StoreAmazonJourney extends StatelessWidget {
  const _StoreAmazonJourney();

  @override
  Widget build(BuildContext context) {
    final stacked = MediaQuery.textScalerOf(context).scale(16) > 26;
    final dopmi = _StoreJourneyStep(
      name: 'DopMi',
      icon: SvgPicture.asset(
        'assets/profile/logo-paw-naranja.svg',
        width: 23,
        height: 23,
        excludeFromSemantics: true,
      ),
    );
    const amazon = _StoreJourneyStep(
      name: 'Amazon México',
      detail: 'Precio y pago',
      icon: Icon(Icons.shopping_bag_outlined, size: 24),
    );
    return Semantics(
      key: const ValueKey('store-amazon-journey'),
      label: 'De DopMi a Amazon México. Ahí ves el precio y haces el pago.',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _storeCream,
          border: Border.all(color: _storeBorder),
          borderRadius: BorderRadius.circular(20),
        ),
        child: stacked
            ? Column(
                children: [
                  dopmi,
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Icon(
                      Icons.arrow_downward_rounded,
                      color: DopmiTokens.cafeStrong,
                    ),
                  ),
                  amazon,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: dopmi),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(8, 11, 8, 0),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: DopmiTokens.cafeStrong,
                    ),
                  ),
                  const Expanded(child: amazon),
                ],
              ),
      ),
    );
  }
}

class _StoreJourneyStep extends StatelessWidget {
  const _StoreJourneyStep({
    required this.name,
    required this.icon,
    this.detail,
  });

  final String name;
  final Widget icon;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 23,
          backgroundColor: Colors.white,
          foregroundColor: DopmiTokens.cafeStrong,
          child: icon,
        ),
        const SizedBox(height: 8),
        Text(
          name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            height: 1.2,
            color: DopmiTokens.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (detail != null)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              detail!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.25,
                color: DopmiTokens.muted,
              ),
            ),
          ),
      ],
    );
  }
}

class _StoreFilterChoice extends StatelessWidget {
  const _StoreFilterChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.sizeIcon,
  });
  final String label;
  final bool selected;
  final VoidCallback? onPressed;
  final double? sizeIcon;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? DopmiTokens.saffronSoft : Colors.white,
        foregroundColor: DopmiTokens.ink,
        minimumSize: const Size(48, 44),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        side: BorderSide(color: selected ? DopmiTokens.ink : DopmiTokens.line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(sizeIcon == null ? 14 : 20),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      onPressed: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (sizeIcon != null) ...[
            SizedBox(
              height: 30,
              child: Center(
                child: SvgPicture.asset(
                  'assets/profile/notif-pet.svg',
                  width: sizeIcon,
                  height: sizeIcon,
                  excludeFromSemantics: true,
                  colorFilter: ColorFilter.mode(
                    selected ? DopmiTokens.purple : DopmiTokens.ink,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _StoreCard extends StatelessWidget {
  const _StoreCard({
    super.key,
    required this.group,
    required this.busy,
    required this.onTap,
    required this.preview,
  });
  final StoreProductGroup group;
  final bool busy;
  final VoidCallback? onTap;
  final bool preview;
  @override
  Widget build(BuildContext context) {
    final product = group.primary;
    final ages = product.species == 'cat' ? _storeCatAgeLabels : storeAgeLabels;
    final grouped = _hasStoreFamily(group);
    final flavors = group.variants
        .map((option) => option.flavor)
        .whereType<String>()
        .toSet();
    final flavorSummary = flavors.length > 3
        ? '${flavors.take(2).join(', ')} y ${flavors.length - 2} más'
        : flavors.join(', ');
    final presentationCount = group.variants.length == 1
        ? '1 variante'
        : '${group.variants.length} variantes';
    final action = busy
        ? 'Abriendo comercio…'
        : grouped
        ? 'Ver opciones'
        : 'Ver detalle';
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: _storeBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(9, 9, 9, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StoreProductArtwork(
                product: product,
                preview: preview,
                previewAlternatives: group.variants.skip(1),
              ),
              const SizedBox(height: 12),
              Text(
                product.brand,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                  color: DopmiTokens.muted,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                group.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  height: 1.25,
                  color: DopmiTokens.ink,
                ),
              ),
              const SizedBox(height: 8),
              if (grouped && flavors.isNotEmpty) ...[
                Text(
                  flavorSummary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: DopmiTokens.muted,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    ages[product.age] ?? product.age,
                    style: const TextStyle(
                      fontSize: 12,
                      color: DopmiTokens.muted,
                    ),
                  ),
                  Text(
                    grouped
                        ? presentationCount
                        : storeWeightLabel(product.weightKg),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: DopmiTokens.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              const Divider(height: 1, color: _storeBorder),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      action,
                      style: TextStyle(
                        color: onTap == null
                            ? DopmiTokens.muted
                            : DopmiTokens.orangeButton,
                        fontSize: 12,
                        fontWeight: onTap == null
                            ? FontWeight.w500
                            : FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 3),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 15,
                      color: DopmiTokens.orangeButton,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

({StoreProduct product, StorePreviewArtwork? artwork})
_selectStorePreviewArtwork(
  StoreProduct primary,
  Iterable<StoreProduct> alternatives,
  StorePreviewArtwork? Function(String) getArtwork,
) {
  final primaryArtwork = getArtwork(primary.id);
  if (primaryArtwork?.kind == StorePreviewArtworkKind.photo) {
    return (product: primary, artwork: primaryArtwork);
  }
  for (final alternative in alternatives) {
    final artwork = getArtwork(alternative.id);
    if (artwork?.kind == StorePreviewArtworkKind.photo) {
      return (product: alternative, artwork: artwork);
    }
  }
  return (product: primary, artwork: primaryArtwork);
}

class _StoreProductArtwork extends ConsumerWidget {
  const _StoreProductArtwork({
    required this.product,
    required this.preview,
    this.detail = false,
    this.previewAlternatives = const [],
  });

  final StoreProduct product;
  final bool preview;
  final bool detail;
  final Iterable<StoreProduct> previewAlternatives;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (product: artworkProduct, artwork: previewArtwork) = preview
        ? _selectStorePreviewArtwork(
            product,
            previewAlternatives,
            ref.watch(storePreviewImageProvider),
          )
        : (product: product, artwork: null);
    final uri = Uri.tryParse(product.imageUrl);
    final ImageProvider<Object>? image = preview
        ? previewArtwork?.image
        : uri != null &&
              uri.scheme == 'https' &&
              uri.host.isNotEmpty &&
              uri.userInfo.isEmpty
        ? NetworkImage(uri.toString())
        : null;
    final credit = previewArtwork?.credit;
    final usesTemplate =
        previewArtwork?.kind == StorePreviewArtworkKind.template;
    return LayoutBuilder(
      builder: (context, bounds) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: detail
                ? (bounds.maxWidth * .69).clamp(170.0, 260.0).toDouble()
                : (bounds.maxWidth * .8).clamp(106.0, 164.0).toDouble(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(detail ? 20 : 13),
              child: ColoredBox(
                color: product.species == 'cat'
                    ? const Color(0xffedf0e8)
                    : _storeCream,
                child: image == null
                    ? const _StoreCategoryArtwork()
                    : usesTemplate
                    ? _StoreIllustratedPack(
                        key: ValueKey(
                          'store-product-illustration-${artworkProduct.id}',
                        ),
                        image: image,
                        product: artworkProduct,
                        detail: detail,
                      )
                    : Padding(
                        padding: EdgeInsets.all(detail ? 18 : 10),
                        child: Image(
                          key: ValueKey(
                            'store-product-image-${artworkProduct.id}',
                          ),
                          image: image,
                          fit: BoxFit.contain,
                          semanticLabel: detail
                              ? 'Empaque de ${artworkProduct.name}'
                              : null,
                          excludeFromSemantics: !detail,
                          errorBuilder: (_, _, _) =>
                              preview && image is NetworkImage
                              ? const Center(
                                  child: Text('Imagen no disponible'),
                                )
                              : const _StoreCategoryArtwork(),
                        ),
                      ),
              ),
            ),
          ),
          if (credit != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                credit,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: detail ? 12 : 10,
                  height: 1.15,
                  color: DopmiTokens.muted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StoreIllustratedPack extends StatelessWidget {
  const _StoreIllustratedPack({
    super.key,
    required this.image,
    required this.product,
    required this.detail,
  });

  final ImageProvider<Object> image;
  final StoreProduct product;
  final bool detail;

  @override
  Widget build(BuildContext context) {
    final weight = storeWeightLabel(product.weightKg);
    final flavor = product.flavor;
    final color = switch (product.brand) {
      'Cat Chow' || 'Dog Chow' => const Color(0xff3f5c4d),
      'Nupec' || 'Purina ONE' => const Color(0xff325867),
      'Whiskas' || 'Royal Canin' => const Color(0xff673e56),
      'Pedigree' || 'Gatina' => const Color(0xff795015),
      _ => const Color(0xff634535),
    };
    final labelColor = switch (product.age) {
      'puppy' => Color.lerp(color, const Color(0xff793d28), .55)!,
      'senior' => Color.lerp(color, const Color(0xff323047), .65)!,
      _ => color,
    };
    // Text on the illustration is also available in the surrounding UI.
    return Semantics(
      image: detail,
      label: detail ? '${product.brand} ${product.name}, $weight' : null,
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsets.all(detail ? 10 : 2),
        child: FittedBox(
          child: SizedBox(
            width: 144,
            height: 172,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: Image(image: image, fit: BoxFit.fill),
                ),
                Positioned(
                  top: 56,
                  width: 87,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: labelColor,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 6, 6, 5),
                      child: DefaultTextStyle(
                        style: const TextStyle(
                          fontFamily: DopmiTokens.bodyFont,
                          color: Colors.white,
                          height: 1.12,
                        ),
                        textAlign: TextAlign.center,
                        child: MediaQuery.withNoTextScaling(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  product.brand,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                product.name,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (flavor != null) ...[
                                const SizedBox(height: 3),
                                Text(
                                  flavor,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 8),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                weight,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StoreCategoryArtwork extends StatelessWidget {
  const _StoreCategoryArtwork();

  @override
  Widget build(BuildContext context) => const Center(
    child: SizedBox.square(
      dimension: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white70,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.pets_rounded, size: 30, color: DopmiTokens.muted),
      ),
    ),
  );
}
