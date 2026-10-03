import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/ui.dart';

// Source Toast is instantaneous and leaves after 2600ms. Removal has no
// visible Toast in Source; retain a live-region result for screen readers.
class PaymentMethodsFeedback extends StatefulWidget {
  const PaymentMethodsFeedback({
    super.key,
    required this.message,
    required this.onDone,
    this.visible = true,
  });
  final String message;
  final VoidCallback onDone;
  final bool visible;
  @override
  State<PaymentMethodsFeedback> createState() => _PaymentMethodsFeedbackState();
}

class _PaymentMethodsFeedbackState extends State<PaymentMethodsFeedback> {
  late final Timer timer;
  @override
  void initState() {
    super.initState();
    timer = Timer(const Duration(milliseconds: 2600), widget.onDone);
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: widget.message,
    excludeSemantics: true,
    child: !widget.visible
        ? const SizedBox.shrink()
        : Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xffe6e2dd)),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: ink.withValues(alpha: .14),
                  offset: const Offset(0, 12),
                  blurRadius: 32,
                ),
              ],
            ),
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/profile/check.svg',
                  width: 16,
                  height: 16,
                  colorFilter: const ColorFilter.mode(ink, BlendMode.srcIn),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.message,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
  );
}
