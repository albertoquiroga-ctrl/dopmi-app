import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../adoption/community_repository.dart';
import 'payment_repository.dart';

const guardianConsent = 'guardian-2026-09-24';
final guardianEnabledProvider = Provider<bool>(
  (ref) => const bool.fromEnvironment('ENABLE_GUARDIAN_TEST'),
);
final guardianRepositoryProvider = Provider<GuardianRepository>(
  (ref) => GuardianRepository(Supabase.instance.client),
);

class GuardianRepository {
  GuardianRepository(this.client);
  final SupabaseClient client;
  Future<Json> state() async =>
      Json.from(await client.rpc('dopmi_guardian_state'));
  Future<Json> history({Json? cursor}) async => Json.from(
    await client.rpc(
      'dopmi_guardian_history',
      params: {
        'before_created_at': cursor?['created_at'],
        'before_id': cursor?['id'],
      },
    ),
  );
  Future<Json> allocations(String cycleId, {String? cursor}) async => Json.from(
    await client.rpc(
      'dopmi_guardian_history_allocations',
      params: {'target_cycle': cycleId, 'after_expense': cursor},
    ),
  );

  Future<bool> capacity(int cents) async {
    final result = await client.rpc(
      'dopmi_guardian_capacity_preview',
      params: {'target_gross': cents},
    );
    return result['can_activate'] == true;
  }

  Future<Json> submit(Json intent) async {
    if (intent['kind'] == 'cancel_activation') {
      return Json.from(
        await client.rpc(
          'dopmi_guardian_cancel_activation',
          params: {'activation_key': intent['key']},
        ),
      );
    }
    if (['checkout', 'method'].contains(intent['kind'])) {
      final result = await client.functions.invoke(
        'guardian-client',
        body: {
          'action': intent['kind'],
          'key': intent['key'],
          if (intent['kind'] == 'checkout') 'gross_cents': intent['cents'],
          if (intent['kind'] == 'method') 'revision': intent['revision'],
          'consent': true,
          'consent_version': intent['consent_version'],
        },
      );
      return Json.from(result.data as Map);
    }
    return Json.from(
      await client.rpc(
        'dopmi_guardian_request',
        params: {
          'request_kind': intent['kind'],
          'request_key': intent['key'],
          'expected_revision': intent['revision'],
          'new_gross_cents': intent['kind'] == 'amount'
              ? intent['cents']
              : null,
          'consent_version': intent['kind'] == 'amount'
              ? intent['consent_version']
              : null,
        },
      ),
    );
  }

  Future<void> openCheckout(String url) =>
      PaymentRepository(client).openStripe(url);
}

String guardianError(Object error) {
  if (guardianMethodRejected(error)) {
    return 'El plan cambió o tiene una operación en conciliación. Actualiza su estado antes de autorizar el cambio de medio de pago.';
  }
  if (error is FunctionException &&
      error.details is Map &&
      (error.details as Map)['error'] == 'guardian_disabled') {
    return 'Guardián todavía no está habilitado. Conservamos tu intento.';
  }
  if (error is PostgrestException) {
    if (error.code == '22023') {
      return 'La solicitud no fue aceptada. Actualiza el estado y revisa el importe antes de autorizar de nuevo.';
    }
    if (error.code == '40001') {
      return 'El plan cambió en otro dispositivo. Actualiza el estado antes de continuar.';
    }
    if (error.code == '42501') {
      return 'Tu cuenta no puede realizar esta operación. La cancelación de un plan sigue disponible con tu sesión.';
    }
  }
  return 'No pudimos confirmar el resultado. Actualiza el estado o reintenta la misma solicitud; no inicies otro pago.';
}

bool guardianRejected(Object error) =>
    (error is PostgrestException && ['40001', '22023'].contains(error.code)) ||
    guardianMethodRejected(error);

bool guardianMethodRejected(Object error) =>
    error is FunctionException &&
    error.details is Map &&
    [
      'guardian_plan_changed',
      'guardian_method_invalid',
      'guardian_method_busy',
      'guardian_account_unavailable',
    ].contains((error.details as Map)['error']);

const guardianMethodLabels = {
  'pending': 'Actualización pendiente: continúa en Stripe para guardar y autenticar tu medio de pago.',
  'attention':
      'El cambio de medio de pago está en revisión. Conservamos tu solicitud.',
  'applied': 'Medio de pago actualizado para los próximos ciclos. No se realizó un cobro por este cambio.',
  'expired':
      'La actualización venció sin aplicarse. Puedes autorizar una nueva.',
  'superseded':
      'La actualización se detuvo porque cambió el estado de tu plan.',
};

const guardianActivationLabels = {
  'pending': 'Alta pendiente de confirmación',
  'no_capacity': 'Sin capacidad: no se inició un cobro',
  'expired': 'Intento vencido sin pago confirmado',
  'failed': 'El primer pago no se completó',
  'funded_pending_schedule':
      'Primer pago confirmado; plan mensual en preparación',
  'refund_pending': 'Devolución en proceso',
  'refunded': 'Primer pago devuelto',
  'attention': 'Alta en revisión. No vuelvas a pagar.',
  'active': 'Plan activo',
  'canceled': 'Plan cancelado',
};

DateTime guardianNextBilling(DateTime today) {
  final lastDay = DateTime(today.year, today.month + 2, 0).day;
  return DateTime(
    today.year,
    today.month + 1,
    today.day > lastDay ? lastDay : today.day,
  );
}
