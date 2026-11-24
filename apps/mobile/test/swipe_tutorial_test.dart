import 'package:dopmi_mobile/features/adoption/swipe_tutorial.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> showTutorial(
  WidgetTester tester, {
  required VoidCallback onDone,
  bool reducedMotion = true,
  double textScale = 1,
  Size size = const Size(377, 852),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reducedMotion,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: SwipeTutorial(onDone: onDone),
    ),
  );
}

void main() {
  testWidgets('buttons teach save then pass before finishing once', (
    tester,
  ) async {
    var completed = 0;
    await showTutorial(tester, onDone: () => completed++);
    expect(find.text('Desliza a la derecha'), findsOneWidget);
    expect(find.textContaining('Mis matches'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsWidgets);
    expect(completed, 0);

    await tester.tap(find.text('Probar guardar'));
    await tester.pump();
    expect(find.text('Desliza a la izquierda'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsWidgets);
    expect(find.textContaining('otra mascota'), findsOneWidget);
    expect(completed, 0);

    await tester.tap(find.text('Probar pasar'));
    await tester.pump();
    expect(find.text('Empezar a descubrir'), findsOneWidget);
    expect(completed, 0);
    await tester.tap(find.text('Empezar a descubrir'));
    await tester.tap(find.text('Empezar a descubrir'));
    expect(completed, 1);
  });

  testWidgets('practice accepts only the taught swipe direction', (
    tester,
  ) async {
    var completed = 0;
    await showTutorial(tester, onDone: () => completed++);
    final card = find.byKey(const ValueKey('swipe-tutorial-card'));
    await tester.drag(card, const Offset(-150, 0));
    await tester.pump();
    expect(find.text('Desliza a la derecha'), findsOneWidget);
    await tester.drag(card, const Offset(150, 0));
    await tester.pump();
    expect(find.text('Desliza a la izquierda'), findsOneWidget);
    await tester.drag(card, const Offset(150, 0));
    await tester.pump();
    expect(find.text('Desliza a la izquierda'), findsOneWidget);
    await tester.drag(card, const Offset(-150, 0));
    await tester.pump();
    expect(find.text('Empezar a descubrir'), findsOneWidget);
    expect(completed, 0);
  });

  for (final step in [0, 1, 2]) {
    testWidgets('skip is available and closes once at step $step', (
      tester,
    ) async {
      var completed = 0;
      await showTutorial(tester, onDone: () => completed++);
      if (step > 0) {
        await tester.tap(find.text('Probar guardar'));
        await tester.pump();
      }
      if (step > 1) {
        await tester.tap(find.text('Probar pasar'));
        await tester.pump();
      }
      await tester.tap(find.text('Omitir'));
      await tester.tap(find.text('Omitir'));
      await tester.pump(const Duration(minutes: 1));
      expect(completed, 1);
    });
  }

  testWidgets('hand moves directionally without advancing on a timer', (
    tester,
  ) async {
    var completed = 0;
    await showTutorial(tester, onDone: () => completed++, reducedMotion: false);
    final hand = find.byKey(const ValueKey('swipe-tutorial-hand'));
    final rightStart = tester.getCenter(hand).dx;
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.getCenter(hand).dx, greaterThan(rightStart));
    await tester.tap(find.text('Probar guardar'));
    await tester.pump();
    final leftStart = tester.getCenter(hand).dx;
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.getCenter(hand).dx, lessThan(leftStart));
    await tester.pump(const Duration(minutes: 1));
    expect(find.text('Desliza a la izquierda'), findsOneWidget);
    expect(completed, 0);
    await tester.pumpWidget(const SizedBox());
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('reduced motion leaves a static accessible gesture cue', (
    tester,
  ) async {
    await showTutorial(tester, onDone: () {});
    final semantics = tester.ensureSemantics();
    try {
      final hand = find.byKey(const ValueKey('swipe-tutorial-hand'));
      final start = tester.getCenter(hand);
      await tester.pump(const Duration(seconds: 5));
      expect(tester.getCenter(hand), start);
      expect(tester.binding.transientCallbackCount, 0);
      expect(
        find.bySemanticsLabel(
          'Tarjeta de práctica. Desliza a la derecha para guardar.',
        ),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('system back skips the tutorial exactly once', (tester) async {
    var completed = 0;
    await showTutorial(tester, onDone: () => completed++);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(completed, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('motion preference changes stop and resume the current cue', (
    tester,
  ) async {
    var completed = 0;
    await showTutorial(tester, onDone: () => completed++, reducedMotion: false);
    await tester.pump(const Duration(milliseconds: 400));
    await showTutorial(tester, onDone: () => completed++);
    final hand = find.byKey(const ValueKey('swipe-tutorial-hand'));
    final still = tester.getCenter(hand);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.getCenter(hand), still);
    expect(tester.binding.transientCallbackCount, 0);
    await showTutorial(tester, onDone: () => completed++, reducedMotion: false);
    final restart = tester.getCenter(hand);
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.getCenter(hand), isNot(restart));
    expect(find.text('Desliza a la derecha'), findsOneWidget);
    expect(completed, 0);
    await tester.pumpWidget(const SizedBox());
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('320px with 200% text keeps all controls reachable', (
    tester,
  ) async {
    var completed = 0;
    await showTutorial(
      tester,
      onDone: () => completed++,
      textScale: 2,
      size: const Size(320, 640),
    );
    for (final label in [
      'Probar guardar',
      'Probar pasar',
      'Empezar a descubrir',
    ]) {
      expect(find.text('Omitir').hitTestable(), findsOneWidget);
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
    expect(completed, 1);
  });
}
