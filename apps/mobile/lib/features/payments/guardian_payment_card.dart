import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/ui.dart';

class GuardianPaymentCard {
  const GuardianPaymentCard({
    required this.id,
    required this.brand,
    required this.last4,
    required this.isDefault,
    this.wallet,
    this.guardianCurrent = false,
    this.expMonth,
    this.expYear,
  });
  final String id, brand, last4;
  final bool isDefault, guardianCurrent;
  final int? expMonth, expYear;
  String? get expiryLabel => expMonth != null && expYear != null
      ? "${expMonth.toString().padLeft(2, '0')}/$expYear"
      : null;
  final String? wallet;

  factory GuardianPaymentCard.fromJson(Map<String, dynamic> value) {
    if (value['id'] is! String ||
        !RegExp(r'^pm_[A-Za-z0-9]+$').hasMatch(value['id']) ||
        value['brand'] is! String ||
        !RegExp(r'^[a-z_]{2,30}$').hasMatch(value['brand']) ||
        value['last4'] is! String ||
        !RegExp(r'^\d{4}$').hasMatch(value['last4']) ||
        value['default'] is! bool ||
        (value['guardian_current'] != null &&
            value['guardian_current'] is! bool) ||
        (value['exp_month'] != null &&
            (value['exp_month'] is! int ||
                value['exp_month'] < 1 ||
                value['exp_month'] > 12)) ||
        (value['exp_year'] != null &&
            (value['exp_year'] is! int ||
                value['exp_year'] < 2000 ||
                value['exp_year'] > 2200)) ||
        ![null, 'apple_pay', 'google_pay'].contains(value['wallet'])) {
      throw const FormatException('Tarjeta no confirmada');
    }
    return GuardianPaymentCard(
      id: value['id'],
      brand: value['brand'],
      last4: value['last4'],
      isDefault: value['default'],
      wallet: value['wallet'],
      guardianCurrent: value['guardian_current'] == true,
      expMonth: value['exp_month'],
      expYear: value['exp_year'],
    );
  }
  String get brandLabel => switch (brand) {
    'visa' => 'Visa',
    'mastercard' => 'Mastercard',
    'amex' => 'American Express',
    'diners' => 'Diners Club',
    'discover' => 'Discover',
    'jcb' => 'JCB',
    'unionpay' => 'UnionPay',
    _ => 'Tarjeta',
  };
}

class GuardianPaymentCardRow extends StatelessWidget {
  const GuardianPaymentCardRow({
    super.key,
    required this.card,
    this.showMakeDefault = false,
    this.onMakeDefault,
    this.showRemove = false,
    this.onRemove,
  });
  final bool showMakeDefault, showRemove;
  final VoidCallback? onMakeDefault, onRemove;
  final GuardianPaymentCard card;
  @override
  Widget build(BuildContext context) {
    final action = !card.isDefault && showMakeDefault
        ? TextButton(
            style: TextButton.styleFrom(
              foregroundColor: muted,
              padding: EdgeInsets.zero,
              minimumSize: const Size(40, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                height: 1.25,
                letterSpacing: 0,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
            onPressed: onMakeDefault,
            child: const Text(
              'Hacer predeterminada',
              textAlign: TextAlign.right,
              softWrap: false,
            ),
          )
        : null;
    final remove = !card.isDefault && showRemove
        ? IconButton(
            tooltip: card.guardianCurrent
                ? 'Tarjeta en uso por Guardián; cambia su tarjeta antes de eliminarla'
                : 'Eliminar tarjeta',
            onPressed: card.guardianCurrent ? null : onRemove,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            style: const ButtonStyle(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            padding: EdgeInsets.zero,
            icon: SvgPicture.asset(
              'assets/profile/icon-trash.svg',
              width: 18,
              height: 18,
              colorFilter: ColorFilter.mode(
                card.guardianCurrent || onRemove == null
                    ? const Color(0xffa8a29b)
                    : const Color(0xff9a9289),
                BlendMode.srcIn,
              ),
            ),
          )
        : null;
    final scaler = MediaQuery.textScalerOf(context);
    double textWidth(String value, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: value, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final actionWidth = action == null
            ? 0.0
            : textWidth(
                'Hacer predeterminada',
                const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              );
        final titleWidth = textWidth(
          '${card.brandLabel} •••• ${card.last4}',
          const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        );
        final inlineWidth =
            32 +
            52 +
            (titleWidth < 80 ? titleWidth : 80) +
            (action == null && remove == null
                ? 0
                : 12 + (actionWidth > 40 ? actionWidth : 40));
        final large =
            constraints.maxWidth < inlineWidth || scaler.scale(12) > 18;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xffe8e8e8)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: card.isDefault
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color(0xfff3f4f6),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/profile/icon-card.svg',
                        width: 18,
                        height: 18,
                        colorFilter: const ColorFilter.mode(
                          Color(0xff6b7280),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${card.brandLabel} •••• ${card.last4}',
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                            color: ink,
                          ),
                        ),
                        if (card.guardianCurrent) ...[
                          const SizedBox(height: 2),
                          const Text(
                            'En uso por Guardián',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.25,
                              color: muted,
                            ),
                          ),
                        ],
                        if (card.expiryLabel != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Vence ${card.expiryLabel}',
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.25,
                              color: muted,
                            ),
                          ),
                        ],
                        if (card.isDefault) const SizedBox(height: 4),
                        if (card.isDefault)
                          const Text(
                            'Predeterminada',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.25,
                              color: muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        if (card.wallet != null) const SizedBox(height: 2),
                        if (card.wallet != null)
                          Text(
                            card.wallet == 'apple_pay'
                                ? 'Apple Pay'
                                : 'Google Pay',
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.25,
                              color: Color(0xff554e48),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if ((action != null || remove != null) && !large) ...[
                    const SizedBox(width: 12),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ?action,
                        if (action != null && remove != null)
                          const SizedBox(height: 8),
                        ?remove,
                      ],
                    ),
                  ],
                ],
              ),
              if ((action != null || remove != null) && large)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 12,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [?action, ?remove],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class GuardianPaymentCardEmpty extends StatelessWidget {
  const GuardianPaymentCardEmpty({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
    decoration: BoxDecoration(
      color: const Color(0xfffafafa),
      border: Border.all(color: const Color(0xffe8e8e8)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: Color(0xfff3f4f6),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: SvgPicture.asset(
              'assets/profile/icon-card.svg',
              width: 22,
              height: 22,
              colorFilter: const ColorFilter.mode(
                Color(0xff9a9289),
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Agrega una tarjeta para guardarla de forma segura con Stripe.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.45, color: muted),
        ),
      ],
    ),
  );
}
