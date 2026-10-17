enum GuardianRegistrationPaymentState {
  notEvaluated,
  prepared,
  skipped,
  expired,
  processing,
  requiresAction,
  processorConfirmed,
  allocated,
  refundPending,
  refunded,
  canceled,
}

const _paymentStates = {
  'not_evaluated': GuardianRegistrationPaymentState.notEvaluated,
  'prepared': GuardianRegistrationPaymentState.prepared,
  'skipped': GuardianRegistrationPaymentState.skipped,
  'expired': GuardianRegistrationPaymentState.expired,
  'processing': GuardianRegistrationPaymentState.processing,
  'requires_action': GuardianRegistrationPaymentState.requiresAction,
  'processor_confirmed': GuardianRegistrationPaymentState.processorConfirmed,
  'allocated': GuardianRegistrationPaymentState.allocated,
  'refund_pending': GuardianRegistrationPaymentState.refundPending,
  'refunded': GuardianRegistrationPaymentState.refunded,
  'canceled': GuardianRegistrationPaymentState.canceled,
};

// Owner projection only. Never retain a processor secret or infer impact from
// method setup, registration, browser return, timeout or processor success.
class GuardianRegistration {
  const GuardianRegistration({
    required this.id,
    required this.key,
    required this.status,
    required this.grossCents,
    required this.revision,
    required this.registeredAt,
    required this.nextEvaluationAt,
    required this.paymentState,
    required this.attemptId,
    required this.allocatedCents,
    required this.refundCents,
    required this.evaluationStatus,
    required this.evaluationCycle,
    this.methodStatus,
    this.methodChange,
  });

  final String id;
  final String key;
  final String status;
  final int grossCents;
  final int revision;
  final String? methodStatus;
  final GuardianRegistrationMethodChange? methodChange;
  final DateTime registeredAt;
  final DateTime? nextEvaluationAt;
  final GuardianRegistrationPaymentState paymentState;
  final String? attemptId;
  final int allocatedCents;
  final int refundCents;
  final String? evaluationStatus;
  final int? evaluationCycle;

  bool get hasConfirmedImpact =>
      paymentState == GuardianRegistrationPaymentState.allocated &&
      allocatedCents > 0;

  String get summary {
    if (paymentState == GuardianRegistrationPaymentState.requiresAction) {
      return 'Tu banco necesita una acción. Consulta el mismo intento.';
    }
    if (paymentState == GuardianRegistrationPaymentState.processing ||
        paymentState == GuardianRegistrationPaymentState.processorConfirmed ||
        paymentState == GuardianRegistrationPaymentState.prepared) {
      return 'En proceso. Consulta el resultado confirmado por el servidor.';
    }
    if (paymentState == GuardianRegistrationPaymentState.refundPending) {
      return 'Devolución en proceso. Consulta su estado.';
    }
    if (status == 'canceled') {
      return 'Registro cancelado. Consulta tus movimientos pendientes.';
    }
    if (status == 'method_pending') {
      return 'Falta preparar tu método. Aún no se confirma una aportación.';
    }
    if (evaluationStatus == 'skipped' ||
        paymentState == GuardianRegistrationPaymentState.skipped ||
        paymentState == GuardianRegistrationPaymentState.expired) {
      return 'Este mes no se realizó un cargo. Sin deuda ni recobro; se evaluará el siguiente mes.';
    }
    if (hasConfirmedImpact) {
      return 'Aportación asignada. Consulta tu impacto y próximos ciclos.';
    }
    if (paymentState == GuardianRegistrationPaymentState.canceled) {
      return 'Este intento terminó sin cobro. Revisa tu método y consulta el próximo ciclo.';
    }
    if (paymentState == GuardianRegistrationPaymentState.refunded) {
      return 'Devolución confirmada. Consulta el próximo ciclo.';
    }
    return 'Registro preparado. El cobro depende de capacidad completa en la evaluación mensual.';
  }

  factory GuardianRegistration.fromJson(Map<String, dynamic> data) {
    Never invalid() => throw const FormatException('Registro no confirmado');
    final uuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    bool identity(dynamic value) => value is String && uuid.hasMatch(value);
    final payment = data['payment'];
    final status = data['status'];
    final gross = data['gross_cents'];
    final revision = data['revision'];
    final methodStatus = data['method_status'];
    if (methodStatus != null &&
        !['saved', 'unavailable'].contains(methodStatus)) {
      invalid();
    }
    final methodChange = data['method_change'] == null
        ? null
        : GuardianRegistrationMethodChange.fromJson(
            Map<String, dynamic>.from(data['method_change'] as Map),
          );
    final registered = DateTime.tryParse(
      data['registered_at']?.toString() ?? '',
    );
    final next = DateTime.tryParse(
      data['next_evaluation_at']?.toString() ?? '',
    );
    if (!identity(data['id']) ||
        !identity(data['key']) ||
        !['method_pending', 'registered', 'canceled'].contains(status) ||
        data['consent_version'] != 'guardian-registration-2026-10-14' ||
        gross is! int ||
        gross < 2000 ||
        gross > 1000000 ||
        revision is! int ||
        revision < 0 ||
        registered == null ||
        (status == 'canceled'
            ? data['next_evaluation_at'] != null
            : next == null) ||
        payment is! Map) {
      invalid();
    }
    final state = _paymentStates[payment['state']];
    final attempt = payment['attempt_id'];
    final allocated = payment['allocated_cents'];
    final refund = payment['refund_cents'];
    final evaluation = data['evaluation'];
    if (evaluation != null &&
        (evaluation is! Map ||
            ![
              'reserved',
              'skipped',
              'expired',
              'canceled',
            ].contains(evaluation['status']) ||
            evaluation['cycle_number'] is! int ||
            evaluation['cycle_number'] < 0 ||
            evaluation['cycle_number'] > 1199)) {
      invalid();
    }
    if (state == null ||
        (attempt != null && !identity(attempt)) ||
        allocated is! int ||
        allocated < 0 ||
        refund is! int ||
        refund < 0 ||
        (state == GuardianRegistrationPaymentState.allocated &&
            (attempt == null || allocated == 0 || refund != 0))) {
      invalid();
    }
    return GuardianRegistration(
      id: data['id'],
      key: data['key'],
      status: status,
      grossCents: gross,
      revision: revision,
      registeredAt: registered.toUtc(),
      nextEvaluationAt: next?.toUtc(),
      paymentState: state,
      attemptId: attempt,
      allocatedCents: allocated,
      refundCents: refund,
      evaluationStatus: evaluation?['status'],
      evaluationCycle: evaluation?['cycle_number'],
      methodStatus: methodStatus as String?,
      methodChange: methodChange,
    );
  }
}

class GuardianRegistrationMethodChange {
  const GuardianRegistrationMethodChange({
    required this.key,
    required this.status,
    required this.revision,
  });
  final String key, status;
  final int revision;
  factory GuardianRegistrationMethodChange.fromJson(Map<String, dynamic> data) {
    final key = data['key'],
        status = data['status'],
        revision = data['revision'];
    if (key is! String ||
        !RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(key) ||
        !['pending', 'applied', 'expired', 'canceled'].contains(status) ||
        revision is! int ||
        revision < 0) {
      throw const FormatException('Cambio de tarjeta no confirmado');
    }
    return GuardianRegistrationMethodChange(
      key: key,
      status: status as String,
      revision: revision,
    );
  }
}
