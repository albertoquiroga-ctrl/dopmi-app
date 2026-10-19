import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'store_screen.dart';

class StorePromotion extends StatelessWidget {
  const StorePromotion({super.key});
  @override
  Widget build(BuildContext context) => StoreEntry.visible(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Material(
        color: const Color(0xffffefbb),
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
                    const Text(
                      'Tienda Dopmi',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Encuentra alimento y compra en comercios autorizados. Las comisiones ayudan a mantener Dopmi.',
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Text(
                          'Ver más',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Icon(Icons.chevron_right, size: 20),
                      ],
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
