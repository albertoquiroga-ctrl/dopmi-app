import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'store_screen.dart';
import 'store_repository.dart';
import '../../core/design_tokens.dart';

class StorePromotion extends ConsumerWidget {
  const StorePromotion({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview =
        ref.watch(storeCatalogProvider).asData?.value.preview == true;
    return StoreEntry.visible(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Material(
          color: DopmiTokens.saffronSoft,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push('/store'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 8, 18),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final copy = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preview ? 'Vista previa de Tienda' : 'Tienda Dopmi',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        preview
                            ? 'Catálogo TEST privado. No permite compras reales.'
                            : 'Encuentra alimento y compra en comercios autorizados. Las comisiones ayudan a mantener Dopmi.',
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: DopmiTokens.orangeButton,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Ver más',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                  final image = SvgPicture.asset(
                    'assets/profile/croquetas-banner-pet.svg',
                    width: 110,
                    height: 138,
                    excludeFromSemantics: true,
                  );
                  if (constraints.maxWidth < 300 ||
                      MediaQuery.textScalerOf(context).scale(16) > 24) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        copy,
                        Align(alignment: Alignment.centerRight, child: image),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: copy),
                      image,
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
