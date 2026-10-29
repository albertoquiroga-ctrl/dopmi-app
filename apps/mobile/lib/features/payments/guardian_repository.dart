import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../adoption/community_repository.dart';
import 'payment_repository.dart';
import 'guardian_payment_card.dart';
import 'guardian_registration.dart';
import 'payment_environment.dart';

const guardianConsent = 'guardian-2026-09-24';
const guardianRegistrationConsent = 'guardian-registration-2026-10-14';
const savedCardConsent = 'saved-cards-2026-10-03';
const savedCardMethodConsent = 'saved-card-methods-2026-10-03';
final guardianEnabledProvider = Provider<bool>(
  (ref) => ref.watch(paymentEnvironmentProvider).guardianEnabled,
);
final guardianRepositoryProvider = Provider<GuardianRepository>(
  (ref) => GuardianRepository(Supabase.instance.client),
);

class GuardianRepository {
  GuardianRepository(this.client);
  final SupabaseClient client;
  Future<Json> submitRegistration(Json draft) async {
    final result = await client.functions.invoke(
      'guardian-client',
      body: {
        'action': 'register',
        'key': draft['key'],
        'gross_cents': draft['gross_cents'],
        'consent': draft['consent'],
        'consent_version': guardianRegistrationConsent,
        'method_consent': draft['method_consent'],
        'method_consent_version': savedCardConsent,
      },
    );
    final data = result.data;
    if (result.status != 200 ||
        data is! Map ||
        data['key'] != draft['key'] ||
        data['gross_cents'] != draft['gross_cents'] ||
        data['id'] is! String ||
        ![
          'method_pending',
          'registered',
          'canceled',
        ].contains(data['status'])) {
      throw const FormatException('Registro no confirmado');
    }
    final url = data['checkout_url'];
    final secret = data['setup_client_secret'];
    final methodStatus = data['method_status'];
    if (methodStatus != null &&
        ![
          'pending',
          'saved',
          'expired',
          'attention',
          'requires_payment_method',
          'requires_confirmation',
          'requires_action',
          'processing',
          'succeeded',
          'canceled',
        ].contains(methodStatus)) {
      throw const FormatException('Método no confirmado');
    }
    if (secret != null &&
        (secret is! String ||
            RegExp(r'^seti_[A-Za-z0-9]+_secret_[A-Za-z0-9]+$')
                    .stringMatch(secret) !=
                secret ||
            data['status'] != 'method_pending' ||
            url != null ||
            ![
              'requires_payment_method',
              'requires_confirmation',
              'requires_action',
            ].contains(methodStatus))) {
      throw const FormatException('Método no confirmado');
    }
    if (url != null &&
        (url is! String ||
            data['status'] != 'method_pending' ||
            Uri.tryParse(url)?.scheme != 'https' ||
            Uri.tryParse(url)?.host != 'checkout.stripe.com')) {
      throw const FormatException('Método no confirmado');
    }
    return {
      'id': data['id'],
      'key': data['key'],
      'status': data['status'],
      'gross_cents': data['gross_cents'],
      'checkout_url': url,
      'setup_client_secret': secret,
      'method_status': methodStatus,
    };
  }

  Future<void> cancelRegistration(String id) async {
    final result = await client.functions.invoke(
      'guardian-client',
      body: {'action': 'registration_cancel', 'id': id},
    );
    if (result.status != 200) {
      throw const FormatException('Cancelación no confirmada');
    }
  }

