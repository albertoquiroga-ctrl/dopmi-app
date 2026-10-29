import { createClient } from 'npm:@supabase/supabase-js@2.57.4';
import Stripe from 'npm:stripe@22.6.0';
import { guardianService } from './guardian-service.mjs';
import { guardianActivationService } from './guardian-activation.mjs';
import { guardianCollectionService } from './guardian-collection.mjs';
import { guardianScheduleService } from './guardian-schedule.mjs';
import { guardianChangeService } from './guardian-changes.mjs';
import { guardianMethodService } from './guardian-method.mjs';
import { guardianMethodListService } from './guardian-method-list.mjs';
import { savedCardService } from './saved-card.mjs';
import { savedCardMethodService } from './saved-card-method.mjs';
import { nativeSavedWalletService } from './native-saved-wallet.mjs';
import { nativeSavedCardService } from './native-saved-card.mjs';
import { guardianRegistrationMethodChange } from './guardian-registration-method-change.mjs';
import { guardianRegistrationService } from './guardian-registration.mjs';
import { guardianRegistrationWorker } from './guardian-registration-worker.mjs';
import { registrationPaymentReply } from './guardian-registration-rpc.mjs';
import { guardianRegistrationBankAction } from './guardian-registration-bank-action.mjs';
import { guardianRefundService } from './guardian-refunds.mjs';
import { PaymentError } from './payments.mjs';
import { verifiedPaymentEnvironment } from './payment-environment.ts';

