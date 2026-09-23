import { createClient } from 'npm:@supabase/supabase-js@2.57.4';
import { paymentService, PaymentError, paymentLog, stripeApi } from './payments.mjs';

export const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
export function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: { ...cors, 'Content-Type': 'application/json', 'Cache-Control': 'no-store' } });
}
export function runtime() {
  const url = Deno.env.get('SUPABASE_URL')!;
  const db = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { auth: { persistSession: false } });
  const rpc = async (operation: string, data: unknown) => {
    const request = operation === 'refund_begin' || operation === 'refund_finish'
      ? db.rpc('dopmi_refund_adjustment', { operation: operation === 'refund_begin' ? 'begin' : 'finish', data })
      : operation === 'finish_job'
      ? db.rpc('dopmi_payment_job_finish', { data })
      : operation === 'claim'
      ? db.rpc('dopmi_payment_job_claim', { target_key: (data as { job_key?: string })?.job_key ?? null })
      : operation === 'replay_get'
        ? db.rpc('dopmi_payment_replay_get', { target_id: (data as { donation_id: string }).donation_id })
        : operation === 'connect_status'
          ? db.rpc('dopmi_connect_status', { target_actor: (data as { actor: string }).actor })
          : db.rpc('dopmi_payment_server', { operation, data });
    const result = await request;
    if (result.error) {
      const denied = result.error.code === '42501';
      const code = denied ? (operation === 'connect_get' || operation === 'connect_begin' ? 'rescuer_verification_required' : 'access_denied') : 'payment_unavailable';
      const context = { source: 'database', operation, sqlstate: result.error.code };
      paymentLog(console, 'payment_rpc_failed', context);
      throw new PaymentError(code, denied ? 403 : result.error.code === '22023' || result.error.code === '40001' ? 409 : 503, context);
    }
    return result.data;
  };
  // H4 uses an isolated test key without replacing the pre-existing Stripe
  // configuration. Production enablement must remove this override explicitly.
  const stripe = stripeApi(
    Deno.env.get('STRIPE_SECRET_KEY_H4_TEST') ??
      Deno.env.get('STRIPE_SECRET_KEY'),
  );
  const returnUrl = `${url}/functions/v1/payment-return`;
  const service = paymentService({ rpc, stripe, returnUrl });
  async function actor(req: Request) {
    const token = req.headers.get('Authorization')?.match(/^Bearer (.+)$/i)?.[1];
    if (!token) throw new PaymentError('sign_in_required', 401);
    const { data, error } = await db.auth.getUser(token);
    if (error || !data.user || !data.user.email_confirmed_at) throw new PaymentError('sign_in_required', 401);
    return data.user.id;
  }
  return { rpc, service, actor };
}
export function failure(error: unknown) {
  return json({ error: error instanceof PaymentError ? error.code : 'payment_unavailable' }, error instanceof PaymentError ? Math.min(error.status, 503) : 503);
}
