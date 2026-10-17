import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../adoption/community_repository.dart';

final monthlyImpactRepositoryProvider = Provider<MonthlyImpactRepository>(
  (ref) => SupabaseMonthlyImpactRepository(Supabase.instance.client),
);

abstract class MonthlyImpactRepository {
  Future<MonthlyPersonalImpact> personal({String? month});
  Future<MonthlyCommunityImpact> community({String? month});
}

class MonthlyPersonalImpact {
  const MonthlyPersonalImpact({
    required this.month,
    required this.currentMonth,
    required this.allocatedCents,
    required this.casesSupported,
    required this.caseIds,
  });
  final String month, currentMonth;
  final int allocatedCents, casesSupported;
  final List<String> caseIds;

  factory MonthlyPersonalImpact.fromJson(Json data) => MonthlyPersonalImpact(
    month: _month(data),
    currentMonth: _month({...data, 'month': data['current_month']}),
    allocatedCents: _count(data, 'allocated_cents'),
    casesSupported: _count(data, 'cases_supported'),
    caseIds: List<String>.unmodifiable(
      (data['case_ids'] as List).cast<String>(),
    ),
  );
}

class MonthlyCommunityImpact {
  const MonthlyCommunityImpact({
    required this.month,
    required this.casesSupported,
    required this.urgentCasesCovered,
    required this.measurementStatus,
    required this.measurementStartedAt,
    required this.measurementStartedOn,
  });
  final String month, measurementStatus;
  final int casesSupported;
  final int? urgentCasesCovered;
  final DateTime? measurementStartedAt;
  final String? measurementStartedOn;

  factory MonthlyCommunityImpact.fromJson(Json data) {
    final status = data['measurement_status'];
    if (!['not_measured', 'partial', 'complete'].contains(status)) {
      throw const FormatException('Medición no confirmada');
    }
    final urgent = data['urgent_cases_covered'];
    if ((status == 'not_measured' && urgent != null) ||
        (status != 'not_measured' && (urgent is! int || urgent < 0))) {
      throw const FormatException('Medición no confirmada');
    }
    final started = data['measurement_started_at'];
    final date = started == null ? null : DateTime.tryParse(started.toString());
    if (started != null && date == null) {
      throw const FormatException('Medición no confirmada');
    }
    final startedOn = data['measurement_started_on'];
    if ((startedOn != null &&
            (startedOn is! String ||
                !RegExp(r'^\d{4}-(0[1-9]|1[0-2])-([0-2]\d|3[01])$')
                    .hasMatch(startedOn))) ||
        (status != 'not_measured' && startedOn == null)) {
      throw const FormatException('Fecha de medición no confirmada');
    }
    return MonthlyCommunityImpact(
      month: _month(data),
      casesSupported: _count(data, 'cases_supported'),
      urgentCasesCovered: urgent as int?,
      measurementStatus: status as String,
      measurementStartedAt: date,
      measurementStartedOn: startedOn as String?,
    );
  }
}

int _count(Json data, String key) {
  final value = data[key];
  if (value is! int || value < 0) {
    throw const FormatException('Impacto no confirmado');
  }
  return value;
}

String _month(Json data) {
  final value = data['month'];
  if (value is! String ||
      !RegExp(r'^\d{4}-(0[1-9]|1[0-2])-01$').hasMatch(value) ||
      data['timezone'] != 'America/Mexico_City') {
    throw const FormatException('Período no confirmado');
  }
  return value;
}

class SupabaseMonthlyImpactRepository implements MonthlyImpactRepository {
  SupabaseMonthlyImpactRepository(this.client);
  final SupabaseClient client;
  Future<Json> _read(String name, String? month) async =>
      Json.from(await client.rpc(name, params: {'target_month': month}) as Map);
  @override
  Future<MonthlyPersonalImpact> personal({String? month}) async =>
      MonthlyPersonalImpact.fromJson(
        await _read('dopmi_monthly_personal_impact', month),
      );
  @override
  Future<MonthlyCommunityImpact> community({String? month}) async =>
      MonthlyCommunityImpact.fromJson(
        await _read('dopmi_monthly_community_impact', month),
      );
}
