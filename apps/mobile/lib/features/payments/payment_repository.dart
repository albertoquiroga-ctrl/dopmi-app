import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../adoption/community_repository.dart';
import 'payment_environment.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>(
  (ref) => PaymentRepository(
    Supabase.instance.client,
    paymentEnvironment: ref.watch(paymentEnvironmentProvider),
  ),
);

class PaymentRepository {
  PaymentRepository(
    this.client, {
    this.paymentEnvironment = const PaymentEnvironment(),
  });
  final SupabaseClient client;
  final PaymentEnvironment paymentEnvironment;
  Future<Json> funding(String expense) async => Json.from(
    await client.rpc('dopmi_expense_funding', params: {'record_id': expense}),
  );
  Future<Json> action(String action, [Json fields = const {}]) async {
    final result = await client.functions.invoke(
      'payments',
      body: {'action': action, ...fields},
    );
    return Json.from(result.data as Map);
  }

  Future<Json> checkout(String expense, int cents, String key) =>
      action('native_checkout', {
        'expense_id': expense,
        'gross_cents': cents,
        'key': key,
        'consent': true,
        'consent_version': paymentEnvironment.oneoffConsentVersion,
      });
  Future<Json> caseCheckout(String caseId, int cents, String key) =>
      action('native_case_checkout', {
        'case_id': caseId,
        'gross_cents': cents,
        'key': key,
        'consent': true,
        'consent_version': paymentEnvironment.oneoffConsentVersion,
      });

  Future<List<Json>> caseAllocations(String donationId) async =>
      (await client.rpc(
        'dopmi_case_payment_allocations',
        params: {'target_donation': donationId},
      ) as List).map((value) => Json.from(value as Map)).toList();
  Future<List<Json>> caseReceivedAllocations(String donationId) async =>
      (await client.rpc(
        'dopmi_case_received_allocations',
        params: {'target_donation': donationId},
      ) as List).map((value) => Json.from(value as Map)).toList();

  Future<Json> ownCaseAttempt(String donationId, String key) async {
    final owner = client.auth.currentUser?.id;
    if (owner == null) {
      throw const FormatException(
        'Inicia sesión para consultar tu aportación.',
      );
    }
    final row = await client
        .from('dopmi_donations')
        .select()
        .eq('donor_id', owner)
        .eq('id', donationId)
        .eq('idempotency_key', key)
        .eq('contribution_scope', 'case')
        .maybeSingle();
    if (client.auth.currentUser?.id != owner ||
        row == null ||
        row['case_id'] is! String) {
      throw const FormatException(
        'No pudimos consultar esa aportación desde tu cuenta.',
      );
    }
    return Json.from(row);
  }

  Future<DataPage<Json>> history(int page, {bool received = false}) async {
    final result = await client
        .from('dopmi_donations')
        .select()
        .eq(received ? 'rescuer_id' : 'donor_id', client.auth.currentUser!.id)
        .order('created_at', ascending: false)
        .order('id')
        .range((page - 1) * 20, page * 20 - 1)
        .count(CountOption.exact);
    return DataPage(result.data.map(Json.from).toList(), result.count);
  }

  Future<Json?> outcome(String expense, String key) =>
      _outcome(expense: expense, key: key);
  Future<Json?> caseOutcome(String caseId, String key) =>
      _outcome(caseId: caseId, key: key);

  Future<Json?> _outcome({
    String? expense,
    String? caseId,
    required String key,
  }) async {
    final actor = client.auth.currentUser?.id;
    if (actor == null) {
      throw const FormatException(
        'Inicia sesión para consultar tu aportación.',
      );
    }
    Future<Json?> readOwned() async {
      var query = client
          .from('dopmi_donations')
          .select()
          .eq('donor_id', actor)
          .eq('idempotency_key', key);
      query = caseId == null
          ? query.eq('expense_id', expense!)
          : query.eq('case_id', caseId).eq('contribution_scope', 'case');
      final row = await query.maybeSingle();
      if (client.auth.currentUser?.id != actor) {
        throw const FormatException(
          'La sesión cambió. Consulta desde tu cuenta.',
        );
      }
      if (row == null) return null;
      final result = Json.from(row);
      if (caseId != null &&
          ['confirmed', 'refunded'].contains(result['payment_status'])) {
        result['case_allocations'] = await caseAllocations(
          result['id'] as String,
        );
        if (client.auth.currentUser?.id != actor) {
          throw const FormatException(
            'La sesión cambió. Consulta desde tu cuenta.',
          );
        }
      }
      return result;
    }

    final before = await readOwned();
    // Historical terminal receipts and absent/forbidden rows remain readable
    // without the new native feature or a provider request.
    if (before == null || before['payment_status'] != 'pending') return before;
    try {
      final state = await client.functions.invoke(
        'payments',
        body: {'action': 'native_status', 'key': key},
      );
      final receipt = state.data is Map ? Json.from(state.data as Map) : null;
      final after = await readOwned();
      if (after == null) return null;
      if (receipt?['donation_id'] != null &&
          receipt!['donation_id'] != after['id']) {
        throw const FormatException('No se pudo confirmar el mismo intento.');
      }
      return {
        ...after,
        if (receipt?['payment_state'] is String)
          'payment_state': receipt!['payment_state'],
      };
    } on FunctionException catch (cause) {
      if (client.auth.currentUser?.id != actor) {
        throw const FormatException(
          'La sesión cambió. Consulta desde tu cuenta.',
        );
      }
      final details = cause.details;
      // A controlled shutdown of new native entries must not hide an existing
      // receipt or turn a pending result into failure/success.
      if (cause.status == 503 &&
          details is Map &&
          details['error'] == 'payments_not_configured') {
        return before;
      }
      rethrow;
    }
  }

