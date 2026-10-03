import 'package:flutter/material.dart';

class VerificationFormFrame extends StatelessWidget {
  const VerificationFormFrame({
    super.key,
    required this.children,
    this.onBack,
    this.title = 'Formulario de verificación',
    this.bodyPadding = const EdgeInsets.fromLTRB(16, 20, 16, 32),
  });
  final List<Widget> children;
  final String title;
  final EdgeInsets bodyPadding;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Column(
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xffe3e4ed))),
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
                        color: Color(0xff151423),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18,
                          height: 1.55,
                          fontWeight: FontWeight.w700,
                          color: Color(0xff151423),
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
              padding: bodyPadding,
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
          color: Color(0xff151423),
        ),
      ),
    ),
  );
}
