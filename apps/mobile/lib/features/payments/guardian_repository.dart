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
  Future<bool> capacity(int cents) async {
    final result = await client.rpc(
      'dopmi_guardian_capacity_preview',
      params: {'target_gross': cents},
    );
    return result['can_activate'] == true;
  }

  Future<Json> submit(Json intent) async {
    if (intent['kind'] == 'checkout') {
      final result = await client.functions.invoke(
        'guardian-client',
        body: {
          'action': 'checkout',
          'key': intent['key'],
          'gross_cents': intent['cents'],
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
  if (error is FunctionException &&
      error.details is Map &&
      (error.details as Map)['error'] == 'guardian_disabled') {
    return 'Guardián todavía no está habilitado. Conservamos tu intento.';
  }
  if (error is PostgrestException) {
    if (error.code == '40001')
      return 'El plan cambió en otro dispositivo. Actualiza el estado antes de continuar.';
    if (error.code == '42501')
      return 'Tu cuenta no puede realizar esta operación. La cancelación de un plan sigue disponible con tu sesión.';
  }
  return 'No pudimos confirmar el resultado. Actualiza el estado o reintenta la misma solicitud; no inicies otro pago.';
}

bool guardianRejected(Object error) =>
    error is PostgrestException && ['40001', '22023'].contains(error.code);

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
