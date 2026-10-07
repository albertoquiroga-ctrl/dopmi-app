import 'package:flutter_test/flutter_test.dart';
import 'package:dopmi_mobile/core/adoption_view_day.dart';

void main() {
  test('measurement day changes at Mexico City midnight, not UTC midnight', () {
    expect(
      adoptionViewDay(DateTime.parse('2026-10-07T05:59:59Z')),
      '2026-10-06',
    );
    expect(
      adoptionViewDay(DateTime.parse('2026-10-07T06:00:00Z')),
      '2026-10-07',
    );
    expect(
      adoptionViewDay(DateTime.parse('2026-10-07T00:01:00Z')),
      '2026-10-06',
    );
  });
}
