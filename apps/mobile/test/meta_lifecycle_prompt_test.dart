import 'dart:async';

import 'package:dopmi_mobile/core/ui.dart';
import 'package:dopmi_mobile/core/meta_lifecycle_measurement.dart';
import 'package:dopmi_mobile/core/meta_lifecycle_provider.dart';
import 'package:dopmi_mobile/features/profile/meta_lifecycle_consent_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Exercise actual controller failures at the plugin storage boundary.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _FailOffStore extends InMemorySharedPreferencesStore {
  _FailOffStore() : super.withData({});
  bool failOff = false;
  int offWrites = 0;
  Completer<void>? holdOn;
  final onStarted = Completer<void>();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key.contains('.metaLifecycle.') &&
        value is String &&
        value.contains('"consent":true') &&
        holdOn != null) {
      if (!onStarted.isCompleted) onStarted.complete();
      await holdOn!.future;
    }
    if (key.contains('.metaLifecycle.') &&
        value is String &&
        value.contains('"consent":false')) {
      offWrites++;
      if (failOff) return false;
    }
    return super.setValue(valueType, key, value);
  }
}

class _AvailableNative implements MetaLifecycleNative {
  int reads = 0;
  @override
  bool get available => true;
  @override
  Future<MetaLifecycleContext?> readContext() async {
    reads++;
    return null;
  }

  @override
  void cancel() {}
}

void main() {
  Future<void> mount(
    WidgetTester tester,
    Future<void> Function(bool) choose, {
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
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
        home: MetaLifecyclePrompt(onConfirm: choose),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pump();
  }

  testWidgets('opening and reading notice makes no measurement choice', (
    tester,
  ) async {
    final choices = <bool>[];
    await mount(tester, (value) async => choices.add(value));
    expect(choices, isEmpty);
    await tap(tester, 'Leer el aviso de esta medición');
    expect(find.textContaining('meta-lifecycle-2026-11-24'), findsOneWidget);
    expect(choices, isEmpty);
  });

  testWidgets('continuing without activating saves only an explicit OFF', (
    tester,
  ) async {
    final choices = <bool>[];
    await mount(tester, (value) async => choices.add(value));
    await tap(tester, 'Continuar sin activar');
    await tester.pumpAndSettle();
    expect(choices, [false]);
  });

  testWidgets(
    'allow requires a tap and duplicate taps do not repeat the write',
    (tester) async {
      final pending = Completer<void>();
      final choices = <bool>[];
      await mount(tester, (value) {
        choices.add(value);
        return pending.future;
      });
      await tap(tester, 'Permitir medición de anuncios');
      expect(choices, [true]);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Continuar sin activar'),
            )
            .onPressed,
        isNull,
      );
      pending.complete();
      await tester.pumpAndSettle();
      expect(choices, [true]);
    },
  );

  testWidgets('failed ON can still continue OFF and large text stays usable', (
    tester,
  ) async {
    final choices = <bool>[];
    await mount(tester, (value) async {
      choices.add(value);
      if (value) throw StateError('synthetic storage failure');
    }, scale: 2);
    await tap(tester, 'Permitir medición de anuncios');
    await tester.pumpAndSettle();
    expect(find.textContaining('No pudimos guardar'), findsOneWidget);
    await tap(tester, 'Continuar sin activar');
    await tester.pumpAndSettle();
    expect(choices, [true, false]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed OFF remains visible and can persist OFF without re-enabling',
    (tester) async {
      final previous = SharedPreferencesStorePlatform.instance;
      final storage = _FailOffStore();
      SharedPreferences.resetStatic();
      SharedPreferencesStorePlatform.instance = storage;
      addTearDown(() {
        SharedPreferencesStorePlatform.instance = previous;
        SharedPreferences.resetStatic();
      });
      final controller = MetaLifecycleController(
        await SharedPreferences.getInstance(),
        'production.fixture',
        configured: true,
        appId: '1156849688851390',
        clientToken: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        readGate: () async => false,
        native: _AvailableNative(),
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.setConsent(true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            metaLifecycleControllerProvider.overrideWithValue(controller),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: MetaLifecyclePrivacyControl()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      storage.failOff = true;
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(controller.consent, isFalse);
      expect(find.textContaining('se apagó para esta sesión'), findsOneWidget);
      expect(find.text('Volver a guardar desactivado'), findsOneWidget);
      storage.failOff = false;
      await tap(tester, 'Volver a guardar desactivado');
      await tester.pumpAndSettle();
      expect(storage.offWrites, 2);
      expect(controller.consent, isFalse);
      expect(find.textContaining('se apagó para esta sesión'), findsNothing);
    },
  );

  testWidgets(
    'allow finishing after background does not reopen identifier access',
    (tester) async {
      final previous = SharedPreferencesStorePlatform.instance;
      final storage = _FailOffStore()..holdOn = Completer<void>();
      SharedPreferences.resetStatic();
      SharedPreferencesStorePlatform.instance = storage;
      final native = _AvailableNative();
      addTearDown(() {
        SharedPreferencesStorePlatform.instance = previous;
        SharedPreferences.resetStatic();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      });
      final controller = MetaLifecycleController(
        await SharedPreferences.getInstance(),
        'production.fixture',
        configured: true,
        appId: '1156849688851390',
        clientToken: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        readGate: () async => true,
        native: native,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            metaLifecycleControllerProvider.overrideWithValue(controller),
          ],
          child: const MaterialApp(
            home: MetaLifecycleConsentGate(
              child: Scaffold(body: Text('Login disponible')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, 'Permitir medición de anuncios');
      await storage.onStarted.future;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      controller.background();
      storage.holdOn!.complete();
      await tester.pumpAndSettle();
      expect(
        controller.consent,
        isTrue,
        reason: 'the choice can finish saving',
      );
      expect(
        native.reads,
        0,
        reason: 'only a real resume may start measurement',
      );
    },
  );
}
