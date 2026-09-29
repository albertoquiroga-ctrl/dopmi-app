import 'package:dopmi_mobile/core/measurement.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnalyticsSpy implements ProductAnalytics {
  bool enabledValue = false;
  final events = <String>[];
  @override
  Future<void> enabled(bool value) async => enabledValue = value;
  @override
  Future<void> event(String name, {Map<String, Object>? parameters}) async {
    events.add(name);
  }
}

class FailingAnalytics extends AnalyticsSpy {
  @override
  Future<void> event(String name, {Map<String, Object>? parameters}) async {
    throw StateError('provider unavailable');
  }
}

class DiagnosticsSpy implements ErrorDiagnostics {
  bool enabledValue = false;
  int reports = 0;
  @override
  Future<void> enabled(bool value) async => enabledValue = value;
  @override
  Future<void> record(Object error, StackTrace stack, {String? reason}) async {
    reports++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'measurement is disabled initially and sends no accumulated events',
    () async {
      SharedPreferences.setMockInitialValues({});
      final analytics = AnalyticsSpy();
      final diagnostics = DiagnosticsSpy();
      final controller = MeasurementController(
        await SharedPreferences.getInstance(),
        'test',
        analytics,
        diagnostics,
      );
      await controller.owner('alice');
      await controller.event('contact_started');
      expect(controller.analyticsEnabled, false);
      expect(controller.diagnosticsEnabled, false);
      expect(analytics.events, isEmpty);
      expect(analytics.enabledValue, false);
      expect(diagnostics.enabledValue, false);
      controller.dispose();
    },
  );

  test('consent is independent, revocable and isolated by account', () async {
    SharedPreferences.setMockInitialValues({});
    final analytics = AnalyticsSpy();
    final diagnostics = DiagnosticsSpy();
    final controller = MeasurementController(
      await SharedPreferences.getInstance(),
      'test',
      analytics,
      diagnostics,
    );
    await controller.owner('alice');
    await controller.setAnalytics(true);
    await controller.event('publication_submitted');
    expect(analytics.events, ['publication_submitted']);
    expect(diagnostics.enabledValue, false);
    await controller.owner('bob');
    expect(controller.analyticsEnabled, false);
    await controller.owner('alice');
    expect(controller.analyticsEnabled, true);
    await controller.setAnalytics(false);
    await controller.event('contact_started');
    expect(analytics.events, ['publication_submitted']);
    controller.dispose();
  });

  test('measurement rejects unknown events and every payload', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = MeasurementController(
      await SharedPreferences.getInstance(),
      'test',
      AnalyticsSpy(),
      DiagnosticsSpy(),
    );
    await controller.owner('alice');
    await controller.setAnalytics(true);
    expect(() => controller.event('unknown_event'), throwsArgumentError);
    expect(
      () => controller.event(
        'contact_started',
        parameters: {'email': 'private@example.com'},
      ),
      throwsArgumentError,
    );
    controller.dispose();
  });

  test(
    'every approved conversion event is forwarded without payload',
    () async {
      SharedPreferences.setMockInitialValues({});
      final analytics = AnalyticsSpy();
      final controller = MeasurementController(
        await SharedPreferences.getInstance(),
        'test',
        analytics,
        DiagnosticsSpy(),
      );
      await controller.owner('alice');
      await controller.setAnalytics(true);
      for (final name in FirebaseProductAnalytics.allowed) {
        await controller.event(name);
      }
      expect(analytics.events.toSet(), FirebaseProductAnalytics.allowed);
      controller.dispose();
    },
  );

  test('diagnostic test requires independent consent', () async {
    SharedPreferences.setMockInitialValues({});
    final diagnostics = DiagnosticsSpy();
    final controller = MeasurementController(
      await SharedPreferences.getInstance(),
      'test',
      AnalyticsSpy(),
      diagnostics,
    );
    await controller.owner('alice');
    await controller.diagnosticTest();
    expect(diagnostics.reports, 0);
    await controller.setDiagnostics(true);
    await controller.diagnosticTest();
    expect(diagnostics.reports, 1);
    await controller.setDiagnostics(false);
    await controller.diagnosticTest();
    expect(diagnostics.reports, 1);
    controller.dispose();
  });

  test('provider failure never changes the product result', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = MeasurementController(
      await SharedPreferences.getInstance(),
      'test',
      FailingAnalytics(),
      DiagnosticsSpy(),
    );
    await controller.owner('alice');
    await controller.setAnalytics(true);
    await expectLater(controller.event('contact_started'), completes);
    controller.dispose();
  });
}
