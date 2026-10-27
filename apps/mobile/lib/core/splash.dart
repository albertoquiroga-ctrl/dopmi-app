import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_tokens.dart';

/// Brand presentation while existing session/consent checks resolve. It adds
/// neither a timer nor a navigation action to the identity lifecycle.
class DopmiSplash extends StatelessWidget {
  const DopmiSplash({super.key, this.label = 'Restaurando sesión'});
  final String label;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
    ),
    child: Scaffold(
      backgroundColor: DopmiTokens.ink,
      body: Semantics(
        label: label,
        liveRegion: true,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Image.asset(
              'assets/onboarding/splash-wordmark.png',
              width: 258,
              height: 86,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
          ),
        ),
      ),
    ),
  );
}
