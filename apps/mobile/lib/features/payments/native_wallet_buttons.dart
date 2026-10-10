import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class NativeWalletButtons extends StatelessWidget {
  const NativeWalletButtons({
    super.key,
    required this.availableProvider,
    required this.onPressed,
  });
  final String? availableProvider;
  final ValueChanged<String>? onPressed;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: _button('apple_pay', 'Apple Pay', 'apple')),
      const SizedBox(width: 12),
      Expanded(child: _button('google_pay', 'Google Pay', 'google')),
    ],
  );

  Widget _button(String provider, String label, String asset) => OutlinedButton(
    onPressed: availableProvider == provider && onPressed != null
        ? () => onPressed!(provider)
        : null,
    style:
        OutlinedButton.styleFrom(
          splashFactory: NoSplash.splashFactory,
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xff15110d),
          disabledBackgroundColor: Colors.white,
          disabledForegroundColor: const Color(0xff68635c),
          side: const BorderSide(color: Color(0xffe6e2dd)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed)
                ? Colors.transparent
                : null,
          ),
        ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SvgPicture.asset(
          'assets/onboarding/icon-$asset.svg',
          width: 18,
          height: 18,
          excludeFromSemantics: true,
        ),
        const SizedBox(width: 8),
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    ),
  );
}
