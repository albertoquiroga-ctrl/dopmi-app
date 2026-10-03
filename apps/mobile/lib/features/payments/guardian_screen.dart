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
import 'payment_methods_feedback.dart';
import 'saved_card_confirmation.dart';
import 'payment_method_border.dart';
import 'native_wallet_buttons.dart';
import 'native_wallet_sdk.dart';
import 'native_wallet_repository.dart';
import 'native_wallet_intent_store.dart';
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
  Json? pendingMethodsFeedback;
  Json? savedCardIntent, savedCardStatus;
  String? pendingSavedFeedback, savedCardError;
  bool savedCardFresh = false;
  Json? walletIntent, walletStatus;
  String? walletProvider, walletError;
  Json? independentIntent, independentStatus;
  bool independentFresh = false;
  String? independentError;
  String get independentStorageKey => 'dopmi-saved-card-method:$owner:intent';
  String? methodsFeedback, methodsFeedbackKey;
  bool feedbackIsRemoval = false;
  final shownMethodsFeedback = <String>{};
  bool busy = true, consent = false, fresh = false, confirming = false;
  String? error, message;
  String? confirmedActivationKey;
  int? confirmedActivationCents;
  String? failedActivationKey;
  int? failedActivationCents;
  late final String owner;
  String get storageKey => 'dopmi-guardian:$owner:intent';
  String get savedCardStorageKey => 'dopmi-saved-card:$owner:intent';
  bool get current =>
      mounted && ref.read(identityControllerProvider).identity?.id == owner;
  Json? get plan => data?['plan'] is Map ? Json.from(data!['plan']) : null;
  Json? get activation =>
      data?['activation'] is Map ? Json.from(data!['activation']) : null;
  Json? get methodSetup =>
      data?['method_setup'] is Map ? Json.from(data!['method_setup']) : null;
  String? get methodsNotice =>
      methodSetup?['status'] == 'applied' &&
          ['default', 'remove'].contains(methodSetup?['action'])
      ? null
      : guardianMethodNotice(methodSetup);

  void confirmMethodsFeedback() {
    final pending = pendingMethodsFeedback, setup = methodSetup;
    if (pending == null || setup == null) return;
    if (setup['key'] != pending['key'] ||
        ['expired', 'superseded'].contains(setup['status'])) {
      pendingMethodsFeedback = null;
      return;
    }
    if (setup['status'] != 'applied' ||
        cards == null ||
        cardsError != null ||
        plan?['status'] != 'active' ||
        !['default', 'remove'].contains(setup['action'])) {
      return;
    }
    final removed = setup['action'] == 'remove',
        target = pending['selected_method_id'];
    if (target != null &&
        (removed
            ? cards!.any((card) => card.id == target)
            : !cards!.any((card) => card.id == target && card.isDefault))) {
      return;
    }
    final key = setup['key'];
    pendingMethodsFeedback = null;
    if (key is! String || !shownMethodsFeedback.add(key)) return;
    methodsFeedbackKey = key;
    feedbackIsRemoval = removed;
    methodsFeedback = removed
        ? 'Tarjeta eliminada.'
        : 'Método predeterminado actualizado';
  }

  String get methodRetryLabel => intent?['remove_saved'] == true
      ? 'Reintentar eliminación'
      : intent?['selected_method_id'] == null
      ? 'Continuar actualización'
      : 'Reintentar cambio de tarjeta';
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
      savedCardFresh = false;
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
      if (widget.paymentMethodsOnly && intent?['kind'] == 'method') {
        pendingMethodsFeedback = Json.from(intent!);
      }
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
          if (methodSetup!['action'] == 'remove') 'remove_saved': true,
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
        await loadSavedCard(prefs, restore: restore);
        await loadIndependentMethod(prefs, restore: restore);
        await loadWallet(prefs);
        if (!current) return;
        cardsError = null;
        cards = null;
        try {
          final result = await ref
              .read(guardianRepositoryProvider)
              .paymentMethods();
          if (!current) return;
          cards = result;
          confirmMethodsFeedback();
          await confirmSavedFeedback(prefs);
          await confirmIndependentMethod(prefs);
          await finishWallet(prefs);
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

  Future<void> loadWallet(SharedPreferences prefs) async {
    final sdk = ref.read(nativeWalletSdkProvider);
    if (sdk.provider == null) return;
    walletError = null;
    try {
      walletIntent = NativeWalletIntentStore(prefs, owner).read();
      final state = await ref.read(nativeWalletRepositoryProvider).state();
      if (!current) return;
      walletStatus = state;
      if (walletIntent == null &&
          state != null &&
          ['pending', 'attention'].contains(state['status'])) {
        walletIntent = await NativeWalletIntentStore(prefs, owner).reserve({
          'key': state['key'],
          'wallet_type': state['wallet_type'],
          'consent_version': savedCardConsent,
        });
      }
      final available = await sdk.available();
      if (current) walletProvider = available ? sdk.provider : null;
    } catch (_) {
      if (current) {
        walletError =
            'No pudimos consultar tu billetera. Conservamos tu solicitud.';
      }
    }
  }

  Future<void> finishWallet(SharedPreferences prefs) async {
    if (!current ||
        walletIntent == null ||
        walletStatus == null ||
        walletStatus!['key'] != walletIntent!['key'] ||
        walletStatus!['wallet_type'] != walletIntent!['wallet_type']) {
      return;
    }
    final status = walletStatus!['status'];
    if (status == 'saved' &&
        (cardsError != null ||
            cards == null ||
            !cards!.any((card) => card.id == walletStatus!['card_id']))) {
      return;
    }
    if (!['saved', 'expired'].contains(status)) return;
    await NativeWalletIntentStore(prefs, owner).finish(walletStatus!);
    if (!current) return;
    walletIntent = null;
    if (status == 'saved') {
      methodsFeedbackKey = walletStatus!['key'];
      if (shownMethodsFeedback.add(methodsFeedbackKey!)) {
        feedbackIsRemoval = false;
        methodsFeedback = walletStatus!['wallet_type'] == 'apple_pay'
            ? 'Apple Pay vinculado'
            : 'Google Pay vinculado';
      }
    }
  }

  Future<void> addWallet(String provider) async {
    if (!current ||
        busy ||
        confirming ||
        !fresh ||
        ref.read(identityControllerProvider).identity?.verified != true ||
        intent != null ||
        savedCardIntent != null ||
        independentIntent != null) {
      return;
    }
    if (walletIntent == null) {
      setState(() => confirming = true);
      final agreed = await confirmSavedCard(context);
      if (!current) return;
      setState(() => confirming = false);
      if (!agreed) return;
    }
    setState(() {
      busy = true;
      walletError = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!current) return;
      walletIntent = await NativeWalletIntentStore(prefs, owner).reserve(
        walletIntent ??
            {
              'key': const Uuid().v4(),
              'wallet_type': provider,
              'consent_version': savedCardConsent,
            },
      );
      if (!current) return;
      final repo = ref.read(nativeWalletRepositoryProvider);
      final receipt = await repo.submit(walletIntent!);
      if (!current) return;
      final secret = receipt['setup_client_secret'];
      if (secret is String) {
        await ref
            .read(nativeWalletSdkProvider)
            .authorize(walletIntent!['wallet_type'], secret);
        if (!current) return;
        walletStatus = await repo.submit(walletIntent!);
      } else {
        walletStatus = receipt;
      }
    } catch (_) {
      if (current) walletError = 'La autorización no se confirmó. Puedes retomar la misma solicitud.';
    } finally {
      if (current) {
        setState(() => busy = false);
        await load();
      }
    }
  }

  Future<void> loadSavedCard(
    SharedPreferences prefs, {
    required bool restore,
  }) async {
    savedCardError = null;
    if (restore && prefs.getString(savedCardStorageKey) != null) {
      try {
        final value = Json.from(
          jsonDecode(prefs.getString(savedCardStorageKey)!),
        );
        if (value['kind'] != 'add_card' ||
            value['consent_version'] != savedCardConsent) {
          throw const FormatException('Intento incompleto');
        }
        savedCardReceipt({
          'key': value['key'],
          'status': 'pending',
          'card_id': null,
        });
        savedCardIntent = value;
      } catch (_) {
        savedCardError =
            'Consultamos el servidor para recuperar el alta de tu tarjeta.';
      }
    }
    pendingSavedFeedback ??= savedCardIntent?['key'];
    try {
      final result = await ref
          .read(guardianRepositoryProvider)
          .savedCardState();
      if (!current) return;
      savedCardStatus = result;
      if (result != null &&
          savedCardIntent != null &&
          result['key'] != savedCardIntent!['key']) {
        await prefs.remove(savedCardStorageKey);
        if (!current) return;
        savedCardIntent = null;
        pendingSavedFeedback = null;
      }
      if (savedCardIntent == null &&
          ['pending', 'attention'].contains(result?['status'])) {
        final recovered = <String, dynamic>{
          'kind': 'add_card',
          'key': result!['key'],
          'consent_version': savedCardConsent,
        };
        if (!await prefs.setString(
          savedCardStorageKey,
          jsonEncode(recovered),
        )) {
          throw const FormatException('No se pudo conservar el intento');
        }
        if (!current) return;
        savedCardIntent = recovered;
        pendingSavedFeedback = result['key'];
      }
      if (result?['status'] == 'expired' &&
          result?['key'] == savedCardIntent?['key']) {
        await prefs.remove(savedCardStorageKey);
        if (!current) return;
        savedCardIntent = null;
        pendingSavedFeedback = null;
        savedCardError = 'El alta de tu tarjeta venció sin completarse. Puedes agregarla de nuevo.';
      }
      savedCardFresh = true;
    } catch (_) {
      if (current) savedCardError = 'No pudimos consultar el alta de tu tarjeta. Actualiza el estado o reintenta la misma solicitud.';
    }
  }

  Future<void> confirmSavedFeedback(SharedPreferences prefs) async {
    final result = savedCardStatus;
    if (!savedCardFresh ||
        result?['status'] != 'saved' ||
        pendingSavedFeedback != result?['key'] ||
        !(cards ?? []).any((card) => card.id == result?['card_id'])) {
      return;
    }
    await prefs.remove(savedCardStorageKey);
    if (!current) return;
    savedCardIntent = null;
    pendingSavedFeedback = null;
    final key = result!['key'] as String;
    if (!shownMethodsFeedback.add(key)) return;
    methodsFeedbackKey = key;
    feedbackIsRemoval = false;
    methodsFeedback = 'Tarjeta agregada';
  }

  Future<void> loadIndependentMethod(
    SharedPreferences prefs, {
    required bool restore,
  }) async {
    independentFresh = false;
    independentError = null;
    try {
      if (restore && prefs.getString(independentStorageKey) != null) {
        final value = Json.from(
          jsonDecode(prefs.getString(independentStorageKey)!),
        );
        if (value['kind'] != 'saved_card_method' ||
            value['consent_version'] != savedCardMethodConsent) {
          throw const FormatException('Intento incompleto');
        }
        savedCardMethodReceipt({
          'key': value['key'],
          'action': value['action'],
          'status': 'pending',
          'card_id': value['selected_method_id'],
        });
        independentIntent = value;
      }
      final result = await ref
          .read(guardianRepositoryProvider)
          .savedCardMethodState();
      if (!current) return;
      independentStatus = result;
      if (result != null &&
          independentIntent != null &&
          result['key'] != independentIntent!['key']) {
        await prefs.remove(independentStorageKey);
        independentIntent = null;
      }
      if (independentIntent == null &&
          ['pending', 'attention'].contains(result?['status'])) {
        final recovered = <String, dynamic>{
          'kind': 'saved_card_method',
          'key': result!['key'],
          'action': result['action'],
          'selected_method_id': result['card_id'],
          'consent_version': savedCardMethodConsent,
        };
        if (!await prefs.setString(
          independentStorageKey,
          jsonEncode(recovered),
        )) {
          throw const FormatException('Intento no conservado');
        }
        if (!current) return;
        independentIntent = recovered;
      }
      if (independentIntent != null &&
          result?['key'] == independentIntent!['key'] &&
          ['refused', 'expired'].contains(result?['status'])) {
        await prefs.remove(independentStorageKey);
        if (!current) return;
        independentIntent = null;
        independentError = result?['status'] == 'refused'
            ? 'No se cambió la tarjeta porque está en uso. Consulta su estado antes de volver a intentar.'
            : 'La solicitud venció sin aplicarse. Puedes autorizar una nueva.';
      }
      independentFresh = true;
    } catch (_) {
      if (current) independentError = 'No pudimos consultar el cambio de tarjeta. Actualiza el estado antes de continuar.';
    }
  }

  Future<void> confirmIndependentMethod(SharedPreferences prefs) async {
    final candidate = independentIntent, receipt = independentStatus;
    if (candidate == null ||
        receipt == null ||
        receipt['key'] != candidate['key'] ||
        receipt['action'] != candidate['action'] ||
        receipt['card_id'] != candidate['selected_method_id'] ||
        cards == null ||
        cardsError != null) {
      return;
    }
    final removed = receipt['action'] == 'remove', target = receipt['card_id'];
    if (removed
        ? receipt['status'] != 'removed' || cards!.any((c) => c.id == target)
        : receipt['status'] != 'applied' ||
              !cards!.any((c) => c.id == target && c.isDefault)) {
      return;
    }
    await prefs.remove(independentStorageKey);
    if (!current) return;
    independentIntent = null;
    final key = receipt['key'] as String;
    if (!shownMethodsFeedback.add(key)) return;
    methodsFeedbackKey = key;
    feedbackIsRemoval = removed;
    methodsFeedback = removed
        ? 'Tarjeta eliminada.'
        : 'Método predeterminado actualizado';
  }

  Future<void> changeIndependentMethod({
    GuardianPaymentCard? card,
    bool remove = false,
  }) async {
    if (!current ||
        busy ||
        confirming ||
        !fresh ||
        !independentFresh ||
        plan != null ||
        !ref.read(guardianEnabledProvider) ||
        ref.read(identityControllerProvider).identity?.verified != true ||
        intent != null ||
        savedCardIntent != null ||
        independentStatus?['status'] == 'attention') {
      return;
    }
    if (independentIntent == null) {
      if (card == null ||
          card.isDefault ||
          !(cards ?? []).any((c) => c.id == card.id)) {
        return;
      }
      setState(() => confirming = true);
      final agreed = await confirmIndependentCardMethod(
        context,
        card,
        remove: remove,
      );
      if (!current) return;
      setState(() => confirming = false);
      if (!agreed) return;
    }
    setState(() {
      busy = true;
      independentError = null;
    });
    try {
      final next =
          independentIntent ??
          <String, dynamic>{
            'kind': 'saved_card_method',
            'key': const Uuid().v4(),
            'action': remove ? 'remove' : 'default',
            'selected_method_id': card!.id,
            'consent_version': savedCardMethodConsent,
          };
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(independentStorageKey, jsonEncode(next))) {
        throw const FormatException('Intento no conservado');
      }
      if (!current) return;
      independentIntent = next;
      await ref.read(guardianRepositoryProvider).submit(next);
      if (current) await load();
    } catch (_) {
      if (current) {
        setState(
          () => independentError = 'No pudimos confirmar el cambio. Reintenta la misma solicitud para consultar su resultado.',
        );
      }
    } finally {
      if (current) setState(() => busy = false);
    }
  }

  Future<void> addSavedCard() async {
    if (!current ||
        busy ||
        confirming ||
        !fresh ||
        !widget.paymentMethodsOnly ||
        !ref.read(guardianEnabledProvider) ||
        ref.read(identityControllerProvider).identity?.verified != true ||
        intent != null ||
        independentIntent != null ||
        !independentFresh ||
        savedCardStatus?['status'] == 'attention' ||
        (savedCardIntent == null && !savedCardFresh)) {
      return;
    }
    if (savedCardIntent == null) {
      setState(() => confirming = true);
      final agreed = await confirmSavedCard(context);
      if (!current) return;
      setState(() => confirming = false);
      if (!agreed) return;
    }
    setState(() {
      busy = true;
      savedCardError = null;
    });
    try {
      final next =
          savedCardIntent ??
          <String, dynamic>{
            'kind': 'add_card',
            'key': const Uuid().v4(),
            'consent_version': savedCardConsent,
          };
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(savedCardStorageKey, jsonEncode(next))) {
        throw const FormatException('No se pudo conservar el intento');
      }
      if (!current) return;
      savedCardIntent = next;
      pendingSavedFeedback = next['key'];
      final repo = ref.read(guardianRepositoryProvider);
      final result = await repo.submit(next);
      if (!current) return;
      if (result['checkout_url'] is String) {
        await repo.openCheckout(result['checkout_url']);
      }
      if (current) await load();
    } catch (_) {
      if (current) {
        setState(
          () => savedCardError = 'No pudimos confirmar el alta. Reintenta la misma solicitud para continuar; tu tarjeta todavía no está confirmada.',
        );
      }
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
    bool removeCard = false,
  }) async {
    if (busy || confirming || !fresh || !current) return;
    if (!cancel && !method && !withdraw && checkoutInReview) return;
    if (removeCard && (!method || selectedCard == null)) return;
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
              barrierColor: ink.withValues(alpha: .48),
              animationStyle: AnimationStyle.noAnimation,
              builder: (context) => AlertDialog(
                scrollable: true,
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                titleTextStyle: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: MediaQuery.textScalerOf(context).scale(22) > 33
                      ? 18
                      : 22,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
                contentTextStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  height: 1.55,
                  color: muted,
                ),
                title: Text(
                  withdraw
                      ? '¿Retirar el cambio de monto?'
                      : method
                      ? removeCard
                            ? '¿Eliminar esta tarjeta?'
                            : selectedCard == null
                            ? '¿Actualizar tu medio de pago?'
                            : '¿Usar esta tarjeta como predeterminada?'
                      : '¿Cancelar tu plan Guardián?',
                ),
                content: Text(
                  withdraw
                      ? 'Mantendrás el importe anterior de tu plan: ${pesos(plan!['gross_cents'] as int)} al mes. Lo retiraremos si aún no comenzó a aplicarse; los próximos ciclos podrán continuar con el importe anterior. Esta acción no cancela tu plan.'
                      : method
                      ? removeCard
                            ? 'Eliminarás ${selectedCard!.brandLabel} •••• ${selectedCard.last4} de tus tarjetas guardadas. Tu tarjeta predeterminada y tu plan no cambiarán. Para volver a usarla tendrás que agregarla de nuevo.'
                            : selectedCard == null
                            ? 'Autorizo guardar y usar el nuevo medio en Stripe para los próximos ciclos de Guardián, con el monto y las condiciones vigentes. Stripe puede solicitar autenticación bancaria. Este cambio no cobra ni recupera ciclos omitidos.'
                            : 'Autorizo usar ${selectedCard.brandLabel} •••• ${selectedCard.last4} como medio predeterminado para los próximos ciclos de Guardián, con el monto y las condiciones vigentes. Este cambio no cobra ni recupera ciclos omitidos.'
                      : 'Detendremos los ciclos futuros. Un pago ya iniciado puede terminar de procesarse. Los pagos anteriores conservan su historial y no se devuelven automáticamente.',
                ),
                actions: [
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: ink,
                      minimumSize: const Size(44, 44),
                      textStyle: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      method || withdraw ? 'Volver' : 'Conservar plan',
                    ),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: removeCard
                          ? const Color(0xffd52f26)
                          : ink,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 11,
                      ),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(
                      withdraw
                          ? 'Retirar y conservar monto'
                          : method
                          ? removeCard
                                ? 'Eliminar tarjeta'
                                : 'Autorizar y continuar'
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
                  if (removeCard) 'remove_saved': true,
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
            ? next['remove_saved'] == true || next['selected_method_id'] != null
                  ? null
                  : guardianMethodLabels[result['status']] ??
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
        child: Stack(
          children: [
            RefreshIndicator(
              color: ink,
              backgroundColor: Colors.white,
              onRefresh: () async {
                if (!busy && !confirming && current) await load();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                children: [
                  const Text(
                    'Tarjetas guardadas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (enabled && cardsError != null) Notice(cardsError!),
                  if (enabled && cards != null && cards!.isNotEmpty)
                    for (var i = 0; i < cards!.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      GuardianPaymentCardRow(
                        card: cards![i],
                        showMakeDefault:
                            verified &&
                            (status == 'active' ||
                                (plan == null && independentFresh)),
                        showRemove:
                            verified &&
                            (status == 'active' ||
                                (plan == null && independentFresh)),
                        onRemove:
                            busy ||
                                confirming ||
                                !fresh ||
                                intent != null ||
                                savedCardIntent != null ||
                                independentIntent != null ||
                                (plan != null &&
                                    data?['method_change_available'] != true)
                            ? null
                            : () => plan == null
                                  ? changeIndependentMethod(
                                      card: cards![i],
                                      remove: true,
                                    )
                                  : submit(
                                      method: true,
                                      selectedCard: cards![i],
                                      removeCard: true,
                                    ),
                        onMakeDefault:
                            busy ||
                                confirming ||
                                !fresh ||
                                intent != null ||
                                savedCardIntent != null ||
                                independentIntent != null ||
                                (plan != null &&
                                    data?['method_change_available'] != true)
                            ? null
                            : () => plan == null
                                  ? changeIndependentMethod(card: cards![i])
                                  : submit(
                                      method: true,
                                      selectedCard: cards![i],
                                    ),
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
                                  ? 'Consultando tus tarjetas…'
                                  : 'Aún no tienes tarjetas guardadas.',
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
                      methodsNotice != null &&
                      message != methodsNotice)
                    Notice(methodsNotice ?? 'Medio de pago en revisión.'),
                  const SizedBox(height: 10),
                  if (enabled)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ink,
                        minimumSize: const Size.fromHeight(56),
                        side: const BorderSide(color: Color(0xffd5cfc6)),
                        textStyle: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        shape: const PaymentMethodBorder(),
                      ),
                      onPressed:
                          busy ||
                              confirming ||
                              !fresh ||
                              !verified ||
                              !savedCardFresh ||
                              !independentFresh ||
                              intent != null ||
                              savedCardIntent != null ||
                              walletIntent != null ||
                              independentIntent != null
                          ? null
                          : addSavedCard,
                      icon: SvgPicture.asset(
                        'assets/profile/icon-plus.svg',
                        width: 18,
                        height: 18,
                      ),
                      label: const Text('Agregar tarjeta'),
                    ),
                  if (ref.read(nativeWalletSdkProvider).provider != null) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Billeteras digitales',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    NativeWalletButtons(
                      availableProvider: walletProvider,
                      onPressed:
                          busy ||
                              confirming ||
                              !verified ||
                              !fresh ||
                              intent != null ||
                              savedCardIntent != null ||
                              independentIntent != null
                          ? null
                          : addWallet,
                    ),
                    if (walletError != null)
                      Notice(walletError!, isError: true),
                    if (walletIntent != null)
                      ActionButton(
                        'Continuar autorización',
                        busy: busy,
                        onPressed:
                            busy ||
                                confirming ||
                                walletStatus?['status'] == 'attention'
                            ? null
                            : () => addWallet(walletIntent!['wallet_type']),
                      ),
                  ],
                  if (independentError != null)
                    Notice(independentError!, isError: true),
                  if (independentIntent != null)
                    independentStatus?['status'] == 'attention'
                        ? const Notice(
                            'El cambio de tarjeta requiere revisión. Conservamos tu solicitud.',
                          )
                        : ActionButton(
                            independentIntent?['action'] == 'remove'
                                ? 'Reintentar eliminación'
                                : 'Continuar actualización',
                            busy: busy,
                            onPressed: busy || confirming
                                ? null
                                : () => changeIndependentMethod(),
                          ),
                  if (savedCardError != null)
                    Notice(savedCardError!, isError: true),
                  if (savedCardIntent != null &&
                      savedCardStatus?['status'] == 'attention')
                    const Notice(
                      'El alta de tu tarjeta requiere revisión. Conservamos tu solicitud.',
                    ),
                  if (savedCardIntent != null &&
                      savedCardStatus?['status'] != 'attention')
                    ActionButton(
                      'Reintentar alta de tarjeta',
                      busy: busy,
                      onPressed:
                          busy ||
                              confirming ||
                              !fresh ||
                              !verified ||
                              intent != null
                          ? null
                          : addSavedCard,
                    ),
                  if (enabled && intent?['kind'] == 'method')
                    ActionButton(
                      methodRetryLabel,
                      busy: busy,
                      onPressed: canSubmit ? () => submit() : null,
                    ),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: ink),
                    onPressed: busy || confirming ? null : () => load(),
                    child: const Text('Actualizar estado'),
                  ),
                ],
              ),
            ),
            if (methodsFeedback != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 24,
                child: PaymentMethodsFeedback(
                  key: ValueKey(methodsFeedbackKey),
                  message: methodsFeedback!,
                  visible: !feedbackIsRemoval,
                  onDone: () {
                    if (current) setState(() => methodsFeedback = null);
                  },
                ),
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
                  guardianMethodNotice(methodSetup) ??
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
                  methodRetryLabel,
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
