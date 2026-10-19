import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/ui.dart';
import '../identity/identity_controller.dart';
import '../rescue/rescue_repository.dart';
import 'contribution_layout.dart';
import 'guardian_bank_action.dart';
import 'guardian_enrollment_amount.dart';
import 'guardian_method_setup.dart';
import 'guardian_registration.dart';
import 'guardian_repository.dart';
import 'guardian_history_screen.dart';
import 'payment_repository.dart';

class GuardianRegistrationScreen extends ConsumerStatefulWidget {
  const GuardianRegistrationScreen({
    super.key,
    required this.owner,
    this.onBack,
  });
  final String owner;
  final VoidCallback? onBack;
  @override
  ConsumerState<GuardianRegistrationScreen> createState() =>
      _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<GuardianRegistrationScreen>
    with WidgetsBindingObserver {
  final amount = TextEditingController(text: '50');
  final contentScroll = ScrollController();
  GuardianRegistration? registration;
  Map<String, dynamic>? draft;
  bool bankAwaiting = false;
  bool methodAwaiting = false;
  bool busy = true,
      fresh = false,
      consent = false,
      methodConsent = false,
      editing = false;
  String? error;
  String get storageKey => 'dopmi-guardian-registration:${widget.owner}:intent';
  bool get current =>
      mounted &&
      ref.read(identityControllerProvider).identity?.id == widget.owner;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load(restore: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    amount.dispose();
    contentScroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        (!busy || bankAwaiting || methodAwaiting) &&
        current) {
      load();
    }
  }

  Future<void> load({bool restore = false}) async {
    if (!current) return;
    setState(() {
      busy = true;
      fresh = false;
      error = null;
    });
    try {
      if (restore) {
        final raw = (await SharedPreferences.getInstance()).getString(
          storageKey,
        );
        if (!current) return;
        if (raw != null) {
          final saved = jsonDecode(raw);
          if (saved is! Map ||
              saved['key'] is! String ||
              !RegExp(
                r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
              ).hasMatch(saved['key']) ||
              saved['gross_cents'] is! int ||
              saved['gross_cents'] < 2000 ||
              saved['gross_cents'] > 1000000 ||
              saved['consent'] != true ||
              saved['method_consent'] != true ||
              saved['consent_version'] != guardianRegistrationConsent ||
              saved['method_consent_version'] != savedCardConsent ||
              saved.keys.any(
                (key) => ![
                  'key',
                  'gross_cents',
                  'consent',
                  'consent_version',
                  'method_consent',
                  'method_consent_version',
                ].contains(key),
              )) {
            throw const FormatException('Solicitud pendiente no confirmada');
          }
          draft = Map<String, dynamic>.from(saved);
          amount.text = (draft!['gross_cents'] / 100).toStringAsFixed(2);
          consent = true;
          methodConsent = true;
        }
      }
      final state = await ref
          .read(guardianRepositoryProvider)
          .registrationState();
      if (!current) return;
      final previousCanceled =
          state?.status == 'canceled' &&
          draft != null &&
          state!.key != draft!['key'];
      registration = previousCanceled ? null : state;
      if (state != null &&
          state.status != 'method_pending' &&
          (draft == null || state.key == draft!['key'])) {
        await (await SharedPreferences.getInstance()).remove(storageKey);
        if (!current) return;
        draft = null;
      }
      if (state != null && !editing && !previousCanceled) {
        amount.text = (state.grossCents / 100).toStringAsFixed(2);
      }
      fresh = true;
    } catch (_) {
      if (current) error = 'No se pudo confirmar el estado. Consulta de nuevo antes de continuar.';
    } finally {
      if (current) setState(() => busy = false);
    }
  }

