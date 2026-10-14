import { guardianRegistrationConsumer } from './guardian-registration-consumer.mjs';
import { readRegistrationSettlementEvidence } from './guardian-registration-settlement.mjs';

// Driver uses only server-owned discovery and identities. Runtime integration
// must preserve its existing test/collection gates; no timer is created here.
export function guardianRegistrationWorker({ stripe, paymentRpc, bind, authorize, resolve, settle }) {
  const load = id => paymentRpc('get', { id });
  const consumer = guardianRegistrationConsumer({ stripe, load, bind, authorize,
    observe: (id, evidence) => paymentRpc('observe', { id, state: evidence.state,
      payment_intent_id: evidence.paymentIntentId }),
  });
  async function reconcile({ allowNewPayments = false } = {}) {
    let observed = 0, finalized = 0, failed = 0;
    // Keep reconciliation available independently of permission for new sends.
    for (const candidate of await paymentRpc('candidates', {})) {
      try {
        const attempt = await load(candidate.id);
        if (attempt.resolved_at || (!allowNewPayments && !attempt.pay_requested_at)) continue;
        await consumer.consume(attempt.id); observed++;
      } catch { failed++; }
    }
    for (const candidate of await paymentRpc('finalization_candidates', {})) {
      try {
        const attempt = await load(candidate.id);
        if (attempt.resolved_at) continue;
        if (attempt.processor_state === 'processor_succeeded' && !attempt.settlement) {
          const evidence = await readRegistrationSettlementEvidence(stripe, attempt);
          await settle(evidence);
        }
        // SQL independently requires terminal state and matching settlement,
        // or confirmed cancellation; a stale candidate cannot release a hold.
        await resolve(attempt.id); finalized++;
      } catch { failed++; }
    }
    return { observed, finalized, failed };
  }
  return { reconcile };
}
