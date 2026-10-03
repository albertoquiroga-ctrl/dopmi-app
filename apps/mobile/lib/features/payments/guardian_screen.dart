import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/ui.dart';
import '../../core/measurement.dart';
import '../adoption/community_repository.dart';
import '../identity/identity_controller.dart';
import '../rescue/rescue_repository.dart';
import 'guardian_repository.dart';
import 'guardian_payment_card.dart';
import 'payment_method_border.dart';
import 'contribution_layout.dart';
import 'guardian_membership_card.dart';
import 'guardian_cancel_dialog.dart';
import 'guardian_amount_dialog.dart';
import 'guardian_history_screen.dart';
import 'guardian_enrollment_amount.dart';
import 'guardian_enrollment_confirmation.dart';
import 'guardian_activation_success.dart';
import 'guardian_activation_failure.dart';

class GuardianScreen extends ConsumerStatefulWidget {
  const GuardianScreen({
    super.key,
    this.initialEnrollment = false,
    this.paymentMethodsOnly = false,
  });
  final bool paymentMethodsOnly;
  final bool initialEnrollment;
  @override
  ConsumerState<GuardianScreen> createState() => _GuardianState();
}

class _GuardianState extends ConsumerState<GuardianScreen>
    with WidgetsBindingObserver {
  final amount = TextEditingController(text: '50');
  final enrollmentInput = GlobalKey();
  bool enrolling = false;
  Json? data, intent;
  List<GuardianPaymentCard>? cards;
  String? cardsError;
  bool busy = true, consent = false, fresh = false, confirming = false;
  String? error, message;
  String? confirmedActivationKey;
  int? confirmedActivationCents;
  String? failedActivationKey;
  int? failedActivationCents;
  late final String owner;
  String get storageKey => 'dopmi-guardian:$owner:intent';
  bool get current =>
      mounted && ref.read(identityControllerProvider).identity?.id == owner;
  Json? get plan => data?['plan'] is Map ? Json.from(data!['plan']) : null;
  Json? get activation =>
      data?['activation'] is Map ? Json.from(data!['activation']) : null;
  Json? get methodSetup =>
      data?['method_setup'] is Map ? Json.from(data!['method_setup']) : null;
  bool get checkoutInReview =>
      intent?['kind'] == 'checkout' && activation?['status'] == 'attention';
  String? get paymentIssueMessage {
    final issue = data?['payment_issue'];
    if (issue is! Map ||
        ![
          'authentication_required',
          'payment_failed',
        ].contains(issue['reason'])) {
      return null;
    }
    return issue['status'] == 'skipped'
        ? 'El último ciclo se omitió por rechazo o autenticación bancaria pendiente. No se volverá a cobrar ese ciclo. Puedes actualizar y autenticar tu medio para los próximos.'
        : 'Un pago necesita revisión bancaria y sigue en conciliación. Espera su resultado antes de cambiar el medio de pago.';
  }

  Future<void> trackOnce(String name, Object? attempt) async {
    if (attempt is! String || attempt.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = '$storageKey:measurement:$name:$attempt';
    if (prefs.getBool(key) == true) return;
    await ref.read(measurementControllerProvider)?.event(name);
    await prefs.setBool(key, true);
  }

  @override
  void initState() {
    super.initState();
    owner = ref.read(identityControllerProvider).identity!.id;
    enrolling = widget.initialEnrollment;
    WidgetsBinding.instance.addObserver(this);
    if (ref.read(guardianEnabledProvider)) {
      load(restore: true);
    } else {
      busy = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !busy &&
        !confirming &&
        ref.read(guardianEnabledProvider)) {
      load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    amount.dispose();
    super.dispose();
  }

  Future<void> load({bool restore = false}) async {
    if (!current) return;
    setState(() {
      busy = true;
      error = null;
      fresh = false;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      if (restore) {
        final saved = prefs.getString(storageKey);
        if (saved != null) {
          try {
            final value = Json.from(jsonDecode(saved));
            if (![
                  'checkout',
                  'amount',
                  'cancel',
                  'cancel_activation',
                  'method',
                  'withdraw_amount',
                ].contains(value['kind']) ||
                value['key'] is! String ||
                (['checkout', 'amount'].contains(value['kind']) &&
                    (value['cents'] is! int ||
                        value['consent_version'] != guardianConsent)) ||
                (value['kind'] == 'method' &&
                    value['consent_version'] != guardianConsent) ||
                ([
                      'amount',
                      'cancel',
                      'method',
                      'withdraw_amount',
                    ].contains(value['kind']) &&
                    value['revision'] is! int)) {
              throw const FormatException('Intento incompleto');
            }
            intent = value;
          } catch (_) {
            message =
                'Consultamos el estado del servidor para recuperar tu plan.';
          }
        }
      }
      if (!current) return;
      final result = await ref.read(guardianRepositoryProvider).state();
      if (!current) return;
      data = result;
      if (intent?['kind'] == 'checkout' &&
          plan == null &&
          activation?['status'] == 'failed' &&
          activation?['key'] == intent?['key'] &&
          activation?['gross_cents'] == intent?['cents']) {
        failedActivationKey = intent!['key'] as String;
        failedActivationCents = intent!['cents'] as int;
      }
      if (intent?['kind'] == 'checkout' &&
          plan?['status'] == 'active' &&
          activation?['status'] == 'active' &&
          activation?['key'] == intent?['key'] &&
          activation?['gross_cents'] == intent?['cents'] &&
          plan?['gross_cents'] == intent?['cents']) {
        confirmedActivationKey = intent!['key'] as String;
        confirmedActivationCents = intent!['cents'] as int;
      }
      if (intent?['kind'] == 'checkout' &&
          (plan != null ||
              activation?['status'] == 'funded_pending_schedule')) {
        await trackOnce('contribution_confirmed', intent?['key']);
      }
      if (plan?['status'] == 'canceled' ||
          activation?['cancellation_status'] == 'stopped') {
        message = null;
      }
      if (intent?['kind'] == 'method' &&
          (['canceled', 'cancel_requested'].contains(plan?['status']) ||
              (methodSetup?['key'] == intent?['key'] &&
                  [
                    'applied',
                    'expired',
                    'superseded',
                  ].contains(methodSetup?['status'])))) {
        await prefs.remove(storageKey);
        intent = null;
      }
      if (intent == null &&
          plan?['status'] == 'active' &&
          ['pending', 'attention'].contains(methodSetup?['status'])) {
        intent = {
          'kind': 'method',
          'key': methodSetup!['key'],
          'revision': methodSetup!['revision'],
          'consent_version': guardianConsent,
        };
        if (!await prefs.setString(storageKey, jsonEncode(intent))) {
          throw const FormatException('No se pudo conservar el intento.');
        }
      }
      if (intent?['kind'] == 'withdraw_amount' &&
          (plan?['requests'] as List? ?? []).any(
            (request) =>
                request['id'] == intent?['key'] &&
                [
                  'withdrawn',
                  'superseded',
                  'applied',
                ].contains(request['status']),
          )) {
        await prefs.remove(storageKey);
        intent = null;
      }
      // Only authoritative terminal state releases an initial payment attempt.
      if (intent?['kind'] == 'checkout' &&
          (plan != null ||
              activation?['cancellation_requested_at'] != null ||
              (activation?['key'] == intent?['key'] &&
                  [
                    'no_capacity',
                    'expired',
                    'failed',
                    'refunded',
                  ].contains(activation?['status'])))) {
        await prefs.remove(storageKey);
        intent = null;
      }
      if (plan == null &&
          intent == null &&
          activation?['cancellation_requested_at'] == null &&
          activation?['status'] == 'pending' &&
          activation?['consent_version'] == guardianConsent) {
        intent = {
          'kind': 'checkout',
          'key': activation!['key'],
          'cents': activation!['gross_cents'],
          'consent_version': guardianConsent,
        };
        if (!await prefs.setString(storageKey, jsonEncode(intent))) {
          throw const FormatException('No se pudo conservar el intento.');
        }
      }
      if (!current) return;
      if (restore || intent != null) {
        final cents =
            intent?['cents'] ??
            plan?['gross_cents'] ??
            failedActivationCents ??
            5000;
        amount.text = ((cents as int) / 100).toStringAsFixed(2);
      }
      fresh = true;
      if (widget.paymentMethodsOnly &&
          ref.read(identityControllerProvider).identity?.verified == true) {
        cardsError = null;
        cards = null;
        try {
          final result = await ref
              .read(guardianRepositoryProvider)
              .paymentMethods();
          if (!current) return;
          cards = result;
        } catch (_) {
          if (current) cardsError = 'No se pudieron consultar tus tarjetas. Actualiza el estado para reintentar.';
        }
      }
    } catch (cause) {
      if (current) error = guardianError(cause);
    } finally {
      if (current) setState(() => busy = false);
    }
  }

  void beginEnrollment() {
    if (!current ||
        busy ||
        confirming ||
        !fresh ||
        intent != null ||
        plan != null) {
      return;
    }
    setState(() {
      failedActivationKey = null;
      enrolling = true;
      consent = false;
    });
  }

  Future<void> changeAmount() async {
    if (!current ||
        busy ||
        confirming ||
        !fresh ||
        intent != null ||
        plan?['status'] != 'active' ||
        plan?['pending_request'] != null) {
      return;
    }
    setState(() => confirming = true);
    final selected = await chooseGuardianAmount(
      context,
      plan!['gross_cents'] as int,
      identity: ref.read(identityControllerProvider),
      canView: () => current,
    );
    if (!current) return;
    setState(() => confirming = false);
    if (selected == null) return;
    setState(() {
      amount.text = (selected / 100).toStringAsFixed(2);
      consent = true;
    });
    await submit();
  }

  Future<void> submit({
    bool cancel = false,
    bool method = false,
    bool withdraw = false,
    GuardianPaymentCard? selectedCard,
  }) async {
    if (busy || confirming || !fresh || !current) return;
    if (!cancel && !method && !withdraw && checkoutInReview) return;
    if (selectedCard != null &&
        (!method ||
            intent != null ||
            plan?['status'] != 'active' ||
            data?['method_change_available'] != true ||
            !(cards ?? []).any(
              (card) => card.id == selectedCard.id && !card.isDefault,
            ))) {
      return;
    }
    if (cancel || method || withdraw) {
      setState(() => confirming = true);
      final agreed = cancel
          ? await confirmGuardianCancellation(context)
          : await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(
                  withdraw
                      ? '¿Retirar el cambio de monto?'
                      : method
                      ? selectedCard == null
                            ? '¿Actualizar tu medio de pago?'
                            : '¿Usar esta tarjeta como predeterminada?'
                      : '¿Cancelar tu plan Guardián?',
                ),
                content: Text(
                  withdraw
                      ? 'Mantendrás el importe anterior de tu plan: ${pesos(plan!['gross_cents'] as int)} al mes. Lo retiraremos si aún no comenzó a aplicarse; los próximos ciclos podrán continuar con el importe anterior. Esta acción no cancela tu plan.'
                      : method
                      ? selectedCard == null
                            ? 'Autorizo guardar y usar el nuevo medio en Stripe para los próximos ciclos de Guardián, con el monto y las condiciones vigentes. Stripe puede solicitar autenticación bancaria. Este cambio no cobra ni recupera ciclos omitidos.'
                            : 'Autorizo usar ${selectedCard.brandLabel} •••• ${selectedCard.last4} como medio predeterminado para los próximos ciclos de Guardián, con el monto y las condiciones vigentes. Este cambio no cobra ni recupera ciclos omitidos.'
                      : 'Detendremos los ciclos futuros. Un pago ya iniciado puede terminar de procesarse. Los pagos anteriores conservan su historial y no se devuelven automáticamente.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      method || withdraw ? 'Volver' : 'Conservar plan',
                    ),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(
                      withdraw
                          ? 'Retirar y conservar monto'
                          : method
                          ? 'Autorizar y continuar'
                          : 'Confirmar cancelación',
                    ),
                  ),
                ],
              ),
            );
      if (!current) return;
      setState(() => confirming = false);
      if (agreed != true) return;
    }
    final cents = parsePesos(amount.text);
    if (!cancel &&
        !method &&
        !withdraw &&
        intent == null &&
        (!consent || cents == null || cents < 5000 || cents > 1000000)) {
      setState(
        () => error = 'Elige un importe de \$50 a \$10,000 MXN, con hasta dos decimales, y confirma la autorización.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
      message = null;
    });
    try {
      final repo = ref.read(guardianRepositoryProvider);
      if (intent == null &&
          !cancel &&
          plan == null &&
          !await repo.capacity(cents!)) {
        if (current) {
          setState(
            () => message = 'Por ahora no hay gastos aprobados suficientes para asignar tu aportación completa. No se abrió un pago ni se activó un plan.',
          );
        }
        return;
      }
      if (!current) return;
      final next = withdraw
          ? <String, dynamic>{
              'kind': 'withdraw_amount',
              'key': plan!['pending_request']['id'],
              'revision': plan!['revision'],
            }
          : cancel
          ? <String, dynamic>{
              'kind': plan == null ? 'cancel_activation' : 'cancel',
              'key': plan == null ? activation!['key'] : const Uuid().v4(),
              'revision': plan?['revision'],
            }
          : intent ??
                <String, dynamic>{
                  'kind': method
                      ? 'method'
                      : (plan == null ? 'checkout' : 'amount'),
                  'key': const Uuid().v4(),
                  'cents': cents,
                  'revision': plan?['revision'],
                  if (selectedCard != null)
                    'selected_method_id': selectedCard.id,
                };
      if (intent == null && !cancel && !withdraw) {
        next['consent_version'] = guardianConsent;
      }
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(storageKey, jsonEncode(next))) {
        throw const FormatException('No se pudo conservar el intento.');
      }
      if (!current) return;
      setState(() => intent = next);
      final result = await repo.submit(next);
      if (next['kind'] == 'checkout') {
        await trackOnce('contribution_started', next['key']);
      }
      if (!current) return;
      if (!['checkout', 'method'].contains(next['kind'])) {
        await prefs.remove(storageKey);
        if (!current) return;
        intent = null;
        consent = false;
        // load() displays the authoritative request status, including withdrawal.
        message = null;
      } else if (result['checkout_url'] is String) {
        await repo.openCheckout(result['checkout_url'] as String);
      } else {
        message = next['kind'] == 'method'
            ? guardianMethodLabels[result['status']] ??
                  'Actualización en revisión.'
            : guardianActivationLabels[result['status']] ??
                  'El alta sigue en revisión. No vuelvas a pagar.';
      }
      if (current) await load();
    } catch (cause) {
      if (current && intent?['kind'] != 'checkout' && guardianRejected(cause)) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(storageKey);
        if (!current) return;
        intent = null;
        consent = false;
        await load();
      }
      if (current) setState(() => error = guardianError(cause));
    } finally {
      if (current) setState(() => busy = false);
    }
  }

  String date(Object? value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return 'por confirmar';
    final local = parsed.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(guardianEnabledProvider);
    if (!widget.paymentMethodsOnly &&
        enabled &&
        current &&
        fresh &&
        !busy &&
        !confirming &&
        plan == null &&
        intent == null &&
        failedActivationKey != null &&
        activation?['key'] == failedActivationKey &&
        activation?['gross_cents'] == failedActivationCents &&
        activation?['status'] == 'failed' &&
        activation?['cancellation_requested_at'] == null) {
      return GuardianActivationFailure(
        cents: failedActivationCents!,
        onRetry: beginEnrollment,
        onReturn: () => context.go('/rescue-cases'),
      );
    }
    if (!widget.paymentMethodsOnly &&
        enabled &&
        current &&
        fresh &&
        !busy &&
        confirmedActivationKey != null &&
        activation?['key'] == confirmedActivationKey &&
        activation?['gross_cents'] == confirmedActivationCents &&
        plan?['gross_cents'] == confirmedActivationCents &&
        activation?['status'] == 'active' &&
        plan?['status'] == 'active') {
      return GuardianActivationSuccess(
        cents: plan!['gross_cents'] as int,
        nextBilling: plan!['next_billing_at'] as String?,
        onReturn: () => context.go('/rescue-cases'),
      );
    }
    final p = plan;
    final pending = p?['pending_request'];
    final status = p?['status'];
    final canStart =
        p == null &&
        activation?['cancellation_requested_at'] == null &&
        (activation == null ||
            [
              'no_capacity',
              'expired',
              'failed',
              'refunded',
            ].contains(activation?['status']));
    final canChange =
        status == 'active' &&
        pending == null &&
        !['pending', 'attention'].contains(methodSetup?['status']);
    final canCancel =
        status == 'active' ||
        (p == null &&
            activation != null &&
            activation?['cancellation_requested_at'] == null &&
            [
              'pending',
              'funded_pending_schedule',
              'attention',
            ].contains(activation?['status']));
    final verified =
        ref.watch(identityControllerProvider).identity?.verified == true;
    final canSubmit =
        !busy &&
        !confirming &&
        fresh &&
        !checkoutInReview &&
        (intent != null || (verified && consent && (canStart || canChange)));
    if (widget.paymentMethodsOnly) {
      return ContributionFrame(
        title: 'Métodos de pago',
        back: () => context.canPop() ? context.pop() : context.go('/settings'),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            const Text(
              'Tarjetas guardadas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
            const SizedBox(height: 12),
            if (enabled && cardsError != null) Notice(cardsError!),
            if (enabled && cards != null && cards!.isNotEmpty)
              for (var i = 0; i < cards!.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                GuardianPaymentCardRow(
                  card: cards![i],
                  showMakeDefault: verified && status == 'active',
                  onMakeDefault:
                      busy ||
                          confirming ||
                          !fresh ||
                          intent != null ||
                          data?['method_change_available'] != true
                      ? null
                      : () => submit(method: true, selectedCard: cards![i]),
                ),
              ],
            if (cards == null || cards!.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xffe6e2dd)),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xffefede8),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/profile/icon-card.svg',
                          width: 18,
                          height: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        !enabled
                            ? 'Guardián no está disponible en esta versión.'
                            : error != null && !fresh
                            ? 'No se pudo confirmar tu medio de pago.'
                            : busy && data == null
                            ? 'Consultando tu suscripción…'
                            : status == 'active'
                            ? 'Gestionado en Stripe'
                            : 'No tienes una suscripción activa de Guardián.',
                      ),
                    ),
                  ],
                ),
              ),
            if (enabled && paymentIssueMessage != null)
              Notice(paymentIssueMessage!),
            if (error != null) Notice(error!),
            if (message != null) Notice(message!),
            if (enabled &&
                methodSetup != null &&
                message != guardianMethodLabels[methodSetup!['status']])
              Notice(
                guardianMethodLabels[methodSetup!['status']] ??
                    'Medio de pago en revisión.',
              ),
            const SizedBox(height: 12),
            if (enabled &&
                verified &&
                status == 'active' &&
                data?['method_change_available'] == true &&
                intent == null)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: ink,
                  minimumSize: const Size.fromHeight(56),
                  side: const BorderSide(color: Color(0xffd5cfc6)),
                  textStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  shape: const PaymentMethodBorder(),
                ),
                onPressed: busy || confirming || !fresh
                    ? null
                    : () => submit(method: true),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Actualizar medio de pago'),
              ),
            if (enabled && intent?['kind'] == 'method')
              ActionButton(
                intent?['selected_method_id'] == null
                    ? 'Continuar actualización'
                    : 'Reintentar cambio de tarjeta',
                busy: busy,
                onPressed: canSubmit ? () => submit() : null,
              ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: ink),
              onPressed: busy || confirming ? null : () => load(),
              child: const Text('Actualizar estado'),
            ),
            if (enabled)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: ink),
                onPressed: () => context.push('/guardian'),
                child: const Text('Ver mi suscripción de Guardián'),
              ),
          ],
        ),
      );
    }
    final showForm =
        !['method', 'withdraw_amount'].contains(intent?['kind']) &&
        !checkoutInReview &&
        ((canStart && enrolling) || intent != null);
    final enrollmentWidgets = <Widget>[
      GuardianEnrollmentAmount(
        headingKey: enrollmentInput,
        amount: amount,
        locked: busy || intent != null,
        onChanged: () => setState(() => consent = false),
      ),
      const SizedBox(height: 16),
      if (p == null)
        GuardianEnrollmentConfirmation(
          firstPaymentDate: date(DateTime.now().toIso8601String()),
          nextBillingDate: date(
            guardianNextBilling(DateTime.now()).toIso8601String(),
          ),
          consent: consent,
          restored: intent != null,
          onConsentChanged: busy
              ? null
              : (value) => setState(() => consent = value ?? false),
        )
      else ...[
        const Notice(
          'El nuevo importe aplica desde el siguiente ciclo. No se prorratea ni cambia el importe de un ciclo ya preparado.',
        ),
        if (intent == null)
          CheckboxListTile(
            value: consent,
            onChanged: busy
                ? null
                : (value) => setState(() => consent = value ?? false),
            title: const Text(
              'Autorizo el nuevo importe mensual desde el siguiente ciclo.',
            ),
          ),
      ],
      const SizedBox(height: 16),
      if (intent != null)
        const Notice(
          'Conservamos tu solicitud. Reintentar usa la misma referencia y el mismo importe.',
        ),
      ContributionButton(
        intent == null
            ? (p == null ? 'Activar en Stripe' : 'Solicitar cambio de monto')
            : 'Reintentar mi solicitud',
        busy: busy,
        onPressed: canSubmit ? () => submit() : null,
      ),
    ];
    if (enabled &&
        p == null &&
        enrolling &&
        showForm &&
        (fresh || data != null)) {
      void returnToBilling() {
        if (busy || confirming) return;
        if (widget.initialEnrollment && intent == null) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/rescue-cases');
          }
          return;
        }
        setState(() {
          enrolling = false;
          consent = false;
        });
      }

      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) returnToBilling();
        },
        child: ContributionFrame(
          title: '',
          back: busy || confirming ? null : returnToBilling,
          child: SingleChildScrollView(
            key: const ValueKey('guardian-enrollment-scroll'),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...enrollmentWidgets,
                const SizedBox(height: 16),
                if (busy) const LinearProgressIndicator(),
                if (error != null) Notice(error!, isError: true),
                if (message != null) Notice(message!),
                TextButton(
                  onPressed: busy || confirming ? null : () => load(),
                  child: const Text('Actualizar estado'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return ContributionFrame(
      title: 'Suscripción y pagos',
      back: () => context.canPop() ? context.pop() : context.go('/settings'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            const Text(
              'Suscripción Dopmi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            if (enabled && fresh && p == null && canStart && intent == null)
              GuardianInactiveCard(
                onSubscribe: busy || confirming ? null : beginEnrollment,
              ),
            if (enabled && p != null)
              GuardianMembershipCard(
                status: status,
                cents: p['gross_cents'] as int,
                nextBilling: p['next_billing_at'],
              ),
            if (enabled && canChange && intent == null)
              ContributionButton(
                'Cambiar cantidad',
                onPressed: busy || confirming || !fresh || !verified
                    ? null
                    : changeAmount,
              ),
            if (enabled && canCancel)
              ContributionButton(
                'Cancelar suscripción',
                secondary: true,
                onPressed: busy || confirming || !fresh
                    ? null
                    : () => submit(cancel: true),
              ),
            if (enabled && fresh) ...[
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Historial de pagos',
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              GuardianHistoryPreview(key: ValueKey(owner), owner: owner),
            ],
            if (!enabled)
              const Notice(
                'Guardián todavía no está disponible. Te avisaremos cuando puedas activar tu plan.',
              ),
            if (enabled) ...[
              TextButton(
                onPressed: () => context.push('/guardian/history'),
                child: const Text('Ver historial de ciclos'),
              ),
              if (p != null)
                TextButton.icon(
                  onPressed: () => context.push('/impact'),
                  icon: const Icon(Icons.auto_stories_outlined),
                  label: const Text('Ver mi impacto'),
                ),
              if (methodSetup != null && status == 'active')
                Notice(
                  guardianMethodLabels[methodSetup!['status']] ??
                      'Medio de pago en revisión.',
                ),
              if (paymentIssueMessage != null) Notice(paymentIssueMessage!),
              if (verified &&
                  status == 'active' &&
                  data?['method_change_available'] == true &&
                  intent == null)
                TextButton(
                  onPressed: busy || confirming || !fresh
                      ? null
                      : () => submit(method: true),
                  child: const Text('Actualizar medio de pago'),
                ),
              if (pending is Map && pending['review_reason'] != null)
                Notice(
                  guardianReviewLabels[pending['review_reason']] ??
                      'El cambio está en revisión.',
                ),
              if (pending is Map &&
                  pending['can_withdraw'] == true &&
                  intent == null)
                TextButton(
                  onPressed: busy || confirming || !fresh
                      ? null
                      : () => submit(withdraw: true),
                  child: const Text('Retirar cambio de monto'),
                ),
              if (intent?['kind'] == 'withdraw_amount')
                ActionButton(
                  'Reintentar retiro del cambio',
                  busy: busy,
                  onPressed: canSubmit ? () => submit() : null,
                ),
              if (intent?['kind'] == 'method')
                ActionButton(
                  intent?['selected_method_id'] == null
                      ? 'Continuar actualización'
                      : 'Reintentar cambio de tarjeta',
                  busy: busy,
                  onPressed: canSubmit ? () => submit() : null,
                ),
              if (activation?['cancellation_requested_at'] != null)
                Notice(switch (activation?['cancellation_status']) {
                  'stopped' => 'Alta detenida. Consulta abajo el estado del primer pago; detener el alta no confirma una devolución.',
                  'attention' =>
                    'Cancelación del alta en revisión. No inicies otro pago.',
                  _ => 'Cancelación del alta solicitada. Estamos confirmando el cierre con Stripe; un pago ya iniciado sigue en conciliación.',
                }),
              const Notice(
                'Solo modo de prueba. No uses datos de una tarjeta real.',
              ),
              if (busy) const LinearProgressIndicator(),
              if (p != null) ...[
                Text(switch (status) {
                  'active' => 'Plan activo',
                  'cancel_requested' =>
                    'Cancelación solicitada: futuros cobros detenidos',
                  'canceled' => 'Plan cancelado',
                  _ => 'Estado por confirmar',
                }, style: Theme.of(context).textTheme.titleLarge),
                Text(
                  'Monto autorizado: ${pesos(p['gross_cents'] as int)} al mes',
                ),
                if (pending is Map)
                  Notice(
                    pending['kind'] == 'cancel'
                        ? 'Estamos confirmando la cancelación con Stripe.'
                        : 'Cambio a ${pesos(pending['new_gross_cents'] as int)} solicitado. El importe anterior se conserva hasta confirmar la aplicación.',
                  ),
                if (p['payment_in_flight'] == true)
                  const Notice(
                    'Hay un pago previamente iniciado en conciliación. Cancelar no confirma su devolución.',
                  ),
                for (final r in p['requests'] as List? ?? [])
                  ListTile(
                    title: Text(
                      r['kind'] == 'cancel'
                          ? 'Cancelación'
                          : 'Cambio a ${pesos(r['new_gross_cents'] as int)}',
                    ),
                    subtitle: Text(switch (r['status']) {
                      'applied' =>
                        r['kind'] == 'amount'
                            ? 'Confirmado. Aplica desde ${date(r['effective_at'])}.'
                            : 'Cancelación confirmada.',
                      'superseded' => 'Sustituido por cancelación.',
                      'withdrawn' =>
                        'Solicitud retirada; se conservó el monto anterior.',
                      _ => 'Pendiente de confirmación.',
                    }),
                  ),
              ] else if (activation != null)
                Notice(
                  guardianActivationLabels[activation!['status']] ??
                      'Estado del alta en revisión. No vuelvas a pagar.',
                ),
              const Notice(
                'Solo se cobra si el neto completo puede asignarse a gastos aprobados. Si no hay capacidad, ese mes se omite sin cargo ni deuda. Dopmi descuenta el 2% y los costos de Stripe; el neto se asigna por prioridad. Puedes cancelar los ciclos futuros.',
              ),
              if (showForm) ...enrollmentWidgets,
              if (error != null) Notice(error!, isError: true),
              if (message != null) Notice(message!),
              TextButton(
                onPressed: busy || confirming ? null : () => load(),
                child: const Text('Actualizar estado'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
