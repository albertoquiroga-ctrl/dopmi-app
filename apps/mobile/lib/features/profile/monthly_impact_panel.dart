import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui.dart';
import '../adoption/community_ui.dart';
import '../adoption/community_repository.dart';
import '../rescue/rescue_repository.dart' show pesos;
import 'impact_photo_journey.dart';
import 'monthly_impact_repository.dart';

class MonthlyImpactPanel extends ConsumerStatefulWidget {
  const MonthlyImpactPanel({super.key});
  @override
  ConsumerState<MonthlyImpactPanel> createState() => _MonthlyImpactPanelState();
}

class _MonthlyImpactPanelState extends ConsumerState<MonthlyImpactPanel> {
  String? selectedMonth;
  Future<(MonthlyPersonalImpact, MonthlyCommunityImpact)> load() async {
    final repo = ref.read(monthlyImpactRepositoryProvider);
    final personal = await repo.personal(month: selectedMonth);
    // The server chooses the current CDMX month; both reads use that exact month.
    final community = await repo.community(month: personal.month);
    if (personal.month != community.month) {
      throw const FormatException('Los períodos no coinciden');
    }
    return (personal, community);
  }

  void changeMonth(String from, int offset, String currentMonth) {
    final date = DateTime.parse(from);
    final next = DateTime(date.year, date.month + offset);
    if (next.isAfter(DateTime.parse(currentMonth))) return;
    setState(
      () => selectedMonth =
          '${next.year.toString().padLeft(4, '0')}-${next.month.toString().padLeft(2, '0')}-01',
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => LiveSection<(MonthlyPersonalImpact, MonthlyCommunityImpact)>(
    key: ValueKey(selectedMonth),
    load: load,
    errorMessage: (_) =>
        'No pudimos consultar el impacto del mes. Vuelve a intentarlo.',
    builder: (result, _) {
      final personal = result.$1, community = result.$2;
      final date = DateTime.parse(personal.month);
      const months = [
        'Enero',
        'Febrero',
        'Marzo',
        'Abril',
        'Mayo',
        'Junio',
        'Julio',
        'Agosto',
        'Septiembre',
        'Octubre',
        'Noviembre',
        'Diciembre',
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Mes anterior',
                onPressed: () =>
                    changeMonth(personal.month, -1, personal.currentMonth),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  '${months[date.month - 1]} ${date.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Mes siguiente',
                onPressed: personal.month.compareTo(personal.currentMonth) >= 0
                    ? null
                    : () =>
                          changeMonth(personal.month, 1, personal.currentMonth),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const Text(
            'Mes calendario de Ciudad de México',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 24),
          const Text(
            'Tu impacto',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (personal.caseIds.isNotEmpty) ...[
            _MonthlyPhotoCollage(
              key: ValueKey(personal.month),
              caseIds: personal.caseIds,
            ),
            const SizedBox(height: 16),
          ],
          _ImpactStat(
            value: pesos(personal.allocatedCents),
            label: 'Asignados de tus aportaciones',
            color: const Color(0xfffef5d0),
          ),
          const SizedBox(height: 12),
          _ImpactStat(
            value: '${personal.casesSupported}',
            label: 'Casos que apoyaste este mes',
            color: const Color(0xfff6f3ef),
          ),
          if (personal.casesSupported == 0) ...[
            const SizedBox(height: 12),
            const Text(
              'Este mes aún no hay aportaciones tuyas asignadas. Un registro o pago pendiente no cuenta como impacto.',
              style: TextStyle(color: muted, height: 1.45),
            ),
          ],
          const SizedBox(height: 28),
          const Text(
            'Este mes logramos',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Entre toda la comunidad',
            style: TextStyle(color: muted, fontSize: 14),
          ),
          const SizedBox(height: 12),
          _ImpactStat(
            value: '${community.casesSupported}',
            label: 'Casos apoyados por la comunidad',
            color: yellow,
          ),
          const SizedBox(height: 12),
          _ImpactStat(
            value:
                community.urgentCasesCovered?.toString() ??
                'Sin medición histórica',
            label: 'Casos con gastos urgentes totalmente cubiertos',
            color: const Color(0xffefe8fb),
          ),
          if (community.measurementStatus == 'partial') ...[
            const SizedBox(height: 10),
            Text(
              'Medición parcial. Desde ${community.measurementStartedOn!.split('-').reversed.join('/')} (Ciudad de México).',
              style: const TextStyle(color: muted, height: 1.45),
            ),
          ],
          if (community.measurementStatus == 'not_measured') ...[
            const SizedBox(height: 10),
            const Text(
              'Las urgencias de este período no tenían seguimiento. No se presentan como cero.',
              style: TextStyle(color: muted, height: 1.45),
            ),
          ],
        ],
      );
    },
  );
}

class _MonthlyPhotoCollage extends ConsumerWidget {
  const _MonthlyPhotoCollage({super.key, required this.caseIds});
  final List<String> caseIds;
  @override
  Widget build(BuildContext context, WidgetRef ref) => LiveSection<List<Json>>(
    load: () async =>
        (await ref.read(communityRepositoryProvider).personalImpact())
            .where(
              (item) =>
                  caseIds.contains(item['case_id']) &&
                  ((item['public_data'] as Map?)?['photos'] as List? ?? [])
                      .isNotEmpty,
            )
            .toList(),
    errorMessage: (_) => 'Las fotos públicas no están disponibles. Tus cifras de impacto se conservan.',
    builder: (items, _) {
      if (items.isEmpty) return const SizedBox.shrink();
      final photos = <ImpactPhoto>[];
      for (final item in items) {
        final data = item['public_data'] as Map;
        for (final path in (data['photos'] as List).whereType<String>()) {
          if (path.isNotEmpty) {
            photos.add(
              ImpactPhoto(
                item['case_id'] as String,
                data['pet_name'] as String? ?? 'Caso apoyado',
                path,
              ),
            );
          }
        }
      }
      if (photos.isEmpty) return const SizedBox.shrink();
      return ImpactPhotoJourney(photos: photos, hero: photos.first);
    },
  );
}

class _ImpactStat extends StatelessWidget {
  const _ImpactStat({
    required this.value,
    required this.label,
    required this.color,
  });
  final String value, label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Fraunces',
            fontSize: 32,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
