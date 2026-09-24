import { createClient } from 'npm:@supabase/supabase-js@2.57.4';
import Stripe from 'npm:stripe@22.6.0';
import { guardianService } from './guardian-service.mjs';
import { guardianActivationService } from './guardian-activation.mjs';
import { guardianCollectionService } from './guardian-collection.mjs';
import { guardianScheduleService } from './guardian-schedule.mjs';
import { guardianChangeService } from './guardian-changes.mjs';
import { guardianMethodService } from './guardian-method.mjs';
import { PaymentError, requireTestKey } from './payments.mjs';

// Separate client/version from H4. Creating this runtime requires an explicit
// test-only worker flag. The client endpoint additionally requires every lifecycle
// flag and its own checkout gate; all remain off until integrated acceptance.
export function guardianRuntime() {
  if (Deno.env.get('DOPMI_GUARDIAN_WORKER_ENABLED') !== 'true')
    throw new PaymentError('guardian_worker_disabled', 503);
  const key = Deno.env.get('STRIPE_SECRET_KEY_H4_TEST');
  requireTestKey(key);
  const stripe = new Stripe(key!, { apiVersion: '2026-08-26.dahlia', maxNetworkRetries: 0, timeout: 20000 });
  const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } });
  async function call(name: string, operation: string, data: unknown) {
    const result = await db.rpc(name, { operation, data });
    if (result.error) throw new PaymentError('guardian_database_unavailable', 503);
    return result.data;
  }
  const settlement = (operation: string, data: unknown) => call('dopmi_guardian_settlement_server', operation, data);
  const service = guardianService({ stripe,
    rpc: settlement,
    lookupSubscription: (stripe_subscription_id: string) => call('dopmi_guardian_subscription_server', 'lookup', { stripe_subscription_id }),
  });
  const initial = guardianActivationService({ stripe,
    rpc: (operation: string, data: unknown) => call('dopmi_guardian_activation_server', operation, data),
    settle: settlement, returnUrl: `${Deno.env.get('SUPABASE_URL')!}/functions/v1/payment-return`,
  });
  const schedule = guardianScheduleService({ stripe,
    rpc: (operation: string, data: unknown) => call('dopmi_guardian_schedule_server', operation, data),
  });
  const collection = guardianCollectionService({ stripe, reconcileInvoice: service.reconcileInvoice,
    recoveryRpc: (operation: string, data: unknown) => call('dopmi_guardian_recovery_server', operation, data),
    rpc: (operation: string, data: unknown) => call('dopmi_guardian_collection_server', operation, data),
  });
  const changes = guardianChangeService({ stripe,
    rpc: (operation: string, data: unknown) => call('dopmi_guardian_change_server', operation, data),
  });
  const method = guardianMethodService({ stripe,
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
    }, returnUrl: `${Deno.env.get('SUPABASE_URL')!}/functions/v1/payment-return`,
  });
  return { ...service, initial, schedule, collection, changes, method,
    async reconcile() {
      const activation = await initial.reconcile();
      const management = Deno.env.get('DOPMI_GUARDIAN_CHANGES_ENABLED') === 'true'
        ? await changes.reconcile() : { applied: 0, failed: 0 };
      const methods = Deno.env.get('DOPMI_GUARDIAN_CHANGES_ENABLED') === 'true'
        ? await method.reconcile() : { applied: 0, failed: 0 };
      const monthly = Deno.env.get('DOPMI_GUARDIAN_COLLECTION_ENABLED') === 'true'
        ? await collection.reconcile() : { processed: 0, failed: 0 };
      const result = await service.reconcile();
      const calendar = Deno.env.get('DOPMI_GUARDIAN_SCHEDULE_ENABLED') === 'true'
        ? await schedule.reconcile() : { ready: 0, failed: 0 };
      return { ...result, initial_reconciled: activation.reconciled, schedules_ready: calendar.ready, monthly_processed: monthly.processed,
        changes_applied: management.applied, methods_applied: methods.applied,
        failed: result.failed + activation.failed + calendar.failed + monthly.failed + management.failed + methods.failed };
    },
  };
}
