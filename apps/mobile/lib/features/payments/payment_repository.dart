import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../adoption/community_repository.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>(
  (ref) => PaymentRepository(Supabase.instance.client),
);

class PaymentRepository {
  PaymentRepository(this.client);
  final SupabaseClient client;
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

  Future<Json> checkout(String expense, int cents, String key) => action(
    'checkout',
    {'expense_id': expense, 'gross_cents': cents, 'key': key},
  );
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
        'Los pagos de prueba todavía no están habilitados. Intenta más tarde.',
      'sign_in_required' =>
        'Inicia sesión con tu cuenta confirmada para continuar.',
      'rescuer_verification_required' =>
        'Completa tu verificación de rescatista para configurar los cobros.',
      'access_denied' => 'Tu cuenta no tiene acceso a esta operación.',
      'stripe_permission_denied' || 'stripe_authentication_failed' => 'La conexión de Dopmi con Stripe necesita revisión del equipo. No vuelvas a pagar.',
      'processor_busy' => 'La aportación sigue en proceso. Actualiza el historial en un momento; no vuelvas a pagar.',
      'manual_reconciliation_required' => 'Este intento necesita revisión del equipo. Consulta tu historial antes de volver a aportar.',
      'payment_unavailable' => 'El gasto o el intento de pago cambió. Actualiza el historial antes de continuar.',
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
