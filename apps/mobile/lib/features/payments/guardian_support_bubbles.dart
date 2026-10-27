import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Decorative photographs from the frozen mock; never financial case data.
class GuardianSupportBubbles extends StatefulWidget {
  const GuardianSupportBubbles({super.key, required this.burst});
  final int burst;

  @override
  State<GuardianSupportBubbles> createState() => _GuardianSupportBubblesState();
}

class _GuardianSupportBubblesState extends State<GuardianSupportBubbles>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  static const bubbles = [
    ('onboarding/luna-card.png', .08, .06, 78.0),
    ('onboarding/rocky.png', .38, .04, 64.0),
    ('guardian/bubbles/milo-card.png', .62, .12, 86.0),
    ('onboarding/toby.png', .18, .22, 92.0),
    ('guardian/guardian-urgent.jpg', .48, .18, 70.0),
    ('guardian/bubbles/publish-sample-pet.jpg', .72, .28, 58.0),
    ('onboarding/luna-detail.png', .04, .34, 68.0),
    ('guardian/guardian-luna.jpg', .32, .38, 80.0),
    ('guardian/guardian-milo.jpg', .56, .42, 74.0),
    ('guardian/bubbles/impact-luna.png', .78, .48, 62.0),
    ('onboarding/rocky.png', .14, .52, 56.0),
    ('guardian/bubbles/milo-card.png', .44, .56, 88.0),
    ('onboarding/luna-card.png', .68, .58, 52.0),
    ('onboarding/toby.png', .82, .08, 48.0),
  ];

  bool get reduced =>
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.accessibleNavigationOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduced) {
      controller.value = 1;
    } else if (!controller.isAnimating && controller.value == 0) {
      controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant GuardianSupportBubbles oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.burst != oldWidget.burst) {
      if (reduced) {
        controller.value = 1;
      } else {
        controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: SizedBox(
        height: (MediaQuery.sizeOf(context).height * .4).clamp(220.0, 340.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return AnimatedBuilder(
              animation: controller,
              builder: (context, _) => DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xffe6e6e6), Colors.white],
                    stops: [0, .78],
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    for (var i = 0; i < bubbles.length; i++)
                      bubble(i, constraints.maxWidth, constraints.maxHeight),
                    const Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 210,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x00ffffff), Colors.white],
                            stops: [0, .88],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  );

  Widget bubble(int i, double width, double height) {
    final (asset, x, y, size) = bubbles[i];
    // The mock computes its entry offsets against a nominal 375x320 stage.
    final entry = Offset(
      375 * .5 - (375 * x + size / 2),
      320 * .94 - (320 * y + size / 2),
    );
    final delay = (entry.distance * .45 + i * 12).round();
    final t = ((controller.value * 1100 - delay) / 720).clamp(0.0, 1.0);
    const curve = Cubic(.22, 1, .36, 1);
    final first = curve.transform((t / .68).clamp(0.0, 1.0));
    final last = curve.transform(((t - .68) / .32).clamp(0.0, 1.0));
    final scale = t <= .68 ? .1 + .95 * first : 1.05 - .05 * last;
    return Positioned(
      left: width * x,
      top: height * y,
      child: Transform.translate(
        offset: entry * (1 - first),
        child: Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: math.min(1, first),
            child: Container(
              key: ValueKey('guardian-bubble-$i'),
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0f15110d),
                    offset: Offset(0, 2),
                    blurRadius: 8,
                  ),
                  BoxShadow(
                    color: Color(0x1f15110d),
                    offset: Offset(0, 10),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset('assets/$asset', fit: BoxFit.cover),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
