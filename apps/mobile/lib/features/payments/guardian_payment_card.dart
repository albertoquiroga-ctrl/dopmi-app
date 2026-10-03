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
  });
  final String id, brand, last4;
  final bool isDefault;
  final String? wallet;

  factory GuardianPaymentCard.fromJson(Map<String, dynamic> value) {
    if (value['id'] is! String ||
        !RegExp(r'^pm_[A-Za-z0-9]+$').hasMatch(value['id']) ||
        value['brand'] is! String ||
        !RegExp(r'^[a-z_]{2,30}$').hasMatch(value['brand']) ||
        value['last4'] is! String ||
        !RegExp(r'^\d{4}$').hasMatch(value['last4']) ||
        value['default'] is! bool ||
        ![null, 'apple_pay', 'google_pay'].contains(value['wallet'])) {
      throw const FormatException('Tarjeta no confirmada');
    }
    return GuardianPaymentCard(
      id: value['id'],
      brand: value['brand'],
      last4: value['last4'],
      isDefault: value['default'],
      wallet: value['wallet'],
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
              foregroundColor: const Color(0xff554e48),
              padding: EdgeInsets.zero,
              minimumSize: const Size(40, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                height: 1.25,
                letterSpacing: 0,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: onMakeDefault,
            child: const Text(
              'Hacer predeterminada',
              textAlign: TextAlign.right,
            ),
          )
        : null;
    final remove = !card.isDefault && showRemove
        ? IconButton(
            tooltip: 'Eliminar tarjeta',
            onPressed: onRemove,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            style: const ButtonStyle(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            padding: EdgeInsets.zero,
            icon: SvgPicture.asset(
              'assets/profile/icon-trash.svg',
              width: 18,
              height: 18,
              colorFilter: const ColorFilter.mode(
                Color(0xffd92d20),
                BlendMode.srcIn,
              ),
            ),
          )
        : null;
    final large = MediaQuery.textScalerOf(context).scale(12) > 18;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xffe6e2dd)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xffefede8),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: SvgPicture.asset(
                    'assets/profile/icon-card.svg',
                    width: 18,
                    height: 18,
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
                        fontSize: 16,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                    if (card.isDefault) const SizedBox(height: 2),
                    if (card.isDefault)
                      const Text(
                        'Predeterminada',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.25,
                          color: Color(0xff554e48),
                        ),
                      ),
                    if (card.wallet != null) const SizedBox(height: 2),
                    if (card.wallet != null)
                      Text(
                        card.wallet == 'apple_pay' ? 'Apple Pay' : 'Google Pay',
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.25,
                          color: Color(0xff554e48),
                        ),
                      ),
                  ],
                ),
              ),
              if (action != null && !large) ...[
                const SizedBox(width: 8),
                SizedBox(width: 92.328125, child: action),
              ],
              if (remove != null && !large) ...[
                const SizedBox(width: 12),
                remove,
              ],
            ],
          ),
          if ((action != null || remove != null) && large)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (action != null) Flexible(child: action),
                if (remove != null) ...[const SizedBox(width: 12), remove],
              ],
            ),
        ],
      ),
    );
  }
}
