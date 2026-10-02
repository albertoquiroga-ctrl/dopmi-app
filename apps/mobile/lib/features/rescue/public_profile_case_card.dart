import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
import '../adoption/community_repository.dart';
import '../adoption/community_ui.dart';
import '../payments/contribution_amount_dialog.dart';
import 'rescue_public_photo.dart';
import 'rescue_repository.dart';

class PublicProfileCaseCard extends ConsumerWidget {
  const PublicProfileCaseCard(this.id, {super.key});
  final String id;
  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) => LiveSection<DataPage<RescueRecord>>(
    load: () => ref.read(rescueRepositoryProvider).completeCaseCatalog(id),
    tables: const ['dopmi_rescue_records', 'dopmi_donations'],
    builder: (data, refresh) {
      final cases = data.items
          .where((item) => item.id == id && item.kind == 'case')
          .toList();
      if (cases.isEmpty) {
        return const Notice('Este caso ya no está disponible.');
      }
      final record = cases.single;
      final expenses = data.items
          .where((item) => item.kind == 'expense' && item.parent == id)
          .toList();
      final expense = expenses.isEmpty ? null : expenses.first;
      final remaining = expense == null
          ? 0
          : (expense.targetCents - expense.fundedCents).clamp(
              0,
              expense.targetCents,
            );
      final photos = (record.publicData['photos'] as List? ?? [])
          .whereType<String>()
          .toList();
      final ratio = expense == null || expense.targetCents <= 0
          ? 0.0
          : (expense.fundedCents / expense.targetCents).clamp(0.0, 1.0);
      final enabled =
          remaining > 0 &&
          record.status != 'closed' &&
          ref.read(communityRepositoryProvider).userId !=
              record.data['owner_id'];
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xffe6e2dd)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x141d140d),
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 258,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (photos.isNotEmpty)
                    RescuePublicPhoto(photos.first, height: 258, radius: 0)
                  else
                    const ColoredBox(color: Color(0xffeeeeee)),
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 142,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0x99000000)],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 14,
                    child: Text(
                      record.title,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        height: 1.2,
                        letterSpacing: 0,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (expense != null) ...[
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        Text(
                          expense.title,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.2,
                            letterSpacing: 0,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${pesos(expense.fundedCents).replaceAll(' MXN', '').replaceFirst(RegExp(r'\.00$'), '')} / ${pesos(expense.targetCents).replaceAll(' MXN', '').replaceFirst(RegExp(r'\.00$'), '')}',
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.2,
                            letterSpacing: 0,
                            fontWeight: FontWeight.w700,
                            color: Color(0xff6b5000),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 8,
                        color: yellow,
                        backgroundColor: const Color(0xfffff2b5),
                        semanticsLabel: 'Avance de ${expense.title}',
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () => context.push('/rescue-cases/$id'),
                          style: FilledButton.styleFrom(
                            backgroundColor: yellow,
                            foregroundColor: ink,
                            minimumSize: const Size(0, 38),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            textStyle: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              height: 1.2,
                              letterSpacing: 0,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: const Text('Ver caso'),
                        ),
                      ),
                      if (expense != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: enabled
                                ? () => chooseContribution(
                                    context,
                                    expense.id,
                                    remaining,
                                    caseId: id,
                                  )
                                : null,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xffe6e2dd)),
                              minimumSize: const Size(0, 38),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              foregroundColor: ink,
                              textStyle: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                height: 1.2,
                                letterSpacing: 0,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: const Text('Donar'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
