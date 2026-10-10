import 'package:dopmi_mobile/features/profile/impact_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 4, 12);
  test('Publication age uses the actual instant and correct Spanish units', () {
    final values = <Duration, String>{
      Duration.zero: 'Hace un momento',
      const Duration(minutes: 1): 'Hace 1 minuto',
      const Duration(minutes: 59): 'Hace 59 minutos',
      const Duration(hours: 1): 'Hace 1 hora',
      const Duration(hours: 23): 'Hace 23 horas',
      const Duration(days: 1): 'Hace 1 día',
      const Duration(days: 2): 'Hace 2 días',
      const Duration(days: 7): 'Hace 1 semana',
      const Duration(days: 14): 'Hace 2 semanas',
    };
    for (final value in values.entries) {
      expect(
        impactElapsed(now.subtract(value.key).toIso8601String(), now: now),
        value.value,
      );
    }
    expect(impactElapsed('2026-10-04T05:00:00-06:00', now: now), 'Hace 1 hora');
  });
  test('Missing or future publications never invent elapsed time', () {
    expect(impactElapsed(null, now: now), 'Fecha no disponible');
    expect(impactElapsed('invalid', now: now), 'Fecha no disponible');
    expect(
      impactElapsed('2026-10-05T12:00:00Z', now: now),
      isNot(startsWith('Hace')),
    );
  });
}
