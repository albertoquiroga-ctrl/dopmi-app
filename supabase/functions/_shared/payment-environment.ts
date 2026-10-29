import { createClient } from 'npm:@supabase/supabase-js@2.57.4';
import { assertPaymentDatabaseEnvironment, assertStripeAccountBinding, resolvePaymentEnvironment } from './payment-environment.mjs';

const names = [
  'DOPMI_ENVIRONMENT',
  'SUPABASE_URL',
  'DOPMI_PAYMENTS_LIVE_ENABLED',
  'STRIPE_SECRET_KEY_H4_TEST',
  'STRIPE_WEBHOOK_SECRET_H4_TEST',
  'STRIPE_CONNECT_WEBHOOK_SECRET_H4_TEST',
  'STRIPE_SECRET_KEY_LIVE',
  'STRIPE_WEBHOOK_SECRET_LIVE',
  'STRIPE_CONNECT_WEBHOOK_SECRET_LIVE',
  'STRIPE_PLATFORM_ACCOUNT_ID_LIVE',
] as const;

export function paymentEnvironment() {
  return resolvePaymentEnvironment(
    Object.fromEntries(names.map(name => [name, Deno.env.get(name)])),
  );
}

export async function verifiedPaymentEnvironment() {
  const context = paymentEnvironment();
  const url = context.returnUrl.replace('/functions/v1/payment-return', '');
  const db = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } });
  await assertPaymentDatabaseEnvironment(context,
    () => db.rpc('dopmi_payment_environment_server'));
  return await assertStripeAccountBinding(context);
}
