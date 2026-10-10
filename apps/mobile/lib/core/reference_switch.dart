import 'package:flutter/material.dart';

class ReferenceSwitch extends StatelessWidget {
  const ReferenceSwitch({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
  });
  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    toggled: value,
    child: InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(99),
      splashFactory: NoSplash.splashFactory,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: Container(
            width: 32,
            height: 19,
            padding: const EdgeInsets.all(1),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: value ? const Color(0xff7841f2) : const Color(0xffdad7d2),
              borderRadius: BorderRadius.circular(99),
            ),
            child: AnimatedContainer(
              transform: Matrix4.translationValues(value ? 13 : 0, 0, 0),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              curve: Curves.ease,
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
