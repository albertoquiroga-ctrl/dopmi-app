import { guardianRegistrationConsumer } from './guardian-registration-consumer.mjs';
import { readRegistrationSettlementEvidence } from './guardian-registration-settlement.mjs';
import { assertRegistrationPaymentIdentity, registrationPaymentEvidence } from './guardian-registration-payment.mjs';
import { PaymentError } from './payments.mjs';

const uuid = value => /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value ?? '');

// Driver uses only server-owned discovery and identities. Runtime integration
// must preserve its existing test/collection gates; no timer is created here.
export function guardianRegistrationWorker({ stripe, paymentRpc, bind, authorize, resolve, settle }) {
  const load = id => paymentRpc('get', { id });
  const consumer = guardianRegistrationConsumer({ stripe, load, bind, authorize,
    observe: (id, evidence) => paymentRpc('observe', { id, state: evidence.state,
      payment_intent_id: evidence.paymentIntentId }),
  });
  async function runAttempt(id, { allowNewPayments = false, finalizeOnly = false } = {}) {
    let attempt = await load(id);
    if (!attempt || attempt.id !== id)
      throw new PaymentError('guardian_registration_attempt_unavailable', 409);
    let observed = 0, finalized = 0;
    if (!attempt.resolved_at && (allowNewPayments || attempt.pay_requested_at)) {
      if (!finalizeOnly && !['processor_succeeded', 'processor_canceled'].includes(attempt.processor_state)) {
        await consumer.consume(attempt.id); observed++;
        attempt = await load(id);
        if (!attempt || attempt.id !== id)
          throw new PaymentError('guardian_registration_attempt_unavailable', 409);
      }
      if (!attempt.resolved_at && attempt.pay_requested_at &&
          ['processor_succeeded', 'processor_canceled'].includes(attempt.processor_state)) {
        if (attempt.processor_state === 'processor_succeeded' && !attempt.settlement) {
          const evidence = await readRegistrationSettlementEvidence(stripe, attempt);
          await settle(evidence);
        }
        // SQL independently rechecks terminal evidence and the settlement.
        await resolve(attempt.id); finalized++;
      }
    }
    return { observed, finalized };
  }
  async function reconcile({ allowNewPayments = false } = {}) {
    let observed = 0, finalized = 0, failed = 0;
    // Keep reconciliation available independently of permission for new sends.
    for (const candidate of await paymentRpc('candidates', {})) {
      try {
        const result = await runAttempt(candidate.id, { allowNewPayments });
        observed += result.observed; finalized += result.finalized;
      } catch { failed++; }
    }
    for (const candidate of await paymentRpc('finalization_candidates', {})) {
      try {
        const result = await runAttempt(candidate.id, { finalizeOnly: true });
        finalized += result.finalized;
      } catch { failed++; }
    }
    return { observed, finalized, failed };
  }
  // Signature verification belongs to the HTTP boundary. The event and its
  // PaymentIntent are re-read in TEST; metadata is only a lookup hint. Neither
  // webhook delivery nor a forged hint may create/authorize a payment.
  async function handleWebhook(eventId) {
    if (!/^evt_[A-Za-z0-9]+$/.test(eventId ?? ''))
      throw new PaymentError('guardian_event_invalid', 400);
    const event = await stripe.events.retrieve(eventId);
    if (event?.id !== eventId || event.livemode !== false)
      throw new PaymentError('guardian_event_invalid', 400);
    if (!['payment_intent.succeeded', 'payment_intent.canceled'].includes(event.type)) return null;
    const paymentIntentId = event.data?.object?.id;
    const attemptId = event.data?.object?.metadata?.guardian_registration_attempt_id;
    if (!/^pi_[A-Za-z0-9]+$/.test(paymentIntentId ?? '') || !uuid(attemptId)) return null;
    const attempt = await load(attemptId);
    if (!attempt || attempt.id !== attemptId || !attempt.pay_requested_at ||
        attempt.stripe_payment_intent_id !== paymentIntentId) return null;
    const intent = await stripe.paymentIntents.retrieve(paymentIntentId);
    assertRegistrationPaymentIdentity(attempt, intent);
    const freshState = registrationPaymentEvidence(attempt, intent).state;
    if (['processor_succeeded', 'processor_canceled'].includes(attempt.processor_state) &&
        ['processor_succeeded', 'processor_canceled'].includes(freshState) &&
        attempt.processor_state !== freshState)
      throw new PaymentError('guardian_registration_payment_mismatch', 409);
    const result = await runAttempt(attemptId);
    const current = await load(attemptId);
    // A duplicate may still drain this settlement's durable delivery jobs.
    // Its cycle is DB-owned, never taken from event metadata or a global scan.
    let cycleId = null;
    if (current?.settlement) {
      if (current.id !== attemptId || !current.pay_requested_at ||
          current.stripe_payment_intent_id !== paymentIntentId ||
          current.processor_state !== 'processor_succeeded' || !uuid(current.reservation_id) ||
          current.settlement.cycle_id !== current.reservation_id ||
          current.settlement.registration_attempt_id !== attemptId ||
          current.settlement.payment_intent_id !== paymentIntentId)
        throw new PaymentError('guardian_registration_settlement_mismatch', 409);
      cycleId = current.reservation_id;
    }
    return { received: true, guardian_registration: true, ...result, cycleId };
  }
  return { runAttempt, reconcile, handleWebhook };
}
