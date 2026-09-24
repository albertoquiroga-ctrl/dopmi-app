import { createClient } from 'npm:@supabase/supabase-js@2.57.4';
import Stripe from 'npm:stripe@22.6.0';
import { guardianService } from './guardian-service.mjs';
import { guardianActivationService } from './guardian-activation.mjs';
import { guardianCollectionService } from './guardian-collection.mjs';
import { guardianScheduleService } from './guardian-schedule.mjs';
import { guardianChangeService } from './guardian-changes.mjs';
import { PaymentError, requireTestKey } from './payments.mjs';

// Separate client/version from H4. Creating this runtime requires an explicit
// test-only worker flag. The activation service is server-only; no user-facing
// Checkout endpoint is enabled before monthly collection and lifecycle acceptance.
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
  return { ...service, initial, schedule, collection, changes,
    async reconcile() {
      const activation = await initial.reconcile();
      const management = Deno.env.get('DOPMI_GUARDIAN_CHANGES_ENABLED') === 'true'
        ? await changes.reconcile() : { applied: 0, failed: 0 };
      const monthly = Deno.env.get('DOPMI_GUARDIAN_COLLECTION_ENABLED') === 'true'
        ? await collection.reconcile() : { processed: 0, failed: 0 };
      const result = await service.reconcile();
      const calendar = Deno.env.get('DOPMI_GUARDIAN_SCHEDULE_ENABLED') === 'true'
        ? await schedule.reconcile() : { ready: 0, failed: 0 };
      return { ...result, initial_reconciled: activation.reconciled, schedules_ready: calendar.ready, monthly_processed: monthly.processed,
        changes_applied: management.applied,
        failed: result.failed + activation.failed + calendar.failed + monthly.failed + management.failed };
    },
  };
}