  Future<void> submit() async {
    final owner = widget.owner;
    bool currentSubmission() => current && widget.owner == owner;
    final cents = parsePesos(amount.text);
    if (!current ||
        busy ||
        methodAwaiting ||
        !fresh ||
        !consent ||
        cents == null ||
        cents < 2000 ||
        cents > 1000000) {
      return;
    }
    if (!editing && !methodConsent) return;
    if (!editing &&
        registration == null &&
        draft == null &&
        !ref.read(guardianMethodSetupProvider).available) {
      setState(() {
        error = 'El método de pago no está disponible en este dispositivo. No iniciamos un registro nuevo.';
      });
      return;
    }
    setState(() {
      busy = true;
      fresh = false;
      error = null;
    });
    String? methodNotice;
    try {
      final repo = ref.read(guardianRepositoryProvider);
      if (editing && registration != null) {
        await repo.changeRegistrationAmount(registration!, cents);
        if (!current) return;
        editing = false;
      } else {
        draft ??= {
          'key': registration?.key ?? const Uuid().v4(),
          'gross_cents': cents,
          'consent': true,
          'consent_version': guardianRegistrationConsent,
          'method_consent': true,
          'method_consent_version': savedCardConsent,
        };
        final saved = await (await SharedPreferences.getInstance()).setString(
          storageKey,
          jsonEncode(draft),
        );
        if (!saved) {
          throw const FormatException('No se pudo conservar la solicitud');
        }
        if (!current) return;
        final receipt = await repo.submitRegistration(draft!);
        if (!current) return;
        final secret = receipt['setup_client_secret'];
        final url = receipt['checkout_url'];
        if (secret is String) {
          final setup = ref.read(guardianMethodSetupProvider);
          if (!setup.available) {
            methodNotice = 'El método de pago no está disponible en este dispositivo. Conservamos la misma solicitud; puedes consultar su estado o cancelar el registro pendiente.';
          } else {
            setState(() => methodAwaiting = true);
            try {
              await setup.present(
                secret,
                current: () =>
                    currentSubmission() &&
                    (ModalRoute.of(context)?.isCurrent ?? false),
              );
            } catch (_) {
              // Closing the sheet or losing its response is not a payment failure.
              // No SDK result or secret is persisted; reconcile the same key.
              methodNotice = 'La preparación del método quedó pendiente. Conservamos la misma solicitud; consulta su estado antes de continuar.';
            } finally {
              if (current) setState(() => methodAwaiting = false);
            }
          }
        } else if (url is String) {
          await ref.read(paymentRepositoryProvider).openStripe(url);
        }
        if (!current) return;
      }
      await load();
      if (current &&
          fresh &&
          methodNotice != null &&
          (registration == null || registration?.status == 'method_pending')) {
        setState(() => error = methodNotice);
        if (contentScroll.hasClients) {
          await contentScroll.animateTo(
            contentScroll.position.minScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      }
    } catch (_) {
      if (current) {
        setState(() {
          error = 'En proceso. Conservamos tu solicitud; consulta su estado antes de reintentar.';
          busy = false;
        });
      }
    }
  }

  Future<void> cancel() async {
    if (!current || busy || methodAwaiting || !fresh || registration == null) {
      return;
    }
    setState(() {
      busy = true;
      fresh = false;
      error = null;
    });
    try {
      await ref
          .read(guardianRepositoryProvider)
          .cancelRegistration(registration!.id);
      if (current) await load();
    } catch (_) {
      if (current) {
        setState(() {
          busy = false;
          error =
              'Cancelación en proceso. Consulta el estado para confirmarla.';
        });
      }
    }
  }

  Future<void> bank() async {
    if (!current ||
        busy ||
        bankAwaiting ||
        methodAwaiting ||
        !fresh ||
        registration == null) {
      return;
    }
    setState(() {
      busy = true;
      fresh = false;
      error = null;
      bankAwaiting = true;
    });
    try {
      await ref.read(guardianBankActionProvider).run(registration!);
      if (current) await load();
    } catch (_) {
      if (current) {
        setState(() {
          busy = false;
          error = 'El estado sigue sin confirmar. Consulta de nuevo; no iniciamos otro intento.';
        });
      }
    } finally {
      if (current) setState(() => bankAwaiting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = registration;
    final form = state == null || state.status == 'method_pending' || editing;
    final methodReady = ref.watch(guardianMethodSetupProvider).available;
    final cents = parsePesos(amount.text);
    final valid =
        !busy &&
        !methodAwaiting &&
        fresh &&
        consent &&
        (editing || methodConsent) &&
        (editing || state != null || draft != null || methodReady) &&
        cents != null &&
        cents >= 2000 &&
        cents <= 1000000;
    final status = switch (state?.paymentState) {
      GuardianRegistrationPaymentState.processing ||
      GuardianRegistrationPaymentState.prepared => 'En proceso',
      GuardianRegistrationPaymentState.requiresAction =>
        'Tu banco necesita tu autorización',
      GuardianRegistrationPaymentState.processorConfirmed =>
        'En proceso de asignación',
      GuardianRegistrationPaymentState.allocated => 'Aportación asignada',
      GuardianRegistrationPaymentState.refundPending => 'Devolución en proceso',
      GuardianRegistrationPaymentState.refunded => 'Aportación devuelta',
      GuardianRegistrationPaymentState.canceled => 'Intento cancelado',
      GuardianRegistrationPaymentState.skipped ||
      GuardianRegistrationPaymentState.expired =>
        'Este mes no se realizó un cargo',
      _ =>
        state?.status == 'method_pending'
            ? 'Prepara tu método de pago'
            : 'Registro Guardián',
    };
    void leave() {
      if (busy || methodAwaiting) return;
      if (widget.onBack != null) {
        widget.onBack!();
      } else if (context.canPop()) {
        context.pop();
      } else {
        context.go('/rescue-cases');
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) leave();
      },
      child: ContributionFrame(
        title: state == null ? 'Guardián' : 'Suscripción y pagos',
        back: leave,
        bottomNavigationBar: form
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ContributionButton(
                    editing
                        ? 'Guardar monto'
                        : draft != null
                        ? 'Continuar registro'
                        : 'Registrar y preparar método',
                    dark: true,
                    busy: busy || methodAwaiting,
                    onPressed: valid ? submit : null,
                  ),
                ),
              )
            : null,
        child: ListView(
          key: const Key('guardian-registration-content'),
          controller: contentScroll,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            if (state != null) ...[
              const Text(
                'Suscripción Guardián',
                style: TextStyle(
                  fontSize: 20,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (busy) const LinearProgressIndicator(),
            if (busy)
              Semantics(liveRegion: true, child: const Text('En proceso…')),
            if (error != null) Notice(error!),
            if (form &&
                !editing &&
                state == null &&
                draft == null &&
                !methodReady)
              const Notice(
                'El método de pago no está disponible en este dispositivo. No iniciamos un registro nuevo.',
              ),
            if (form) ...[
              if (state?.status == 'method_pending')
                const Notice(
                  'Registro pendiente: falta confirmar tu método de pago. Prepararlo no genera un cargo. Conservamos la misma solicitud.',
                ),
              GuardianEnrollmentAmount(
                registrationOnly: true,
                amount: amount,
                locked:
                    busy || draft != null || state?.status == 'method_pending',
                decorate: true,
                onChanged: () => setState(() {
                  consent = false;
                  methodConsent = false;
                }),
              ),
              const SizedBox(height: 16),
              const Text(
                'Puedes registrarte aunque no haya gastos disponibles. Preparar tu método no genera un cargo.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Con capacidad suficiente se intenta la primera aportación hoy. Sin capacidad, no se cobra y se evalúa el siguiente mes, sin deuda ni recobro. Sólo se aporta cuando puede asignarse todo el neto.',
              ),
              CheckboxListTile(
                key: const Key('registration-consent'),
                contentPadding: EdgeInsets.zero,
                value: consent,
                onChanged: busy
                    ? null
                    : (value) => setState(() => consent = value ?? false),
                title: Text(
                  editing
                      ? 'Autorizo este monto desde el siguiente ciclo, sin cambiar ciclos ya preparados.'
                      : 'Autorizo este monto mensual, su evaluación por aniversario y la cancelación de ciclos futuros.',
                ),
              ),
              if (!editing)
                CheckboxListTile(
                  key: const Key('method-consent'),
                  contentPadding: EdgeInsets.zero,
                  value: methodConsent,
                  onChanged: busy
                      ? null
                      : (value) =>
                            setState(() => methodConsent = value ?? false),
                  title: const Text(
                    'Autorizo guardar mi método de pago de forma segura en Stripe para estas aportaciones.',
                  ),
                ),
              if (state?.status == 'method_pending')
                TextButton(
                  onPressed: busy || methodAwaiting || !fresh ? null : cancel,
                  child: const Text('Cancelar registro pendiente'),
                ),
            ] else ...[
              Container(
                key: const ValueKey('guardian-registration-membership-card'),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xffe6e2dd)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xffefede8),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                state.status == 'canceled'
                                    ? 'Registro cancelado'
                                    : status,
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.3,
                                  fontWeight: FontWeight.w600,
                                  color: muted,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const CircleAvatar(
                          backgroundColor: Color(0xfffff2b8),
                          foregroundColor: ink,
                          child: Icon(Icons.star_border),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Monto mensual',
                      style: TextStyle(fontSize: 13, height: 1.3, color: muted),
                    ),
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: contributionMoney(state.grossCents)
                                .replaceFirst(' MXN', ''),
                          ),
                          const TextSpan(
                            text: ' MXN / mes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                      key: const ValueKey(
                        'guardian-registration-monthly-amount',
                      ),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 30,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Color(0xffe6e2dd)),
                    Text(
                      state.summary,
                      style: const TextStyle(
                        color: muted,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                    if (state.nextEvaluationAt != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Próxima evaluación: ${state.nextEvaluationAt!.toIso8601String().substring(0, 10)} (UTC).',
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (state.evaluationStatus == 'skipped')
                const Notice(
                  'Este ciclo se omitió. No genera deuda ni se cobrará después.',
                ),
              if (state.hasConfirmedImpact)
                Text(
                  'Neto asignado: ${contributionMoney(state.allocatedCents)}',
                ),
              if (state.status == 'canceled' &&
                  [
                    GuardianRegistrationPaymentState.processing,
                    GuardianRegistrationPaymentState.processorConfirmed,
                  ].contains(state.paymentState))
                const Notice(
                  'Cancelaste los ciclos futuros. El intento anterior sigue en conciliación; espera su resultado.',
                ),
              if (state.paymentState ==
                  GuardianRegistrationPaymentState.requiresAction) ...[
                const Notice(
                  'Continúa la autorización de tu banco. Sólo está disponible mientras la reserva siga vigente. Regresar o cerrar no confirma el resultado.',
                ),
                ContributionButton(
                  'Autorizar con mi banco',
                  busy: busy,
                  onPressed:
                      !busy &&
                          !bankAwaiting &&
                          fresh &&
                          state.status == 'registered' &&
                          ref.watch(guardianBankSdkProvider).available
                      ? bank
                      : null,
                ),
              ],
              if (state.status == 'registered') ...[
                ContributionButton(
                  'Cambiar cantidad',
                  dark: true,
                  onPressed: busy || !fresh
                      ? null
                      : () => setState(() {
                          editing = true;
                          consent = false;
                        }),
                ),
                const SizedBox(height: 12),
                ContributionButton(
                  'Cancelar ciclos futuros',
                  secondary: true,
                  onPressed: busy || !fresh ? null : cancel,
                ),
              ],
              if (state.status == 'canceled')
                ContributionButton(
                  'Ver mi impacto',
                  secondary: true,
                  onPressed: busy || !fresh
                      ? null
                      : () => context.push('/impact?history=1'),
                ),
              if (state.status == 'canceled' &&
                  [
                    GuardianRegistrationPaymentState.notEvaluated,
                    GuardianRegistrationPaymentState.skipped,
                    GuardianRegistrationPaymentState.expired,
                    GuardianRegistrationPaymentState.canceled,
                    GuardianRegistrationPaymentState.allocated,
                    GuardianRegistrationPaymentState.refunded,
                  ].contains(state.paymentState))
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ContributionButton(
                    'Volver a registrarme',
                    dark: true,
                    onPressed: busy || methodAwaiting || !fresh
                        ? null
                        : () => setState(() {
                            registration = null;
                            consent = false;
                            methodConsent = false;
                            error = null;
                          }),
                  ),
                ),
            ],
            if (state != null && !editing) ...[
              const SizedBox(height: 28),
              const Text(
                'Historial de pagos',
                style: TextStyle(
                  fontSize: 20,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
              const SizedBox(height: 12),
              GuardianHistoryPreview(owner: widget.owner),
              TextButton.icon(
                onPressed: busy
                    ? null
                    : () => context.push('/guardian/history'),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Ver historial de pagos'),
              ),
            ],
            const SizedBox(height: 12),
            TextButton(
              onPressed: busy && !bankAwaiting && !methodAwaiting ? null : load,
              child: const Text('Consultar estado'),
            ),
          ],
        ),
      ),
    );
  }
}
