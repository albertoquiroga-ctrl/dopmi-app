import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
import '../adoption/community_ui.dart';
import '../adoption/community_repository.dart';
import '../rescue/rescue_repository.dart';
import '../rescue/support_stories.dart';
import '../rescue/rescue_public_photo.dart';
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
          if (personal.caseIds.isNotEmpty) ...[
            _MonthlyPhotoCollage(
              key: ValueKey(personal.month),
              caseIds: personal.caseIds,
              month: personal.month,
            ),
            const SizedBox(height: 16),
          ],

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
          _ImpactMosaic(
            children: [
              _ImpactStat(
                value: pesos(personal.allocatedCents),
                label: 'Asignados de tus aportaciones',
                color: const Color(0xfffef5d0),
              ),
              _ImpactStat(
                value: '${personal.casesSupported}',
                label: 'Casos que apoyaste este mes',
                color: const Color(0xfff6f3ef),
              ),
            ],
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
          _MonthlyCommunityMosaic(
            key: ValueKey('mosaic-${personal.month}'),
            caseIds: personal.caseIds,
            community: community,
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
  const _MonthlyPhotoCollage({
    super.key,
    required this.caseIds,
    required this.month,
  });
  final String month;
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
      var openingStory = false;
      return ImpactPhotoJourney(
        photos: photos,
        hero: photos.first,
        periodLabel:
            '${const ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'][DateTime.parse(month).month - 1]} ${month.substring(2, 4)}',
        onOpenStory: (photo) async {
          if (openingStory) return;
          openingStory = true;
          try {
            // Match the rail's first occurrence of each case, starting at the
            // selected ring. Revalidate every snapshot instead of reusing the
            // historical impact projection or loading a global catalog.
            final orderedCaseIds = <String>{
              for (final entry in photos) entry.caseId,
            }.toList();
            final selectedIndex = orderedCaseIds.indexOf(photo.caseId);
            if (selectedIndex < 0) return;
            final repository = ref.read(rescueRepositoryProvider);
            final records = <RescueRecord>[];
            for (final caseId in orderedCaseIds.skip(selectedIndex)) {
              DataPage<RescueRecord> catalog;
              try {
                catalog = await repository.completeCaseCatalog(caseId);
              } catch (_) {
                if (!context.mounted) return;
                if (caseId == photo.caseId) rethrow;
                // A later unavailable case cannot hide the verified selection.
                // Omit it instead of falling back to the stale impact snapshot.
                continue;
              }
              if (!context.mounted) return;
              records.addAll(
                catalog.items
                    .where(
                      (record) =>
                          record.id == caseId &&
                          record.kind == 'case' &&
                          (record.status == 'approved' ||
                              record.status == 'closed') &&
                          supportStoryPhotos(record).isNotEmpty,
                    )
                    .take(1),
              );
              // Never substitute another case for the ring the person opened.
              if (caseId == photo.caseId && records.isEmpty) break;
            }
            if (!context.mounted) return;
            if (records.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Las historias públicas de este caso ya no están disponibles.',
                  ),
                ),
              );
              return;
            }
            final detail = await Navigator.of(context, rootNavigator: true)
                .push<String>(
                  MaterialPageRoute(
                    builder: (_) => SupportStories(records: records),
                    fullscreenDialog: true,
                  ),
                );
            if (context.mounted && detail != null) {
              context.push('/rescue-cases/$detail');
            }
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'No pudimos abrir las historias. Vuelve a intentarlo.',
                  ),
                ),
              );
            }
          } finally {
            openingStory = false;
          }
        },
      );
    },
  );
}

class _MonthlyCommunityMosaic extends ConsumerStatefulWidget {
  const _MonthlyCommunityMosaic({
    super.key,
    required this.caseIds,
    required this.community,
  });
  final List<String> caseIds;
  final MonthlyCommunityImpact community;
  @override
  ConsumerState<_MonthlyCommunityMosaic> createState() =>
      _MonthlyCommunityMosaicState();
}

