import '../../core/reference_focus_outline.dart';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../adoption/community_repository.dart';
import '../payments/payment_repository.dart';
import '../rescue/rescue_repository.dart';

class RescuerProfileActivity extends StatelessWidget {
  const RescuerProfileActivity({
    super.key,
    required this.data,
    required this.onHome,
    required this.onExpense,
    required this.onStart,
  });
  final Json data;
  final VoidCallback onHome, onStart;
  final ValueChanged<String> onExpense;
  @override
  Widget build(BuildContext context) {
    final approved = data['verification_status'] == 'approved';
    final items = approved
        ? (data['recent_activity'] as List? ?? [])
              .map((item) => Json.from(item as Map))
              .take(3)
              .toList()
        : <Json>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: const Text(
                  'Actividad reciente',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff151423),
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
            if (items.isNotEmpty) RescuerActivityHomeLink(onPressed: onHome),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
            decoration: BoxDecoration(
              color: const Color(0xfff7f5f1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Text(
                  approved
                      ? 'Aún no hay movimiento. Publica un caso para empezar a recibir apoyo.'
                      : 'Verifica tu cuenta para publicar casos y ver donaciones aquí.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    height: 1.55,
                    color: Color(0xff4f4e5c),
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 12),
                ReferenceFocusOutline(
                  radius: 14,
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onStart,
                      style:
                          FilledButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            backgroundColor: const Color(0xff7841f2),
                            overlayColor: Colors.transparent,
                            foregroundColor: const Color(0xfffbfbff),
                            textStyle: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0,
                            ),
                          ).copyWith(
                            animationDuration: Duration.zero,
                            backgroundColor: WidgetStateProperty.resolveWith(
                              (states) => states.contains(WidgetState.hovered)
                                  ? const Color(0xff6d28d9)
                                  : const Color(0xff7841f2),
                            ),
                          ),
                      child: Text(
                        approved ? 'Publicar caso' : 'Ir a verificación',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xffe3e4ed)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                for (var n = 0; n < items.length; n++) ...[
                  if (n > 0)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xffe3e4ed),
                    ),
                  RescuerProfileActivityRow(
                    item: items[n],
                    onPressed: items[n]['expense_id'] is String
                        ? () => onExpense(items[n]['expense_id'] as String)
                        : null,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class RescuerActivityHomeLink extends StatefulWidget {
  const RescuerActivityHomeLink({super.key, required this.onPressed});
  final VoidCallback onPressed;
  @override
  State<RescuerActivityHomeLink> createState() =>
      _RescuerActivityHomeLinkState();
}

class _RescuerActivityHomeLinkState extends State<RescuerActivityHomeLink> {
  bool hovered = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => hovered = true),
    onExit: (_) => setState(() => hovered = false),
    child: ReferenceFocusOutline(
      radius: 0,
      outlineInset: const EdgeInsets.symmetric(vertical: 2),
      child: TextButton(
        onPressed: widget.onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          tapTargetSize: MaterialTapTargetSize.padded,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          foregroundColor: const Color(0xff7841f2),
          backgroundColor: Colors.transparent,
          overlayColor: Colors.transparent,
          shape: const RoundedRectangleBorder(),
          animationDuration: Duration.zero,
          splashFactory: NoSplash.splashFactory,
        ),
        child: Text(
          'Ver inicio',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            height: 16 / 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
            decoration: hovered
                ? TextDecoration.underline
                : TextDecoration.none,
            decorationColor: const Color(0xff7841f2),
          ),
        ),
      ),
    ),
  );
}

class RescuerProfileActivityRow extends StatefulWidget {
  const RescuerProfileActivityRow({
    super.key,
    required this.item,
    required this.onPressed,
  });
  final Json item;
  final VoidCallback? onPressed;
  @override
  State<RescuerProfileActivityRow> createState() =>
      _RescuerProfileActivityRowState();
}

class _RescuerProfileActivityRowState extends State<RescuerProfileActivityRow> {
  bool hovered = false;
  @override
  Widget build(BuildContext context) {
    final cents = widget.item['allocated_cents'] as int?;
    final title =
        '${cents == null ? '—' : pesos(cents)} asignados · ${widget.item['expense_title'] as String? ?? 'Gasto'}';
    return Semantics(
      button: widget.onPressed != null,
      child: ReferenceFocusOutline(
        radius: 0,
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 120),
          curve: Curves.ease,
          width: double.infinity,
          color: hovered ? const Color(0xfffffdf5) : Colors.transparent,
          constraints: const BoxConstraints(minHeight: 64),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onPressed,
              onHover: (value) => setState(() => hovered = value),
              splashFactory: NoSplash.splashFactory,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
              focusColor: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xfff3eefc),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SvgPicture.asset(
                          'assets/profile/icon-donation-in.svg',
                          width: 18,
                          height: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines:
                                MediaQuery.textScalerOf(context).scale(14) > 20
                                ? null
                                : 1,
                            overflow:
                                MediaQuery.textScalerOf(context).scale(14) > 20
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                              letterSpacing: 0,
                              color: Color(0xff151423),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            transferLabels[widget.item['transfer_status']] ??
                                'Estado de transferencia no disponible',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              height: 15.2 / 12,
                              letterSpacing: 0,
                              color: Color(0xff4f4e5c),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    ExcludeSemantics(
                      child: SvgPicture.asset(
                        'assets/profile/icon-chevron-right.svg',
                        width: 20,
                        height: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
