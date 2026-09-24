import { createClient } from 'npm:@supabase/supabase-js@2.57.4';
import Stripe from 'npm:stripe@22.6.0';
import { guardianService } from './guardian-service.mjs';
import { guardianActivationService } from './guardian-activation.mjs';
import { PaymentError, requireTestKey } from './payments.mjs';

// Separate client/version from H4. Creating this runtime requires an explicit
// test-only worker flag. The activation service is server-only; no user-facing
// Checkout endpoint is enabled before the monthly schedule is implemented.
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
  return { ...service, initial,
    async reconcile() {
      const activation = await initial.reconcile();
      const result = await service.reconcile();
      return { ...result, initial_reconciled: activation.reconciled, failed: result.failed + activation.failed };
    },
  };
}