class _MonthlyCommunityMosaicState
    extends ConsumerState<_MonthlyCommunityMosaic> {
  Future<List<Json>>? request;
  String? scope;
  @override
  Widget build(BuildContext context) {
    final current = widget.caseIds.join(':');
    if (scope != current || request == null) {
      scope = current;
      request = ref.read(communityRepositoryProvider).personalImpact();
    }
    return FutureBuilder<List<Json>>(
      future: request,
      builder: (context, snapshot) {
        final photos = <(String, String)>[];
        for (final item in snapshot.data ?? <Json>[]) {
          if (!widget.caseIds.contains(item['case_id'])) continue;
          final data = item['public_data'] as Map? ?? {};
          for (final path
              in (data['photos'] as List? ?? []).whereType<String>().where(
                (path) => path.isNotEmpty,
              )) {
            photos.add((path, data['pet_name'] as String? ?? 'Caso apoyado'));
          }
        }
        Widget photoTile(int index) => Semantics(
          label:
              'Foto pública de ${photos[index].$2}, caso que apoyaste este mes',
          child: RescuePublicPhoto(
            photos[index].$1,
            height: index.isEven ? 188 : 220,
            radius: 24,
            compact: true,
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ImpactMosaic(
              children: [
                _ImpactStat(
                  value: '${widget.community.casesSupported}',
                  label: 'Casos apoyados por la comunidad',
                  color: yellow,
                ),
                if (photos.isNotEmpty) photoTile(0),
                if (photos.length > 1) photoTile(1),
                _ImpactStat(
                  value:
                      widget.community.urgentCasesCovered?.toString() ??
                      'Sin medición histórica',
                  isTextualStatus: widget.community.urgentCasesCovered == null,
                  label: 'Casos con gastos urgentes totalmente cubiertos',
                  color: const Color(0xffefe8fb),
                ),
                if (photos.length > 2) photoTile(2),
                if (photos.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xfff6f3ef),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Text(
                      'Un pequeño gesto. Una gran diferencia.',
                      style: TextStyle(
                        fontSize: 20,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (photos.length > 3) photoTile(3),
              ],
            ),
            if (snapshot.hasError)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'No pudimos cargar las fotos públicas. Las cifras de impacto se conservan.',
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ImpactMosaic extends StatelessWidget {
  const _ImpactMosaic({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final halfContent = (constraints.maxWidth - 12) / 2 - 48;
      final valueNeedsRow = children.whereType<_ImpactStat>().any((stat) {
        if (!stat.value.startsWith(r'$') && !stat.isTextualStatus) {
          return false;
        }
        final words = stat.isTextualStatus
            ? stat.value.split(' ')
            : [stat.value.split(' ').first];
        return words.any((word) {
          final painter = TextPainter(
            text: TextSpan(
              text: word,
              style: stat.isTextualStatus
                  ? _ImpactStat.textualStatusStyle
                  : _ImpactStat.valueStyle,
            ),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          final needsRow = painter.width > halfContent;
          painter.dispose();
          return needsRow;
        });
      });
      final columns =
          MediaQuery.textScalerOf(context).scale(14) > 21 ||
              constraints.maxWidth < 280 ||
              valueNeedsRow
          ? 1
          : 2;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

class _ImpactStat extends StatelessWidget {
  const _ImpactStat({
    required this.value,
    required this.label,
    required this.color,
    this.isTextualStatus = false,
  });
  final String value, label;
  final Color color;
  final bool isTextualStatus;
  static const valueStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 42,
    height: 1.2,
    fontWeight: FontWeight.w800,
  );
  static const textualStatusStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 20,
    height: 1.4,
    fontWeight: FontWeight.w700,
  );
  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('impact-stat-$label'),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (value.startsWith(r'$'))
          LayoutBuilder(
            builder: (context, constraints) {
              final painter = TextPainter(
                text: TextSpan(text: value, style: valueStyle),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
              )..layout();
              final overflow = painter.width > constraints.maxWidth;
              painter.dispose();
              if (!overflow) return Text(value, style: valueStyle);
              final parts = value.split(' ');
              final number = parts.first;
              final unit = parts.skip(1).join(' ');
              final numberPainter = TextPainter(
                text: TextSpan(text: number, style: valueStyle),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
              )..layout();
              final numberOverflows =
                  numberPainter.width > constraints.maxWidth;
              numberPainter.dispose();
              return Semantics(
                label: value,
                explicitChildNodes: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SingleChildScrollView(
                      key: ValueKey('impact-amount-scroll-$label'),
                      scrollDirection: Axis.horizontal,
                      child: ExcludeSemantics(
                        child: Text(number, style: valueStyle, softWrap: false),
                      ),
                    ),
                    if (unit.isNotEmpty)
                      ExcludeSemantics(
                        child: Text(
                          unit,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (numberOverflows)
                      const Text(
                        'Desliza para ver el importe completo',
                        style: TextStyle(fontSize: 12),
                      ),
                  ],
                ),
              );
            },
          )
        else
          Text(value, style: isTextualStatus ? textualStatusStyle : valueStyle),
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
