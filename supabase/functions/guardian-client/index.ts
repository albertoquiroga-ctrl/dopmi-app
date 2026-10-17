import { createClient } from 'npm:@supabase/supabase-js@2.57.4';
import { guardianRuntime } from '../_shared/guardian-runtime.ts';
import { guardianClientEnabled, guardianClientHandler, nativeWalletEnabled } from '../_shared/guardian-client.mjs';

Deno.serve(guardianClientHandler({
  enabled: () => guardianClientEnabled((name: string) => Deno.env.get(name)),
  walletEnabled: () => nativeWalletEnabled((name: string) => Deno.env.get(name)),
  registrationMethod: (actor: string, input: { action: string }) => {
    const service = guardianRuntime().registrationMethod;
    return input.action === 'registration_method' ? service.submit(actor, input) : service.status(actor, input);
  },
  registrationAction: (actor: string, input: unknown) => guardianRuntime().registrationAction(actor, input),
  registration: (actor: string, input: { action: string }) => {
    const service = guardianRuntime().registration;
    if (input.action === 'register') return service.register(actor, input);
    if (input.action === 'registration_cancel') return service.cancel(actor, input);
    if (input.action === 'registration_amount') return service.changeAmount(actor, input);
    return service.status(actor, input);
  },
  authenticate: async (token: string) => {
    const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      { auth: { persistSession: false } });
    const { data, error } = await db.auth.getUser(token);
    return error ? null : data.user;
  },
  checkout: (actor: string, input: unknown) => guardianRuntime().initial.checkout(actor, input),
  defaultMethod: (actor: string, input: unknown) => guardianRuntime().method.checkout(actor, input),
  removeMethod: (actor: string, input: unknown) => guardianRuntime().method.checkout(actor, input),
  addCard: (actor: string, input: unknown) => guardianRuntime().savedCard.checkout(actor, input),
  addWallet: (actor: string, input: unknown) => guardianRuntime().savedWallet.submit(actor, input),
  savedCardMethod: (actor: string, input: unknown) => guardianRuntime().savedCardMethod.submit(actor, input),
  methods: (actor: string) => guardianRuntime().methods(actor),
  method: (actor: string, input: unknown) => guardianRuntime().method.checkout(actor, input),
}));
