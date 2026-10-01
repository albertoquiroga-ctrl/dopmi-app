import 'package:flutter/material.dart';

class VerificationFormFrame extends StatelessWidget {
  const VerificationFormFrame({super.key, required this.children, this.onBack});
  final List<Widget> children;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Column(
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xffe6e2dd))),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 68),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: onBack,
                      tooltip: 'Volver',
                      icon: const Icon(
                        Icons.arrow_back,
                        size: 24,
                        color: Color(0xff15110d),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Formulario de verificación',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18,
                          height: 1.55,
                          fontWeight: FontWeight.w700,
                          color: Color(0xff15110d),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: MediaQuery.textScalerOf(context).scale(18) > 24
                          ? 0
                          : 48,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              key: const ValueKey('verification-form-body'),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              children: children,
            ),
          ),
        ],
      ),
    ),
  );
}

class VerificationSectionTitle extends StatelessWidget {
  const VerificationSectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 16),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 19,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: Color(0xff15110d),
        ),
      ),
    ),
  );
}
