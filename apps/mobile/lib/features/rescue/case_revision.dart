import '../adoption/community_repository.dart';
import 'rescue_repository.dart';

class CaseRevisionPacket {
  CaseRevisionPacket(Json data)
    : revision = Json.from(data['revision'] as Map),
      record = RescueRecord(Json.from(data['record'] as Map)),
      baseRecord = RescueRecord(Json.from(data['base_record'] as Map)),
      caseUnit = Json.from(data['case_unit'] as Map? ?? {}),
      comments = (data['need_comments'] as List? ?? [])
          .map((item) => Json.from(item as Map))
          .toList(),
      publicationBlockers = (data['publication_blockers'] as List? ?? [])
          .whereType<String>()
          .toList(),
      expenses = ((data['expenses'] as Map)['items'] as List)
          .map((item) => RescueRecord(Json.from(item as Map)))
          .toList() {
    final total = (data['expenses'] as Map)['total'];
    if (total != expenses.length ||
        expenses.map((expense) => expense.id).toSet().length !=
            expenses.length ||
        revision['case_id'] != record.id ||
        baseRecord.id != record.id) {
      throw const FormatException(
        'No se pudo cargar la edición completa. Vuelve a intentarlo.',
      );
    }
  }
  final Json revision, caseUnit;
  final RescueRecord record, baseRecord;
  final List<RescueRecord> expenses;
  final List<Json> comments;
  final List<String> publicationBlockers;
  String get id => revision['id'] as String;
  int get version => revision['version'] as int;
  String get status => revision['status'] as String;
  String get reason => revision['reason'] as String? ?? '';
  bool? get publicVersionVisible => caseUnit['public_version_visible'] is bool
      ? caseUnit['public_version_visible'] as bool
      : null;
  bool get canStartRevision => caseUnit['can_start_revision'] is bool
      ? caseUnit['can_start_revision'] == true
      : (caseUnit['case_status'] ?? baseRecord.status) == 'approved' &&
            caseUnit['case_archived'] != true;
  bool get editable =>
      ['draft', 'changes_requested', 'rejected'].contains(status);
}
