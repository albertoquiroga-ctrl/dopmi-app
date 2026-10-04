import 'package:flutter/material.dart';

import '../../core/ui.dart';
import '../../core/dialog_close.dart';
import '../rescue/rescue_repository.dart';
import 'contribution_layout.dart';

Future<int?> chooseGuardianAmount(
  BuildContext context,
  int currentCents, {
  Listenable? identity,
  bool Function()? canView,
}) => showGeneralDialog<int>(
  context: context,
  barrierDismissible: true,
  barrierLabel: 'Cerrar cambio de cantidad',
  barrierColor: ink.withValues(alpha: .48),
  transitionDuration: Duration.zero,
  pageBuilder: (context, animation, secondaryAnimation) {
    Widget content() => canView?.call() == false
        ? AlertDialog(
            title: const Text('La sesión cambió'),
            content: const Text(
              'Cierra este diálogo para continuar con tu cuenta actual.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          )
        : GuardianAmountDialog(currentCents: currentCents);
    return identity == null
        ? content()
        : ListenableBuilder(
            listenable: identity,
            builder: (context, _) => content(),
          );
  },
);

class GuardianAmountDialog extends StatefulWidget {
  const GuardianAmountDialog({super.key, required this.currentCents});
  final int currentCents;
  @override
  State<GuardianAmountDialog> createState() => _GuardianAmountDialogState();
}

class _GuardianAmountDialogState extends State<GuardianAmountDialog> {
  late final TextEditingController amount = TextEditingController(
    text: (widget.currentCents / 100).toStringAsFixed(2),
  );
  bool consent = false;
  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cents = parsePesos(amount.text);
    final valid =
        cents != null &&
        cents >= 5000 &&
        cents <= 1000000 &&
        cents != widget.currentCents;
    final large = MediaQuery.textScalerOf(context).scale(22) > 33;
    void choose(int value) => setState(() {
      amount.text = (value / 100).toStringAsFixed(2);
      consent = false;
    });
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 400,
                maxHeight: MediaQuery.sizeOf(context).height * .88,
              ),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (large) const SizedBox(height: 24),
                            Text(
                              'Cambiar cantidad',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: large ? 18 : 22,
                                height: 1.3,
                                fontWeight: FontWeight.w700,
                                color: ink,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Tu nueva cantidad se solicitará para el siguiente ciclo. El importe anterior se conserva hasta confirmar la aplicación.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.55,
                                color: muted,
                              ),
                            ),
                            const SizedBox(height: 20),
                            for (final value in [5000, 20000, 50000]) ...[
                              Semantics(
                                button: true,
                                selected: cents == value,
                                child: InkWell(
                                  splashFactory: NoSplash.splashFactory,
                                  overlayColor: const WidgetStatePropertyAll(
                                    Colors.transparent,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () => choose(value),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: cents == value
                                          ? const Color(0xfffffbed)
                                          : Colors.white,
                                      border: Border.all(
                                        color: cents == value
                                            ? yellow
                                            : const Color(0xffe6e2dd),
                                      ),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Aportación mensual',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  height: 1.2,
                                                  fontWeight: FontWeight.w700,
                                                  color: ink,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Wrap(
                                                spacing: 4,
                                                crossAxisAlignment:
                                                    WrapCrossAlignment.center,
                                                children: [
                                                  Text(
                                                    contributionMoney(value)
                                                        .replaceAll(' MXN', ''),
                                                    style: const TextStyle(
                                                      fontSize: 20,
                                                      height: 1.2,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: ink,
                                                    ),
                                                  ),
                                                  const Text(
                                                    'MXN / mes',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      height: 1.2,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: muted,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (widget.currentCents == value)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xffefede8,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          999,
                                                        ),
                                                  ),
                                                  child: const Text(
                                                    'Actual',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      height: 1.2,
                                                      color: muted,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: cents == value
                                                ? yellow
                                                : Colors.white,
                                            border: Border.all(
                                              color: cents == value
                                                  ? const Color(0xfff4c917)
                                                  : const Color(0xffd5cfc6),
                                            ),
                                          ),
                                          child: cents == value
                                              ? Center(
                                                  child: Container(
                                                    width: 8,
                                                    height: 8,
                                                    decoration:
                                                        const BoxDecoration(
                                                          color: ink,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                  ),
                                                )
                                              : null,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            TextField(
                              controller: amount,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              onChanged: (_) => setState(() => consent = false),
                              decoration: const InputDecoration(
                                labelText: 'Importe mensual en MXN',
                                prefixText: '\$ ',
                                helperMaxLines: 3,
                                helperText: 'De \$50 a \$10,000 MXN; hasta dos decimales.',
                              ),
                            ),
                            const SizedBox(height: 12),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: consent,
                              onChanged: (value) =>
                                  setState(() => consent = value ?? false),
                              title: const Text(
                                'Autorizo el nuevo importe mensual desde el siguiente ciclo.',
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.55,
                                  color: ink,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ContributionButton(
                              'Guardar nueva cantidad',
                              onPressed: valid && consent
                                  ? () => Navigator.pop(context, cents)
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            ContributionButton(
                              'Cancelar',
                              secondary: true,
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      DopmiDialogClose(onPressed: () => Navigator.pop(context)),
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
