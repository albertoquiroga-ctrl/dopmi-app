import 'package:dopmi_mobile/features/adoption/publication_age.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Age expressions preserve real months and legacy drafts', () {
    for (final entry in {
      '': 0,
      '0': 0,
      '24': 24,
      '3 meses': 3,
      '1 mes': 1,
      '2 años': 24,
      '1 año y 6 meses': 18,
      '1 ano 2 meses': 14,
      ' 30 AÑOS ': 360,
      '360 meses': 360,
    }.entries) {
      expect(publicationAgeMonths(entry.key), entry.value, reason: entry.key);
    }
  });
  test('Invalid ages cannot silently turn into newborns', () {
    for (final value in [
      '-1',
      '361',
      '9223372036854775807 años',
      '31 años',
      'dos años',
      '1.5 años',
      '3 meses basura',
      'meses',
      '1 año y',
      '9999999999999999999999999 años',
    ]) {
      expect(publicationAgeMonths(value), isNull, reason: value);
    }
  });
}
