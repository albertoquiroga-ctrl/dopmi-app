import 'package:dopmi_mobile/features/rescue/need_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'needs order is stable and preserves category and financial amounts',
    () {
      final values = [
        {'id': 'food', 'type': 'food', 'amount_cents': 30},
        {'id': 'other', 'type': 'other', 'amount_cents': 10},
        {'id': 'medicine', 'type': 'medicine', 'amount_cents': 40},
        {'id': 'vet1', 'type': 'veterinary', 'amount_cents': 50},
        {'id': 'vet2', 'type': 'veterinary', 'amount_cents': 20},
      ];
      final ordered = orderedNeedItems(values);
      expect(ordered.map((item) => item['id']), [
        'vet1',
        'vet2',
        'medicine',
        'food',
        'other',
      ]);
      expect(ordered.map((item) => item['amount_cents']), [50, 20, 40, 30, 10]);
      expect(values.first['id'], 'food');
    },
  );
}