  Future<Json> submitRegistrationMethod(Json draft) =>
      _registrationMethod('registration_method', draft);
  Future<Json> registrationMethodStatus(Json draft) =>
      _registrationMethod('registration_method_status', draft);
  Future<Json> _registrationMethod(String action, Json draft) async {
    final uuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (draft['id'] is! String ||
        !uuid.hasMatch(draft['id']) ||
        draft['key'] is! String ||
        !uuid.hasMatch(draft['key']) ||
        draft['revision'] is! int ||
        draft['revision'] < 0 ||
        draft['consent'] != true ||
        draft['consent_version'] != savedCardConsent) {
      throw const FormatException(
        'Revisa la autorización del cambio de tarjeta.',
      );
    }
    final owner = client.auth.currentUser?.id;
    final token = client.auth.currentSession?.accessToken;
    if (owner == null) {
      throw const FormatException(
        'Inicia sesión para consultar el cambio de tarjeta.',
      );
    }
    final result = await client.functions.invoke(
      'guardian-client',
      body: {
        'action': action,
        'id': draft['id'],
        'key': draft['key'],
        if (action == 'registration_method') ...{
          'revision': draft['revision'],
          'consent': true,
          'consent_version': savedCardConsent,
        },
      },
    );
    if (client.auth.currentUser?.id != owner ||
        client.auth.currentSession?.accessToken != token) {
      throw const FormatException(
        'La sesión cambió. Consulta desde tu cuenta.',
      );
    }
    final data = result.data;
    if (result.status != 200 ||
        data is! Map ||
        data['id'] != draft['id'] ||
        data['key'] != draft['key'] ||
        ![
          'pending',
          'applied',
          'expired',
          'canceled',
        ].contains(data['status']) ||
        data['registration_revision'] !=
            (draft['revision'] as int) +
                (data['status'] == 'applied' ? 1 : 0) ||
        data['checkout_url'] != null) {
      throw const FormatException(
        'El cambio de tarjeta no está confirmado. Consulta la misma solicitud.',
      );
    }
    final secret = data['setup_client_secret'];
    if (secret != null &&
        (data['status'] != 'pending' ||
            secret is! String ||
            !RegExp(r'^seti_[A-Za-z0-9]+_secret_[A-Za-z0-9]+$')
                .hasMatch(secret) ||
            ![
              'requires_payment_method',
              'requires_confirmation',
              'requires_action',
            ].contains(data['method_status']))) {
      throw const FormatException('El cambio de tarjeta no está confirmado.');
    }
    return {
      'id': data['id'],
      'key': data['key'],
      'status': data['status'],
      'registration_revision': data['registration_revision'],
      'method_status': data['method_status'],
      'setup_client_secret': secret,
      'checkout_url': null,
    };
  }

  Future<void> changeRegistrationAmount(
    GuardianRegistration registration,
    int cents,
  ) async {
    final result = await client.functions.invoke(
      'guardian-client',
      body: {
        'action': 'registration_amount',
        'id': registration.id,
        'revision': registration.revision,
        'gross_cents': cents,
        'consent': true,
        'consent_version': guardianRegistrationConsent,
      },
    );
    if (result.status != 200) {
      throw const FormatException('Cambio no confirmado');
    }
  }

  Future<Object?> registrationBankAction(
    String registrationId,
    String attemptId,
  ) async {
    final result = await client.functions.invoke(
      'guardian-client',
      body: {
        'action': 'registration_action',
        'id': registrationId,
        'attempt_id': attemptId,
      },
    );
    if (result.status != 200) {
      throw const FormatException('La acción bancaria no está disponible.');
    }
    // Transient SDK response; do not place it in persisted payment intents.
    return result.data;
  }

  Future<Json> membershipState() async {
    final legacy = await state();
    if (legacy['plan'] != null || legacy['activation'] != null) return legacy;
    return {...legacy, 'registration': await registrationState()};
  }

  // Read-only projection for legal-consent access. Unlike registrationState,
  // this must not reconcile a pending SetupIntent or prepare any payment.
  Future<GuardianRegistration?> registrationSnapshot() async {
    final owner = client.auth.currentUser?.id;
    final token = client.auth.currentSession?.accessToken;
    if (owner == null || token == null) {
      throw const FormatException('Inicia sesión para consultar Guardián.');
    }
    final result = await client.rpc(
      'dopmi_guardian_registration_cancellation_state',
    );
    if (client.auth.currentUser?.id != owner ||
        client.auth.currentSession?.accessToken != token) {
      throw const FormatException(
        'La sesión cambió. Consulta desde tu cuenta.',
      );
    }
    if (result == null) return null;
    if (result is! Map) throw const FormatException('Registro no confirmado');
    return GuardianRegistration.fromJson(Map<String, dynamic>.from(result));
  }

