import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/design_tokens.dart';
import '../../core/donor_canvas.dart';
import '../../core/warm_filter_dialog.dart';
import '../../core/donor_notification_button.dart';
import 'store_repository.dart';

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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SvgPicture.asset(
                          'assets/profile/logo-paw-naranja.svg',
                          width: 40,
                          height: 40,
                          semanticsLabel: 'Dopmi',
                        ),
                      ),
                    ),
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
const storeSizeLabels = {
  'small': 'Chico',
  'medium': 'Mediano',
  'large': 'Grande',
};

class _StoreSelection {
  String species = 'dog';
  String? age, size;
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
  DialogRoute<bool>? filterRoute;
  String get species => widget.selection.species;
  set species(String value) => widget.selection.species = value;
  String? get age => widget.selection.age;
  set age(String? value) => widget.selection.age = value;
  String? get size => widget.selection.size;
  set size(String? value) => widget.selection.size = value;
  Set<String> get brands => widget.selection.brands;
  set brands(Set<String> value) => widget.selection.brands = value;
  bool get descending => widget.selection.descending;
  set descending(bool value) => widget.selection.descending = value;
  String? opening;
  @override
  void initState() {
    super.initState();
    scroll = ScrollController(
      initialScrollOffset: widget.selection.offset,
      keepScrollOffset: false,
    );
    scroll.addListener(() => widget.selection.offset = scroll.offset);
  }