  Future<void> openStripe(String value) async {
    final url = Uri.parse(value);
    if (url.scheme != 'https' ||
        !['checkout.stripe.com', 'connect.stripe.com'].contains(url.host)) {
      throw const FormatException('No pudimos validar el enlace de Stripe.');
    }
    if (!await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_self',
    )) {
      throw const FormatException(
        'No pudimos abrir Stripe. Vuelve a intentar.',
      );
    }
  }
}

String paymentError(Object cause) {
  if (cause is FormatException) return cause.message;
  if (cause is FunctionException) {
    final details = cause.details;
    final code = details is Map ? details['error'] : null;
    return switch (code) {
      'payments_not_configured' =>
        'Los pagos todavía no están habilitados. Intenta más tarde.',
      'sign_in_required' =>
        'Inicia sesión con tu cuenta confirmada para continuar.',
      'rescuer_verification_required' =>
        'Completa tu verificación de rescatista para configurar los cobros.',
      'access_denied' => 'Tu cuenta no tiene acceso a esta operación.',
      'stripe_permission_denied' || 'stripe_authentication_failed' => 'La conexión de Dopmi con Stripe necesita revisión del equipo. No vuelvas a pagar.',
      'processor_busy' => 'La aportación sigue en proceso. Actualiza el historial en un momento; no vuelvas a pagar.',
      'manual_reconciliation_required' => 'Este intento necesita revisión del equipo. Consulta tu historial antes de volver a aportar.',
      'payment_unavailable' => 'El gasto o el intento de pago cambió. Actualiza el historial antes de continuar.',
      'payment_consent_required' =>
        'Revisa el importe y las condiciones antes de confirmar tu aportación.',
      'payment_channel_mismatch' => 'Conservamos tu intento original. Consulta su resultado antes de continuar.',
      _ => 'No pudimos consultar Stripe. Conservamos tu intento; puedes volver a intentar.',
    };
  }
  return 'No pudimos actualizar la información. Revisa tu conexión e intenta de nuevo.';
}

const paymentLabels = {
  'pending': 'Pendiente de confirmación',
  'confirmed': 'Pago confirmado',
  'canceled': 'Cancelado sin cobro',
  'refunded': 'Devuelto',
};
const transferLabels = {
  'not_started': 'Sin transferencia',
  'pending': 'Transferencia en proceso',
  'transferred': 'Transferido a la cuenta Stripe',
  'attention': 'Transferencia en revisión',
  'reversed': 'Transferencia revertida',
};

enum ContributionOutcome {
  processing,
  confirmed,
  canceled,
  refundPending,
  refundReconciling,
  refunded,
  refundReview,
}

ContributionOutcome contributionOutcome(Json value) {
  final status = value['payment_status'];
  if (value['contribution_scope'] == 'case') {
    final allocated = (value['allocated_cents'] as num? ?? 0).toInt();
    final refund = value['refund_status'];
    final refundRequested =
        (value['refund_cents'] as num? ?? 0) > 0 ||
        refund == 'pending' ||
        refund == 'refunded' ||
        refund == 'attention' ||
        status == 'refunded' ||
        value['external_refund_pending'] == true ||
        value['transfer_status'] == 'reversed';
    if (refundRequested) {
      if (refund == 'attention' || value['transfer_status'] == 'attention') {
        return ContributionOutcome.refundReview;
      }
      if (value['external_refund_pending'] == true) {
        return ContributionOutcome.refundReconciling;
      }
      if (refund == 'refunded' || status == 'refunded') {
        return allocated == 0 || value['transfer_status'] == 'reversed'
            ? ContributionOutcome.refunded
            : ContributionOutcome.refundReconciling;
      }
      return value['transfer_status'] == 'reversed'
          ? ContributionOutcome.refundReconciling
          : ContributionOutcome.refundPending;
    }
    if (status == 'confirmed' && allocated <= 0) {
      return ContributionOutcome.processing;
    }
  }
  return switch (status) {
    'confirmed' => ContributionOutcome.confirmed,
    'canceled' => ContributionOutcome.canceled,
    'refunded' => ContributionOutcome.refunded,
    _ => ContributionOutcome.processing,
  };
}
