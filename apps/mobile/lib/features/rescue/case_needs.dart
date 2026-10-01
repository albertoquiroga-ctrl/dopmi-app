import 'package:flutter/material.dart';

import 'case_information.dart';
import 'rescue_fields.dart';

class CaseNeeds extends StatelessWidget {
  const CaseNeeds({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onChanged,
  });
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        '¿Qué necesita la mascota?',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          height: 28 / 18,
          fontWeight: FontWeight.w600,
          color: Color(0xff151423),
        ),
      ),
      const SizedBox(height: 16),
      CaseInformation(
        controllers: {'need': controller},
        enabled: enabled,
        onChanged: onChanged,
      ).field(rescueFields['case']!.firstWhere((f) => f.key == 'need')),
    ],
  );
}
