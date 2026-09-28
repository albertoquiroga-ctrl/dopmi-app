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
}
