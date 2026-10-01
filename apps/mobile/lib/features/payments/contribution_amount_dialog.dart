import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
import '../rescue/rescue_repository.dart' show parsePesos;

Future<void> chooseContribution(
  BuildContext context,
  String expense,
  int remainingCents, {
  String? caseId,
}) async {
  final cents = await showGeneralDialog<int>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar selector de monto',
    barrierColor: const Color(0xff15110d).withValues(alpha: .48),
    transitionDuration: Duration.zero,
    pageBuilder: (context, _, _) =>
        ContributionAmountDialog(remainingCents: remainingCents),
  );
  if (cents != null && context.mounted) {
    context.push(
      Uri(
        path: '/contribute/$expense',
        queryParameters: {'amount_cents': '$cents', 'case': ?caseId},
      ).toString(),
    );
  }
}

class ContributionAmountDialog extends StatefulWidget {
  const ContributionAmountDialog({super.key, required this.remainingCents});
  final int remainingCents;
  @override
  State<ContributionAmountDialog> createState() =>
      _ContributionAmountDialogState();
}

class _ContributionAmountDialogState extends State<ContributionAmountDialog> {
  final custom = TextEditingController();
  final focus = FocusNode();
  int? selected = 10000;
  bool selectedRemaining = false;
  @override
  void dispose() {
    custom.dispose();
    focus.dispose();
    super.dispose();
  }

  String money(int cents) =>
      '\$${(cents / 100).toStringAsFixed(cents % 100 == 0 ? 0 : 2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  Widget preset(int cents, {bool remaining = false}) {
    final active =
        selected == cents && selectedRemaining == remaining && !focus.hasFocus;
    return Semantics(
      selected: active,
      child: OutlinedButton(
        onPressed: () => setState(() {
          selected = cents;
          selectedRemaining = remaining;
          custom.clear();
          focus.unfocus();
        }),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          foregroundColor: ink,
          backgroundColor: active ? const Color(0xfffff8d6) : Colors.white,
          side: BorderSide(
            color: active ? yellow : const Color(0xffe6e2dd),
            width: active ? 2.5 : 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              money(cents),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
            if (remaining) ...[
              const SizedBox(height: 2),
              const Text(
                'Total faltante',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: muted,
                  height: 1.1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget close(String label, String asset, double size) => IconButton(
    tooltip: label,
    onPressed: () => Navigator.pop(context),
    constraints: const BoxConstraints.tightFor(width: 36, height: 36),
    padding: EdgeInsets.zero,
    icon: SvgPicture.asset(
      'assets/profile/$asset',
      width: size,
      height: size,
      colorFilter: const ColorFilter.mode(Color(0xff9a928a), BlendMode.srcIn),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final cents = selected ?? parsePesos(custom.text);
    final valid = cents != null && cents >= 1000 && cents <= 1000000;
    final large = MediaQuery.textScalerOf(context).scale(18) > 27;
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => Center(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              12 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 340,
                maxHeight: constraints.maxHeight * .88,
              ),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          close('Regresar', 'back.svg', 20),
                          close('Cerrar', 'icon-x-muted.svg', 18),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Elige un monto a donar:',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (large)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            preset(5000),
                            const SizedBox(height: 10),
                            preset(10000),
                            const SizedBox(height: 10),
                            preset(widget.remainingCents, remaining: true),
                          ],
                        )
                      else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: preset(5000)),
                            const SizedBox(width: 10),
                            Expanded(child: preset(10000)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: preset(
                                widget.remainingCents,
                                remaining: true,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 18),
                      const Text(
                        'Otra cantidad:',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Semantics(
                        label: 'Monto personalizado en pesos mexicanos',
                        child: TextField(
                          controller: custom,
                          focusNode: focus,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onTap: () => setState(() => selected = null),
                          onChanged: (_) => setState(() => selected = null),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: ink,
                          ),
                          decoration: InputDecoration(
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(left: 14, right: 4),
                              child: Text(
                                '\$',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xffb0a89f),
                                ),
                              ),
                            ),
                            prefixIconConstraints: const BoxConstraints(
                              minWidth: 0,
                              minHeight: 0,
                            ),
                            prefixStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xffb0a89f),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xffe6e2dd),
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: yellow,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'De \$10 a \$10,000 MXN, con hasta dos decimales.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: muted,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Los costos de transacción se descuentan del apoyo. Revisarás el importe antes de confirmar en Stripe.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: valid
                            ? () => Navigator.pop(context, cents)
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: yellow,
                          foregroundColor: ink,
                          disabledBackgroundColor: yellow.withValues(alpha: .5),
                          disabledForegroundColor: ink.withValues(alpha: .5),
                          minimumSize: const Size(0, 52),
                          shape: const StadiumBorder(),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                'Dona ahora',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.north_east, size: 18),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Serás redirigido para completar la transacción',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
