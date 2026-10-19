import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/design_tokens.dart';
import '../../core/donor_notification_button.dart';
import 'store_repository.dart';

/// Gate for every navigation entry/banner. This does not authorize the route:
/// StoreScreen and the link RPC independently enforce current availability.
class StoreEntry extends ConsumerWidget {
  const StoreEntry.visible({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(storeCatalogProvider)
      .when(
        skipLoadingOnRefresh: false,
        skipLoadingOnReload: false,
        data: (catalog) => catalog.enabled ? child : const SizedBox.shrink(),
        error: (_, _) => const SizedBox.shrink(),
        loading: () => const SizedBox.shrink(),
      );
}

class StoreScreen extends ConsumerWidget {
  const StoreScreen({super.key, this.navigation});
  final Widget? navigation;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actor = ref.watch(storeActorProvider).asData?.value;
    final catalog = ref.watch(storeCatalogProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: navigation,
      body: SafeArea(
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
                        'assets/profile/logo-paw.svg',
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
                loading: () => const Center(child: CircularProgressIndicator()),
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
                          onPressed: () => ref.invalidate(storeCatalogProvider),
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (value) => value.enabled
                    ? _StoreContent(
                        key: ValueKey(actor),
                        catalog: value,
                        actor: actor,
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

class _StoreContent extends ConsumerStatefulWidget {
  const _StoreContent({super.key, required this.catalog, required this.actor});
  final StoreCatalog catalog;
  final String? actor;
  @override
  ConsumerState<_StoreContent> createState() => _StoreContentState();
}

class _StoreContentState extends ConsumerState<_StoreContent> {
  final scroll = ScrollController();
  String species = 'dog';
  String? age, size;
  Set<String> brands = {};
  bool descending = false;
  String? opening;
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  Future<void> openProduct(StoreProduct product) async {
    if (opening != null) return;
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
    String? draftAge = age, draftSize = size;
    final draftBrands = {...brands};
    final availableBrands =
        widget.catalog.products
            .where((item) => item.species == species)
            .map((item) => item.brand)
            .toSet()
            .toList()
          ..sort();
    final applied = await showDialog<bool>(
      context: context,
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
          return Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
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
                        backgroundColor: DopmiTokens.yellow,
                        foregroundColor: DopmiTokens.ink,
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
    if (applied == true && mounted) {
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
      key: PageStorageKey('store-scroll-${widget.actor}'),
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Tienda Dopmi',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 28,
              height: 1.1,
              letterSpacing: 0,
              fontWeight: FontWeight.w700,
              color: DopmiTokens.ink,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xffeff6ff),
              border: Border.all(color: const Color(0xffbedbff)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Busca las croquetas de tu preferencia. Al seleccionar un producto, abrirás el comercio para comprar y pagar ahí. Las comisiones corresponden a Dopmi.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                height: 20 / 14,
                color: Color(0xff1c398e),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 18,
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
                                : const Color(0xff777067),
                            textStyle: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: species == choice.$1 ? 28 : 22,
                              height: 1.1,
                              fontWeight: species == choice.$1
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          onPressed: () => setState(() => species = choice.$1),
                          child: Text(choice.$2),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: activeFilters ? 'Filtros activos' : 'Filtros',
                style: IconButton.styleFrom(
                  backgroundColor: activeFilters
                      ? const Color(0xfff3eaff)
                      : Colors.transparent,
                  foregroundColor: DopmiTokens.ink,
                ),
                onPressed: showFilters,
                icon: SvgPicture.string(
                  '<svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" fill="none"><path d="M4 7h16" stroke="#15110d" stroke-width="1.8" stroke-linecap="round"/><circle cx="16.5" cy="7" r="2.25" fill="#15110d"/><path d="M4 17h16" stroke="#15110d" stroke-width="1.8" stroke-linecap="round"/><circle cx="7.5" cy="17" r="2.25" fill="#15110d"/></svg>',
                  width: 22,
                  height: 22,
                  excludeFromSemantics: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => descending = !descending),
              icon: const Icon(Icons.swap_vert),
              label: Text(
                'Ordenar: ${descending ? 'Mayor a menor kg' : 'Menor a mayor kg'}',
              ),
            ),
          ),
          const SizedBox(height: 16),
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
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: products
                    .map(
                      (product) => SizedBox(
                        width: width,
                        child: _StoreCard(
                          product: product,
                          busy: opening == product.id,
                          onTap: opening == null
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
        backgroundColor: selected ? const Color(0xfff4efff) : Colors.white,
        foregroundColor: DopmiTokens.ink,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        side: BorderSide(
          color: selected ? DopmiTokens.purple : DopmiTokens.line,
        ),
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
  });
  final StoreProduct product;
  final bool busy;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: DopmiTokens.line),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 104,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xfff7f4ef),
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.network(
                product.imageUrl,
                fit: BoxFit.contain,
                semanticLabel: product.name,
                errorBuilder: (_, _, _) => const Center(
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    semanticLabel: 'Imagen no disponible',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              product.brand,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(product.name),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Text(
                  '${product.weightKg.toStringAsFixed(product.weightKg % 1 == 0 ? 0 : 1)} kg',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xfffff0ba),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(storeAgeLabels[product.age] ?? product.age),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              busy ? 'Abriendo comercio…' : 'Ver en ${product.merchantName}',
              style: const TextStyle(color: DopmiTokens.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}
