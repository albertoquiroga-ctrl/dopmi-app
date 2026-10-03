import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../adoption/community_repository.dart';
import 'payment_repository.dart';
import 'guardian_payment_card.dart';

const guardianConsent = 'guardian-2026-09-24';
const savedCardConsent = 'saved-cards-2026-10-03';
const savedCardMethodConsent = 'saved-card-methods-2026-10-03';
final guardianEnabledProvider = Provider<bool>(
  (ref) => const bool.fromEnvironment('ENABLE_GUARDIAN_TEST'),
);
final guardianRepositoryProvider = Provider<GuardianRepository>(
  (ref) => GuardianRepository(Supabase.instance.client),
);

class GuardianRepository {
  GuardianRepository(this.client);
  final SupabaseClient client;
  Future<Json?> savedCardMethodState() async {
    final result = await client.rpc('dopmi_saved_card_method_state');
    return result == null ? null : savedCardMethodReceipt(result);
  }

  Future<Json?> savedCardState() async {
    final result = await client.rpc('dopmi_saved_card_state');
    return result == null ? null : savedCardReceipt(result);
  }

  Future<List<GuardianPaymentCard>> paymentMethods() async {
    final response = await client.functions.invoke(
      'guardian-client',
      body: {'action': 'methods'},
    );
    final body = response.data;
    if (response.status != 200 || body is! Map || body['items'] is! List) {
      throw const FormatException('No se pudieron consultar las tarjetas');
    }
    final cards = (body['items'] as List).map((item) {
      if (item is! Map) throw const FormatException('Tarjeta no confirmada');
      return GuardianPaymentCard.fromJson(Map<String, dynamic>.from(item));
    }).toList();
    if (cards.map((card) => card.id).toSet().length != cards.length ||
        cards.where((card) => card.isDefault).length > 1) {
      throw const FormatException('Lista no confirmada');
    }
    return cards;
  }

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
    if (intent['kind'] == 'saved_card_method') {
      if (!['default', 'remove'].contains(intent['action']) ||
          intent['consent_version'] != savedCardMethodConsent) {
        throw const FormatException('Solicitud de tarjeta incompleta');
      }
      final result = await client.functions.invoke(
        'guardian-client',
        body: {
          'action': intent['action'] == 'remove'
              ? 'saved_card_remove'
              : 'saved_card_default',
          'key': intent['key'],
          'payment_method_id': intent['selected_method_id'],
          'consent': true,
          'consent_version': savedCardMethodConsent,
        },
      );
      if (result.status != 200) {
        throw const FormatException('Cambio de tarjeta no confirmado');
      }
      final receipt = savedCardMethodReceipt(result.data);
      if (receipt['key'] != intent['key'] ||
          receipt['action'] != intent['action'] ||
          receipt['card_id'] != intent['selected_method_id']) {
        throw const FormatException('Cambio de tarjeta no confirmado');
      }
      return receipt;
    }
    if (intent['kind'] == 'add_card') {
      final result = await client.functions.invoke(
        'guardian-client',
        body: {
          'action': 'add_card',
          'key': intent['key'],
          'consent': true,
          'consent_version': intent['consent_version'],
        },
      );
      if (result.status != 200) {
        throw const FormatException('Alta no confirmada');
      }
      final receipt = savedCardReceipt(result.data);
      if (receipt['key'] != intent['key'] ||
          (result.data['checkout_url'] != null &&
              (result.data['checkout_url'] is! String ||
                  receipt['status'] != 'pending'))) {
        throw const FormatException('Alta no confirmada');
      }
      return {...receipt, 'checkout_url': result.data['checkout_url']};
    }
    if (intent['kind'] == 'withdraw_amount') {
      return Json.from(
        await client.rpc(
          'dopmi_guardian_withdraw_amount',
          params: {
            'request_id': intent['key'],
            'expected_revision': intent['revision'],
          },
        ),
      );
    }
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
          'action':
              intent['kind'] == 'method' && intent['selected_method_id'] != null
              ? intent['remove_saved'] == true
                    ? 'remove_method'
                    : 'default_method'
              : intent['kind'],
          if (intent['kind'] == 'method' &&
              intent['selected_method_id'] != null)
            'payment_method_id': intent['selected_method_id'],
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

Json savedCardMethodReceipt(Object? value) {
  if (value is! Map) throw const FormatException('Solicitud no confirmada');
  final key = value['key'], action = value['action'], status = value['status'];
  final card = value['card_id'];
  if (key is! String ||
      !RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false,
      ).hasMatch(key) ||
      !['default', 'remove'].contains(action) ||
      ![
        'pending',
        'applied',
        'removed',
        'refused',
        'expired',
        'attention',
      ].contains(status) ||
      (status == 'applied' && action != 'default') ||
      (status == 'removed' && action != 'remove') ||
      card is! String ||
      !RegExp(r'^pm_[A-Za-z0-9]+$').hasMatch(card)) {
    throw const FormatException('Solicitud no confirmada');
  }
  return {'key': key, 'action': action, 'status': status, 'card_id': card};
}

Json savedCardReceipt(Object? value) {
  if (value is! Map ||
      value['key'] is! String ||
      !RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false,
      ).hasMatch(value['key']) ||
      !['pending', 'saved', 'expired', 'attention'].contains(value['status']) ||
      (value['status'] == 'saved'
          ? value['card_id'] is! String ||
                !RegExp(r'^pm_[A-Za-z0-9]+$').hasMatch(value['card_id'])
          : value['card_id'] != null)) {
    throw const FormatException('Alta no confirmada');
  }
  return {
    'key': value['key'],
    'status': value['status'],
    'card_id': value['card_id'],
  };
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
  'pending': 'Actualización pendiente: retoma la misma solicitud para confirmar tu medio de pago.',
  'attention':
      'El cambio de medio de pago está en revisión. Conservamos tu solicitud.',
  'applied': 'Medio de pago actualizado para los próximos ciclos. No se realizó un cobro por este cambio.',
  'expired':
      'La actualización venció sin aplicarse. Puedes autorizar una nueva.',
  'superseded':
      'La actualización se detuvo porque cambió el estado de tu plan.',
};

String? guardianMethodNotice(Json? setup) {
  if (setup == null) return null;
  if (setup['action'] != 'remove') return guardianMethodLabels[setup['status']];
  if (setup['reason'] == 'in_use') {
    return 'No se eliminó la tarjeta porque está en uso. Puedes elegir otra tarjeta predeterminada antes de volver a intentar.';
  }
  return switch (setup['status']) {
    'pending' => 'Eliminación pendiente: retoma la misma solicitud para confirmar el resultado.',
    'attention' => 'La eliminación está en revisión. Conservamos tu solicitud.',
    'applied' => 'Tarjeta eliminada.',
    'expired' =>
      'La eliminación venció sin aplicarse. Puedes autorizar una nueva.',
    'superseded' =>
      'La eliminación se detuvo porque cambió el estado de tu plan.',
    _ => 'Eliminación en revisión.',
  };
}

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

const guardianReviewLabels = {
  'near_anniversary': 'El cambio llegó cerca del aniversario y aún no se aplicó. No se preparan nuevos cobros mientras se revisa; un ciclo ya preparado conserva su importe.',
  'period_review': 'Estamos comprobando qué importe corresponde al aniversario. No se preparan nuevos cobros hasta confirmar el resultado.',
  'retry_limit': 'El cambio necesita revisión después de varios intentos. No se preparan nuevos cobros hasta resolverlo.',
  'processor_review': 'El cambio sigue en conciliación con Stripe. No se preparan nuevos cobros hasta confirmar el resultado.',
};
