import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/ui.dart';
import '../payments/contribution_amount_dialog.dart';
import 'rescue_repository.dart';
import 'rescue_public_photo.dart';

class PublicExpenseCard extends StatefulWidget {
  const PublicExpenseCard(
    this.record, {
    super.key,
    required this.canContribute,
    this.initiallyOpen = false,
  });
  final RescueRecord record;
  final bool canContribute, initiallyOpen;
  @override
  State<PublicExpenseCard> createState() => _PublicExpenseCardState();
}

class _PublicExpenseCardState extends State<PublicExpenseCard> {
  late bool open = widget.initiallyOpen;
  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final category =
        (record.publicData['category'] ?? record.publicData['type'] ?? '')
            .toString();
    final tone = switch (category) {
      'veterinary' || 'Veterinario' => (
        const Color(0xffe8f1ff),
        const Color(0xff4f7cff),
        'veterinary',
      ),
      'medicine' || 'Medicina' => (
        const Color(0xffe7f8ef),
        const Color(0xff22bd90),
        'medicine',
      ),
      'food' ||
      'Comida' => (const Color(0xfffde8f1), const Color(0xffe85d9a), 'food'),
      _ => (const Color(0xfff3f0ea), yellow, ''),
    };
    final ratio = record.targetCents <= 0
        ? 0.0
        : (record.fundedCents / record.targetCents).clamp(0.0, 1.0);
    final remaining = (record.targetCents - record.fundedCents).clamp(
      0,
      record.targetCents,
    );
    final photos = (record.publicData['photos'] as List? ?? const [])
        .whereType<String>()
        .toList();
    final enabled = widget.canContribute && remaining > 0;
    final large = MediaQuery.textScalerOf(context).scale(12) > 17;
    final amount1 = Text(
      '${_amount(record.fundedCents)} donados',
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: ink,
      ),
    );
    final amount2 = Text(
      '${_amount(remaining)} faltantes',
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        height: 1.2,
        color: muted,
      ),
    );
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xffe6e2dd)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            IntrinsicHeight(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 84),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Semantics(
                        button: true,
                        expanded: open,
                        label:
                            '${open ? 'Ocultar' : 'Ver'} evidencia de ${record.title}',
                        child: InkWell(
                          onTap: () => setState(() => open = !open),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                            child: Row(
                              children: [
                                ExcludeSemantics(
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: tone.$1,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: tone.$3.isEmpty
                                        ? Icon(
                                            Icons.auto_awesome,
                                            size: 22,
                                            color: tone.$2,
                                          )
                                        : SvgPicture.asset(
                                            'assets/profile/need-${tone.$3}.svg',
                                            width: 22,
                                            height: 22,
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              record.title,
                                              style: const TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                height: 1.2,
                                                color: ink,
                                              ),
                                            ),
                                          ),
                                          if (record.data['urgent'] ==
                                              true) ...[
                                            const SizedBox(width: 6),
                                            Semantics(
                                              label: 'Urgente',
                                              child: SvgPicture.asset(
                                                'assets/profile/icon-alert-circle.svg',
                                                width: 14,
                                                height: 14,
                                                colorFilter:
                                                    const ColorFilter.mode(
                                                      Color(0xffc10007),
                                                      BlendMode.srcIn,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      LinearProgressIndicator(
                                        value: ratio,
                                        minHeight: 6,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        color: tone.$2,
                                        backgroundColor: const Color(
                                          0xffefe9df,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      if (large)
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            amount1,
                                            const SizedBox(height: 4),
                                            amount2,
                                          ],
                                        )
                                      else
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(child: amount1),
                                            const SizedBox(width: 8),
                                            Expanded(child: amount2),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ExcludeSemantics(
                                  child: SizedBox(
                                    width: 24,
                                    child: RotatedBox(
                                      quarterTurns: open ? 3 : 1,
                                      child: SvgPicture.asset(
                                        'assets/profile/icon-chevron-right.svg',
                                        width: 20,
                                        height: 20,
                                        colorFilter: const ColorFilter.mode(
                                          muted,
                                          BlendMode.srcIn,
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
                    ),
                    SizedBox(
                      width: 48,
                      child: IconButton(
                        tooltip: !widget.canContribute
                            ? 'Aportación no disponible'
                            : remaining == 0
                            ? 'Gasto cubierto'
                            : 'Aportar a ${record.title}',
                        onPressed: enabled
                            ? () => chooseContribution(
                                context,
                                record.id,
                                remaining,
                                caseId: record.parent,
                              )
                            : null,
                        style: IconButton.styleFrom(
                          backgroundColor: yellow,
                          disabledBackgroundColor: yellow.withValues(
                            alpha: .55,
                          ),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        icon: SvgPicture.asset(
                          'assets/navigation/tab-donate.svg',
                          width: 18,
                          height: 18,
                          colorFilter: const ColorFilter.mode(
                            ink,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (open)
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xffe6e2dd))),
                ),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      photos.isEmpty
                          ? 'No hay evidencia pública disponible.'
                          : 'Evidencias cargadas por rescatista:',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.55,
                        color: ink,
                      ),
                    ),
                    for (final photo in photos) ...[
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (context, box) => RescuePublicPhoto(
                          photo,
                          height: box.maxWidth * 10 / 16,
                          radius: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _amount(int cents) {
  final whole = (cents ~/ 100).toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
  return '\$$whole${cents % 100 == 0 ? '' : '.${(cents % 100).toString().padLeft(2, '0')}'}';
}