  Future<GuardianRegistration?> registrationState() async {
    var result = await client.rpc('dopmi_guardian_registration_state');
    if (result == null) return null;
    if (result is! Map) {
      throw const FormatException('Registro no confirmado');
    }
    final registration = GuardianRegistration.fromJson(
      Map<String, dynamic>.from(result),
    );
    if (registration.status == 'method_pending') {
      final response = await client.functions.invoke(
        'guardian-client',
        body: {'action': 'registration_status', 'id': registration.id},
      );
      final data = response.data;
      if (response.status != 200 ||
          data is! Map ||
          data['id'] != registration.id ||
          ![
            'method_pending',
            'registered',
            'canceled',
          ].contains(data['status'])) {
        throw const FormatException('Registro no confirmado');
      }
      // The SDK never confirms this state. Reconcile the owned SetupIntent on
      // the server, then read the complete owner-filtered projection again.
      final refreshed = await client.rpc<dynamic>(
        'dopmi_guardian_registration_state',
      );
      if (refreshed is! Map || refreshed['id'] != registration.id) {
        throw const FormatException('Registro no confirmado');
      }
      result = refreshed;
    }
    return GuardianRegistration.fromJson(Map<String, dynamic>.from(result));
  }

  Future<Json?> savedCardMethodState() async {
    final result = await client.rpc('dopmi_saved_card_method_state');
    return result == null ? null : savedCardMethodReceipt(result);
  }

  Future<Json?> savedCardState() async {
    final result = await client.rpc('dopmi_saved_card_state');
    return result == null ? null : savedCardReceipt(result);
  }

  Future<Json?> nativeSavedCardStatus(String key) async {
    final result = await client.functions.invoke(
      'guardian-client',
      body: {'action': 'native_add_card_status', 'key': key},
    );
    if (result.status != 200) throw const FormatException('Alta no confirmada');
    return result.data == null
        ? null
        : nativeSavedCardReceipt(result.data, key);
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
      if (intent['presentation'] == 'native_card') {
        if (intent['consent_version'] != savedCardConsent) {
          throw const FormatException('Solicitud de tarjeta incompleta');
        }
        final result = await client.functions.invoke(
          'guardian-client',
          body: {
            'action': 'native_add_card',
            'key': intent['key'],
            'consent': true,
            'consent_version': savedCardConsent,
          },
        );
        if (result.status != 200) {
          throw const FormatException('Alta no confirmada');
        }
        return nativeSavedCardReceipt(result.data, intent['key'] as String);
      }
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
          : value['card_id'] != null) ||
      (value['presentation'] != null &&
          (![
                'native_card',
                'hosted_checkout',
              ].contains(value['presentation']) ||
              value['add_only'] != true ||
              value['default_unchanged'] != true))) {
    throw const FormatException('Alta no confirmada');
  }
  return {
    'key': value['key'],
    'status': value['status'],
    'card_id': value['card_id'],
    if (value['presentation'] != null) ...{
      'presentation': value['presentation'],
      'add_only': true,
      'default_unchanged': true,
    },
  };
}

Json nativeSavedCardReceipt(Object? value, String key) {
  final receipt = savedCardReceipt(value);
  final data = value as Map;
  final presentation = receipt['presentation'];
  final secret = data['setup_client_secret'];
  final checkout = data['checkout_url'];
  if (receipt['key'] != key ||
      !['native_card', 'hosted_checkout'].contains(presentation) ||
      receipt['add_only'] != true ||
      receipt['default_unchanged'] != true ||
      (secret != null &&
          (presentation != 'native_card' ||
              receipt['status'] != 'pending' ||
              secret is! String ||
              !RegExp(r'^seti_[A-Za-z0-9]+_secret_[A-Za-z0-9]+$')
                  .hasMatch(secret) ||
              ![
                'requires_payment_method',
                'requires_confirmation',
                'requires_action',
              ].contains(data['method_status']))) ||
      (checkout != null &&
          (presentation != 'hosted_checkout' ||
              receipt['status'] != 'pending' ||
              checkout is! String))) {
    throw const FormatException('Alta no confirmada');
  }
  return {
    ...receipt,
    'method_status': data['method_status'],
    'setup_client_secret': secret,
    'checkout_url': checkout,
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