// Separate client/version from H4. Creating this runtime requires an explicit
// worker flag. The client endpoint additionally requires every lifecycle
// flag and its own checkout gate; all remain off until integrated acceptance.
export async function guardianRuntime() {
  if (Deno.env.get('DOPMI_GUARDIAN_WORKER_ENABLED') !== 'true')
    throw new PaymentError('guardian_worker_disabled', 503);
  const context = await verifiedPaymentEnvironment();
  const { expectedLivemode } = context;
  const stripe = new Stripe(context.secretKey, { apiVersion: '2026-08-26.dahlia', maxNetworkRetries: 0, timeout: 20000 });
  const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } });
  async function call(name: string, operation: string, data: unknown) {
    const result = await db.rpc(name, { operation, data });
    if (result.error) throw new PaymentError('guardian_database_unavailable', 503);
    return result.data;
  }
  const settlement = (operation: string, data: unknown) => call('dopmi_guardian_settlement_server', operation, data);
  const refunds = guardianRefundService({ stripe, expectedLivemode,
    rpc: (operation: string, data: unknown) => call('dopmi_guardian_refund_server', operation, data),
  });
  const service = guardianService({ stripe, expectedLivemode,
    rpc: settlement,
    lookupSubscription: (stripe_subscription_id: string) => call('dopmi_guardian_subscription_server', 'lookup', { stripe_subscription_id }),
  });
  const initial = guardianActivationService({ stripe, expectedLivemode,
    rpc: (operation: string, data: unknown) => call('dopmi_guardian_activation_server', operation, data),
    settle: settlement, returnUrl: context.returnUrl,
  });
  const schedule = guardianScheduleService({ stripe, expectedLivemode,
    rpc: (operation: string, data: unknown) => call('dopmi_guardian_schedule_server', operation, data),
  });
  const collection = guardianCollectionService({ stripe, expectedLivemode, reconcileInvoice: service.reconcileInvoice,
    recoveryRpc: (operation: string, data: unknown) => call('dopmi_guardian_recovery_server', operation, data),
    rpc: (operation: string, data: unknown) => call('dopmi_guardian_collection_server', operation, data),
  });
  const changes = guardianChangeService({ stripe, expectedLivemode,
    rpc: (operation: string, data: unknown) => call('dopmi_guardian_change_server', operation, data),
  });
  const method = guardianMethodService({ stripe, expectedLivemode,
    rpc: async (operation: string, data: unknown) => {
      const result = await db.rpc('dopmi_guardian_method_server', { operation, data });
      if (result.error) {
        if (operation === 'prepare') {
          const code = { '40001': 'guardian_plan_changed', '22023': 'guardian_method_invalid',
            '55000': 'guardian_method_busy', '42501': 'guardian_account_unavailable' }[result.error.code];
          if (code) throw new PaymentError(code, 409);
        }
        throw new PaymentError('guardian_database_unavailable', 503);
      }
      return result.data;
    }, returnUrl: context.returnUrl,
  });
  const methods = guardianMethodListService({ stripe, expectedLivemode, lookup: async (actor: string) => {
    const result = await db.rpc('dopmi_saved_card_owner_server', { target_actor: actor });
    if (result.error) throw new PaymentError('guardian_methods_unavailable', 503);
    return result.data;
  } });
  const savedCard = savedCardService({ stripe, expectedLivemode,
    rpc: (operation: string, data: unknown) => call('dopmi_saved_card_server', operation, data),
    returnUrl: context.returnUrl,
  });
  const savedCardMethod = savedCardMethodService({ stripe, expectedLivemode,
    rpc: async (operation: string, data: unknown) => {
      const result = await db.rpc('dopmi_saved_card_method_server', { operation, data });
      if (result.error) {
        if (operation === 'prepare') {
          const code = { '40001': 'saved_card_method_changed', '22023': 'saved_card_method_invalid',
            '55000': 'saved_card_method_busy', '42501': 'saved_card_account_unavailable' }[result.error.code];
          if (code) throw new PaymentError(code, 409);
        }
        throw new PaymentError('guardian_database_unavailable', 503);
      }
      return result.data;
    },
  });
  const savedWallet = nativeSavedWalletService({ stripe, expectedLivemode,
    rpc: async (operation: string, data: unknown) => {
      const result = await db.rpc('dopmi_saved_wallet_server', { operation, data });
      if (result.error) {
        if (operation === 'prepare') {
          const code = { '40001': 'saved_wallet_changed', '22023': 'saved_wallet_invalid',
            '55000': 'saved_wallet_busy', '42501': 'saved_wallet_account_unavailable' }[result.error.code];
          if (code) throw new PaymentError(code, 409);
        }
        throw new PaymentError('guardian_database_unavailable', 503);
      }
      return result.data;
    }, returnUrl: context.returnUrl,
  });
  const savedNativeCard = nativeSavedCardService({ stripe, expectedLivemode, hosted: savedCard,
    rpc: (operation: string, data: unknown) => call('dopmi_saved_native_card_server', operation, data),
    returnUrl: context.returnUrl,
  });
  const registration = guardianRegistrationService({ savedCard, savedNativeCard,
    rpc: (operation: string, data: unknown) => call('dopmi_guardian_registration_server', operation, data),
    attemptRpc: (operation: string, data: unknown) => call('dopmi_guardian_registration_attempt_server', operation, data),
  });
  const registrationMethod = guardianRegistrationMethodChange({ savedNativeCard,
    rpc: async (operation: string, data: unknown) => {
      const result = await db.rpc('dopmi_guardian_registration_method_server', { operation, data });
      if (result.error) {
        const code = { '40001': 'guardian_registration_changed', '55000': 'guardian_method_busy',
          '42501': 'guardian_method_unavailable', '22023': 'guardian_method_invalid' }[result.error.code];
        throw new PaymentError(code ?? 'guardian_database_unavailable', code ? 409 : 503);
      }
      return result.data;
    },
  });
  async function registrationCommand(name: string, data: Record<string, unknown>) {
    const result = await db.rpc(name, data);
    if (result.error) throw new PaymentError('guardian_database_unavailable', 503);
    return result.data;
  }
  const registrationPayments = guardianRegistrationWorker({ stripe, expectedLivemode,
    paymentRpc: async (operation: string, data: unknown) => {
      const result = await db.rpc('dopmi_guardian_registration_payment_server', { operation, data });
      // A valid UUID from untrusted processor metadata may have no binding.
      // Preserve retryable DB faults while letting that lookup fall through.
      return registrationPaymentReply(operation, result);
    },
    bind: (id: string, processor: string) => registrationCommand('dopmi_guardian_registration_bind_payment',
      { target_attempt: id, processor_id: processor }),
    authorize: (id: string) => registrationCommand('dopmi_guardian_registration_authorize_payment', { target_attempt: id }),
    resolve: (id: string) => registrationCommand('dopmi_guardian_registration_resolve_payment', { target_attempt: id }),
    settle: (evidence: unknown) => settlement('settle_registration', evidence),
  });
  const registrationAction = guardianRegistrationBankAction({ stripe, expectedLivemode,
    authorizeAction: (owner: string, registrationId: string, attemptId: string) => registrationCommand(
      'dopmi_guardian_registration_bank_action', { target_owner: owner, target_registration: registrationId, target_attempt: attemptId }),
  });
  return { ...service, initial, schedule, collection, changes, method, methods, refunds, savedCard, savedNativeCard, savedCardMethod, savedWallet, registration, registrationMethod, registrationPayments, registrationAction,
    async reconcile() {
      const activation = await initial.reconcile();
      const returns = Deno.env.get('DOPMI_GUARDIAN_REFUNDS_ENABLED') === 'true'
        ? await refunds.reconcile() : { reconciled: 0, failed: 0 };
      const management = Deno.env.get('DOPMI_GUARDIAN_CHANGES_ENABLED') === 'true'
        ? await changes.reconcile() : { applied: 0, failed: 0 };
      const methods = Deno.env.get('DOPMI_GUARDIAN_CHANGES_ENABLED') === 'true'
        ? await method.reconcile() : { applied: 0, failed: 0 };
      const savedCards = Deno.env.get('DOPMI_GUARDIAN_CHANGES_ENABLED') === 'true'
        ? await savedCard.reconcile() : { saved: 0, failed: 0 };
      const savedNativeCards = Deno.env.get('DOPMI_GUARDIAN_CHANGES_ENABLED') === 'true'
        ? await savedNativeCard.reconcile() : { saved: 0, failed: 0 };
      const registrationMethods = Deno.env.get('DOPMI_GUARDIAN_CHANGES_ENABLED') === 'true'
        ? await registrationMethod.reconcile() : { applied: 0, failed: 0 };
      const registrations = Deno.env.get('DOPMI_GUARDIAN_CHANGES_ENABLED') === 'true'
        ? await registration.reconcile() : { registered: 0, failed: 0 };
      const savedMethods = Deno.env.get('DOPMI_GUARDIAN_CHANGES_ENABLED') === 'true'
        ? await savedCardMethod.reconcile() : { applied: 0, failed: 0 };
      // Continue reconciliation of previously authorized jobs even when new
      // native-wallet requests are disabled; a SetupIntent must not be stranded.
      const savedWallets = Deno.env.get('DOPMI_GUARDIAN_CHANGES_ENABLED') === 'true'
        ? await savedWallet.reconcile() : { saved: 0, failed: 0 };
      const monthly = Deno.env.get('DOPMI_GUARDIAN_COLLECTION_ENABLED') === 'true'
        ? await collection.reconcile() : { processed: 0, failed: 0 };
      // Durable preparation only; it never invokes Stripe. A later payment
      // consumer must freshly authorize the same attempt before confirmation.
      const registrationAttempts = Deno.env.get('DOPMI_GUARDIAN_COLLECTION_ENABLED') === 'true'
        ? await registration.prepareAttempts() : { prepared: 0, skipped: 0, failed: 0 };
      const registrationCollections = await registrationPayments.reconcile({
        allowNewPayments: Deno.env.get('DOPMI_GUARDIAN_COLLECTION_ENABLED') === 'true',
      });
      const result = await service.reconcile();
      const calendar = Deno.env.get('DOPMI_GUARDIAN_SCHEDULE_ENABLED') === 'true'
        ? await schedule.reconcile() : { ready: 0, failed: 0 };
      return { ...result, initial_reconciled: activation.reconciled, schedules_ready: calendar.ready, monthly_processed: monthly.processed,
        changes_applied: management.applied, methods_applied: methods.applied, cards_saved: savedCards.saved,
        native_cards_saved: savedNativeCards.saved,
        saved_methods_applied: savedMethods.applied,
        wallets_saved: savedWallets.saved,
        registrations_completed: registrations.registered,
        registration_methods_applied: registrationMethods.applied,
        registration_attempts_prepared: registrationAttempts.prepared,
        registration_evaluations_skipped: registrationAttempts.skipped,
        registration_payments_observed: registrationCollections.observed,
        registration_payments_finalized: registrationCollections.finalized,
        refunds_reconciled: returns.reconciled,
        failed: result.failed + activation.failed + calendar.failed + monthly.failed + management.failed + methods.failed + savedCards.failed + savedNativeCards.failed + registrations.failed + registrationMethods.failed + registrationAttempts.failed + registrationCollections.failed + savedMethods.failed + savedWallets.failed + returns.failed };
    },
  };
}
