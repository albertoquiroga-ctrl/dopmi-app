import 'package:dopmi_mobile/features/adoption/community_repository.dart';
import 'package:dopmi_mobile/features/rescue/rescue_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PublicCases extends RescueRepository {
  PublicCases(this.expense, this.snapshot)
    : super(SupabaseClient('http://localhost:54321', 'test'));
  final List<RescueRecord> expense, snapshot;
  final requests = <String?>[];
  @override
  Future<DataPage<RescueRecord>> catalog(int page, {String? caseId}) async {
    requests.add(caseId);
    final items = caseId == 'expense-one' ? expense : snapshot;
    return DataPage(items, items.length);
  }
}

void main() {
  final expense = RescueRecord({
    'id': 'expense-one',
    'kind': 'expense',
    'parent_id': 'case-one',
    'status': 'approved',
  });
  final parent = RescueRecord({
    'id': 'case-one',
    'kind': 'case',
    'status': 'approved',
  });
  test(
    'Resolves the public parent rather than using the expense as a case ID',
    () async {
      final repo = PublicCases([expense], [parent, expense]);
      expect(await repo.publicCaseForExpense('expense-one'), 'case-one');
      expect(repo.requests, ['expense-one', 'case-one']);
    },
  );
  test('Withdrawn parent discards the previous public expense', () async {
    expect(
      await PublicCases([expense], []).publicCaseForExpense('expense-one'),
      isNull,
    );
  });
  test(
    'Missing expense in the current parent snapshot cannot navigate',
    () async {
      expect(
        await PublicCases(
          [expense],
          [parent],
        ).publicCaseForExpense('expense-one'),
        isNull,
      );
    },
  );
  test('Wrong record kind cannot be treated as an expense', () async {
    final wrong = RescueRecord({
      'id': 'expense-one',
      'kind': 'case',
      'status': 'approved',
    });
    final repo = PublicCases([wrong], [parent, expense]);
    expect(await repo.publicCaseForExpense('expense-one'), isNull);
    expect(repo.requests, ['expense-one']);
  });
}