  @override
  void dispose() {
    final route = filterRoute;
    final navigator = route?.navigator;
    if (route != null && navigator != null) {
      // The overlay belongs to this catalog/account. Remove only that route,
      // after the current navigator frame releases its lock.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigator.mounted && route.isActive) navigator.removeRoute(route);
      });
    }
    scroll.dispose();
    super.dispose();
  }

  Future<void> openProduct(StoreProduct product) async {
    if (opening != null ||
        !widget.catalog.enabled ||
        (widget.catalog.preview && !widget.catalog.externalLinksEnabled)) {
      return;
    }
    setState(() => opening = product.id);
    try {
      final repository = ref.read(storeRepositoryProvider);
      final link = await repository.productLink(product.id);
      if (!mounted || repository.userId != widget.actor) return;
      if (link == null) throw StateError('not available');
      final opened = await ref.read(storeLinkOpenerProvider)(link);
      if (!opened) throw StateError('not opened');
      // Returning from the merchant is not a purchase confirmation.
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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

  Future<void> showFilters() async {
    if (filterRoute != null) return;
    String? draftAge = age, draftSize = size;
    final draftBrands = {...brands};
    final availableBrands =
        widget.catalog.products
            .where((item) => item.species == species)
            .map((item) => item.brand)
            .toSet()
            .toList()
          ..sort();
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
                      storeAgeLabels,
                      draftAge,
                      (value) => update(() => draftAge = value),
                    ),
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
    filterRoute = route;
    final applied = await Navigator.of(
      context,
      rootNavigator: true,
    ).push(route);
    if (identical(filterRoute, route)) filterRoute = null;
    if (applied == true && mounted && widget.catalog.enabled) {
      setState(() {
        age = draftAge;
        size = draftSize;
        brands = draftBrands;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = filterStoreProducts(
      widget.catalog.products,
      species: species,
      age: age,
      size: size,
      brands: brands,
      descending: descending,
    );
    final activeFilters = age != null || size != null || brands.isNotEmpty;
    return SingleChildScrollView(
      key: PageStorageKey(
        'store-scroll-${widget.actor}-${widget.catalog.preview}',
      ),
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.catalog.preview ? 'Vista previa de Tienda' : 'Tienda Dopmi',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 32,
              height: 1.1,
              letterSpacing: -.64,
              fontWeight: FontWeight.w800,
              color: DopmiTokens.ink,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: DopmiTokens.saffronSoft,
              border: Border.all(color: DopmiTokens.line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              widget.catalog.preview
                  ? 'Catálogo TEST. No permite compras reales. ${widget.catalog.externalLinksEnabled ? 'Sólo abre destinos de prueba autorizados.' : 'Salida de prueba no habilitada.'}'
                  : 'Busca las croquetas de tu preferencia. Al seleccionar un producto, abrirás el comercio para comprar y pagar ahí. Las comisiones corresponden a Dopmi.',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                height: 1.45,
                color: DopmiTokens.ink,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 14,
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
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 44),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: species == choice.$1
                                ? DopmiTokens.ink
                                : DopmiTokens.muted,
                            textStyle: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: species == choice.$1 ? 18 : 16,
                              height: 1.1,
                              fontWeight: species == choice.$1
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          onPressed: () => setState(() => species = choice.$1),
                          child: Container(
                            padding: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: species == choice.$1
                                      ? DopmiTokens.orange
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            child: Text(choice.$2),
                          ),
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
                color: DopmiTokens.muted,
                onPressed: () => setState(() => descending = !descending),
                icon: const Icon(Icons.unfold_more, size: 22),
              ),
              IconButton(
                tooltip: activeFilters ? 'Filtros activos' : 'Filtros',
                style: IconButton.styleFrom(
                  backgroundColor: activeFilters
                      ? DopmiTokens.orangeSoft
                      : Colors.transparent,
                  foregroundColor: DopmiTokens.ink,
                ),
                onPressed: showFilters,
                icon: SvgPicture.string(
                  '<svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" fill="none"><path d="M4 7h16" stroke="#15110d" stroke-width="1.8" stroke-linecap="round"/><circle cx="16.5" cy="7" r="2.25" fill="#15110d"/><path d="M4 17h16" stroke="#15110d" stroke-width="1.8" stroke-linecap="round"/><circle cx="7.5" cy="17" r="2.25" fill="#15110d"/></svg>',
                  width: 22,
                  height: 22,
                  colorFilter: ColorFilter.mode(
                    activeFilters ? DopmiTokens.orange : DopmiTokens.muted,
                    BlendMode.srcIn,
                  ),
                  excludeFromSemantics: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (products.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No hay croquetas con estos filtros. Prueba otra combinación o limpia los filtros.',
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
                children: products
                    .map(
                      (product) => SizedBox(
                        width: width,
                        child: _StoreCard(
                          product: product,
                          preview: widget.catalog.preview,
                          externalLinksEnabled:
                              widget.catalog.externalLinksEnabled,
                          busy: opening == product.id,
                          onTap:
                              opening == null &&
                                  widget.catalog.enabled &&
                                  (!widget.catalog.preview ||
                                      widget.catalog.externalLinksEnabled)
                              ? () => openProduct(product)
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

class _StoreFilterChoice extends StatelessWidget {
  const _StoreFilterChoice({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.sizeIcon,
  });
  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final double? sizeIcon;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? DopmiTokens.saffronSoft : Colors.white,
        foregroundColor: DopmiTokens.ink,
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
    required this.product,
    required this.busy,
    required this.onTap,
    required this.preview,
    required this.externalLinksEnabled,
  });
  final StoreProduct product;
  final bool busy;
  final VoidCallback? onTap;
  final bool preview, externalLinksEnabled;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0d15110d),
          blurRadius: 10,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: DopmiTokens.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xfff5f5f5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: preview
                      ? SvgPicture.asset(
                          'assets/profile/croquetas-banner-pet.svg',
                          fit: BoxFit.cover,
                          semanticsLabel: product.name,
                        )
                      : Image.network(
                          product.imageUrl,
                          fit: BoxFit.cover,
                          semanticLabel: product.name,
                          errorBuilder: (_, _, _) => const Center(
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              semanticLabel: 'Imagen no disponible',
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.brand,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            height: 1.25,
                            color: DopmiTokens.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.3,
                            color: DopmiTokens.muted,
                          ),
                        ),
                        Text(
                          storeAgeLabels[product.age] ?? product.age,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.3,
                            color: DopmiTokens.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${product.weightKg.toStringAsFixed(product.weightKg % 1 == 0 ? 0 : 1)} kg',
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      height: 1.2,
                      color: DopmiTokens.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                preview
                    ? (externalLinksEnabled
                          ? (busy
                                ? 'Abriendo destino de prueba…'
                                : 'Abrir destino TEST')
                          : 'Salida de prueba no habilitada')
                    : (busy
                          ? 'Abriendo comercio…'
                          : 'Ver en ${product.merchantName}'),
                style: const TextStyle(color: DopmiTokens.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
