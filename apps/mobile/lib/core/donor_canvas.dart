import 'package:flutter/material.dart';

/// Frozen b9f6d5f warm-trust donor canvas (styles.css:14102–14114).
/// CSS feTurbulence grain is intentionally omitted: Flutter's SVG renderer
/// cannot render that filter. No unrelated bitmap or random noise substitutes it.
class DonorCanvas extends StatelessWidget {
  const DonorCanvas({super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) => !enabled
      ? child
      : Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _DonorCanvasPainter()),
              ),
            ),
            child,
          ],
        );
}

class _DonorCanvasPainter extends CustomPainter {
  const _DonorCanvasPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    void sphere(
      Offset center,
      double radius,
      List<Color> colors,
      List<double> stops,
    ) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: colors,
            stops: stops,
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    // CSS background layers are composited back-to-front.
    sphere(
      Offset(size.width * .86, size.height * .92),
      168,
      const [
        Color(0x80b5b5b5),
        Color(0x80d2d2d2),
        Color(0x80ededed),
        Color(0x00ededed),
      ],
      const [0, .36, .56, .76],
    );
    sphere(
      Offset(size.width * .02, size.height * .58),
      138,
      const [
        Color(0x80adadad),
        Color(0x80cbcbcb),
        Color(0x80e8e8e8),
        Color(0x00e8e8e8),
      ],
      const [0, .34, .54, .74],
    );
    sphere(
      Offset(size.width * .90, size.height * .10),
      158,
      const [
        Color(0x47a8a8a8),
        Color(0x47c6c6c6),
        Color(0x47e6e6e6),
        Color(0x00e6e6e6),
      ],
      const [0, .32, .52, .72],
    );
  }

  @override
  bool shouldRepaint(covariant _DonorCanvasPainter oldDelegate) => false;
}
