import 'dart:async';

import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/features/profile/usage_analytics_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> mount(
    WidgetTester tester, {
    required Future<void> Function(bool) onConfirm,
    VoidCallback? onPrivacy,
    bool initialValue = true,
    bool isReview = false,
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: dopmiTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: UsageAnalyticsPrompt(
          key: const ValueKey('analytics-choice:one'),
          onConfirm: onConfirm,
          onPrivacy: onPrivacy ?? () {},
          initialValue: initialValue,
          isReview: isReview,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final target = find.text(text);
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pump();
  }

  testWidgets('preselection makes no choice until the person confirms', (
    tester,
  ) async {
    final choices = <bool>[];
    await mount(tester, onConfirm: (value) async => choices.add(value));

    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
    expect(find.text('Analítica de uso'), findsOneWidget);
    expect(choices, isEmpty);

    await tapText(tester, 'Guardar elección y continuar');
    await tester.pumpAndSettle();
    expect(choices, [true]);
  });

  testWidgets('changing the selection to OFF saves only OFF', (tester) async {
    final choices = <bool>[];
    await mount(tester, onConfirm: (value) async => choices.add(value));
    final toggle = find.byType(SwitchListTile);
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pump();
    expect(choices, isEmpty);

    await tapText(tester, 'Guardar elección y continuar');
    await tester.pumpAndSettle();
    expect(choices, [false]);
  });

  testWidgets('review starts OFF and confirming preserves that choice', (
    tester,
  ) async {
    final choices = <bool>[];
    await mount(
      tester,
      onConfirm: (value) async => choices.add(value),
      isReview: true,
    );
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
    expect(find.textContaining('mientras revisas'), findsOneWidget);
    expect(choices, isEmpty);
    await tapText(tester, 'Guardar elección y continuar');
    await tester.pumpAndSettle();
    expect(choices, [false]);
  });

  testWidgets(
    'review can enable analytics only after a deliberate selection and save',
    (tester) async {
      final choices = <bool>[];
      await mount(
        tester,
        onConfirm: (value) async => choices.add(value),
        isReview: true,
      );
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      expect(choices, isEmpty);
      await tapText(tester, 'Guardar elección y continuar');
      await tester.pumpAndSettle();
      expect(choices, [true]);
    },
  );

  testWidgets(
    'a supplied OFF is never replaced by the new-account ON proposal',
    (tester) async {
      final choices = <bool>[];
      await mount(
        tester,
        onConfirm: (value) async => choices.add(value),
        initialValue: false,
      );
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      expect(choices, isEmpty);
    },
  );

  testWidgets(
    'same prompt changes an ON proposal into OFF review without saving',
    (tester) async {
      final choices = <bool>[];
      Future<void> choose(bool value) async => choices.add(value);
      await mount(tester, onConfirm: choose);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
      await mount(tester, onConfirm: choose, isReview: true);
      expect(find.textContaining('mientras revisas'), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      expect(choices, isEmpty);
    },
  );

  testWidgets(
    'a rebuild in review mode keeps a deliberate selection until save',
    (tester) async {
      final choices = <bool>[];
      Future<void> choose(bool value) async => choices.add(value);
      await mount(tester, onConfirm: choose, isReview: true);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
      await mount(tester, onConfirm: choose, isReview: true);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
      expect(choices, isEmpty);
    },
  );

  testWidgets('continuing without analytics overrides the ON preselection', (
    tester,
  ) async {
    final choices = <bool>[];
    await mount(tester, onConfirm: (value) async => choices.add(value));

    await tapText(tester, 'Continuar sin analítica');
    await tester.pumpAndSettle();
    expect(choices, [false]);
  });

  testWidgets('pending confirmation disables duplicate choices and privacy', (
    tester,
  ) async {
    final pending = Completer<void>();
    final choices = <bool>[];
    var privacyOpened = 0;
    await mount(
      tester,
      onConfirm: (value) {
        choices.add(value);
        return pending.future;
      },
      onPrivacy: () => privacyOpened++,
    );

    await tapText(tester, 'Guardar elección y continuar');
    expect(choices, [true]);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
      isNull,
    );
    for (final button in tester.widgetList<TextButton>(
      find.byType(TextButton),
    )) {
      expect(button.onPressed, isNull);
    }
    expect(privacyOpened, 0);
    pending.complete();
    await tester.pumpAndSettle();
    expect(choices, [true]);
  });

  testWidgets('failed confirmation can continue without analytics', (
    tester,
  ) async {
    final choices = <bool>[];
    await mount(
      tester,
      onConfirm: (value) async {
        choices.add(value);
        if (value) throw StateError('synthetic network failure');
      },
    );

    await tapText(tester, 'Guardar elección y continuar');
    await tester.pumpAndSettle();
    expect(find.textContaining('No pudimos guardar'), findsOneWidget);
    expect(find.textContaining('synthetic'), findsNothing);

    await tapText(tester, 'Continuar sin analítica');
    await tester.pumpAndSettle();
    expect(choices, [true, false]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('privacy can be read without confirming a choice', (
    tester,
  ) async {
    final choices = <bool>[];
    var privacyOpened = 0;
    await mount(
      tester,
      onConfirm: (value) async => choices.add(value),
      onPrivacy: () => privacyOpened++,
    );

    await tapText(tester, 'Leer el aviso de privacidad');
    expect(privacyOpened, 1);
    expect(choices, isEmpty);
  });

  testWidgets('small screen and 200 percent text keep both choices reachable', (
    tester,
  ) async {
    final choices = <bool>[];
    await mount(
      tester,
      onConfirm: (value) async => choices.add(value),
      size: const Size(320, 640),
      scale: 2,
    );

    await tester.ensureVisible(find.text('Guardar elección y continuar'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tapText(tester, 'Continuar sin analítica');
    await tester.pumpAndSettle();
    expect(choices, [false]);
    expect(tester.takeException(), isNull);
  });
}
