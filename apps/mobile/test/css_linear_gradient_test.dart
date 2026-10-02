import 'dart:ui' as ui;

import 'package:dopmi_mobile/core/css_linear_gradient.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dimensions in const [(200, 100, 85, 170), (100, 200, 170, 85)]) {
    test(
      'CSS diagonal has magic corners independent of aspect ratio: $dimensions',
      () async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        final rect = Rect.fromLTWH(
          0,
          0,
          dimensions.$1.toDouble(),
          dimensions.$2.toDouble(),
        );
        canvas.drawRect(
          rect,
          Paint()
            ..shader = const CssLinearGradient(
              degrees: 45,
              colors: [Color(0xff000000), Color(0xffffffff)],
            ).createShader(rect),
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(dimensions.$1, dimensions.$2);
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        int value(int x, int y) => bytes.getUint8((y * dimensions.$1 + x) * 4);
        expect(value(0, 0), closeTo(dimensions.$3, 2));
        expect(value(dimensions.$1 - 1, 0), closeTo(254, 2));
        expect(value(0, dimensions.$2 - 1), closeTo(1, 2));
        expect(
          value(dimensions.$1 - 1, dimensions.$2 - 1),
          closeTo(dimensions.$4, 2),
        );
        image.dispose();
        picture.dispose();
      },
    );
  }
  test('gradient tween retains CSS angles colors and stops', () {
    const a = CssLinearGradient(
      degrees: 149,
      colors: [Color(0xff000000), Color(0xff808080), Color(0xffffffff)],
      stops: [0, .55, 1],
    );
    const b = CssLinearGradient(
      degrees: 155,
      colors: [Color(0xff000000), Color(0xff808080), Color(0xffffffff)],
      stops: [0, .55, 1],
    );
    final value = Gradient.lerp(a, b, .5)! as CssLinearGradient;
    expect(value.degrees, 152);
    expect(value.stops, [0, .55, 1]);
    expect(a.withOpacity(.25).colors.every((color) => color.a == .25), isTrue);
    expect(a.fromColor(const Color(0xff7841f2)).degrees, 149);
    expect(a.fromColor(const Color(0xff7841f2)).stops, [0, .55, 1]);
    expect(Gradient.lerp(a, b, 0), a);
    expect(Gradient.lerp(a, b, 1), b);
    expect((Gradient.lerp(null, a, .5)! as CssLinearGradient).degrees, 149);
  });
}
