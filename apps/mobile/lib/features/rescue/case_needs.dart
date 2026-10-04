import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../adoption/community_repository.dart';
import 'case_need_dialog.dart';
import 'case_need_row.dart';
import 'case_information.dart';
import 'rescue_fields.dart';

class CaseNeeds extends StatelessWidget {
  const CaseNeeds({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onChanged,
    required this.items,
    required this.onItemsChanged,
  });
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onChanged;
  final List<Json> items;
  final ValueChanged<List<Json>> onItemsChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        '¿Qué necesita la mascota?',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          height: 28 / 18,
          fontWeight: FontWeight.w600,
          color: Color(0xff151423),
        ),
      ),
      const SizedBox(height: 16),
      DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xffeff6ff),
          border: Border.all(color: const Color(0xffbedbff)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Nota:',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text: ' Las necesidades son opcionales. Puedes publicar el caso aunque aún no agregues apoyo económico.',
                ),
              ],
            ),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              height: 20 / 14,
              color: Color(0xff1c398e),
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),
      for (final type in ['food', 'medicine', 'veterinary']) ...[
        OutlinedButton(
          onPressed: !enabled || items.length >= 20
              ? null
              : () async {
                  final item = await addCaseNeed(context, type);
                  if (item != null && context.mounted) {
                    onItemsChanged([...items, item]);
                  }
                },
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            side: const BorderSide(color: Color(0xffe3e4ed)),
            foregroundColor: const Color(0xff151423),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: SvgPicture.asset(
                    'assets/profile/need-$type.svg',
                    width: 36,
                    height: 36,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      const {
                        'food': 'Comida',
                        'medicine': 'Medicina',
                        'veterinary': 'Veterinario',
                      }[type]!,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      type == 'food'
                          ? 'Agrega el alimento, costo y frecuencia que necesita.'
                          : type == 'medicine'
                          ? 'Agrega una medicina, costo y tratamiento relacionado.'
                          : 'Agrega consulta o tratamiento veterinario.',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        height: 20 / 14,
                        fontWeight: FontWeight.w400,
                        color: Color(0xff616174),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
      if (items.isNotEmpty) ...[
        const Text(
          'Necesidades agregadas',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: CaseNeedRow(
              item: item,
              showRemove: true,
              showUrgency: true,
              onRemove: enabled
                  ? () => onItemsChanged(
                      items.where((i) => i['id'] != item['id']).toList(),
                    )
                  : null,
            ),
          ),
      ],

      CaseInformation(
        controllers: {'need': controller},
        enabled: enabled,
        onChanged: onChanged,
      ).field(rescueFields['case']!.firstWhere((f) => f.key == 'need')),
    ],
  );
}
