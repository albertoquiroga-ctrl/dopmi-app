import { createClient } from 'npm:@supabase/supabase-js@2.57.4';
import { paymentService, PaymentError, stripeApi } from './payments.mjs';

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
    const result = await db.rpc('dopmi_payment_server', { operation, data });
    if (result.error) throw new PaymentError(result.error.code === '42501' ? 'access_denied' : 'payment_unavailable', result.error.code === '42501' ? 403 : 409);
    return result.data;
  };
  const stripe = stripeApi(Deno.env.get('STRIPE_SECRET_KEY'));
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
