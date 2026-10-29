import { createClient } from 'npm:@supabase/supabase-js@2.57.4';
import { guardianRuntime } from '../_shared/guardian-runtime.ts';
import { guardianClientEnabled, guardianClientHandler, nativeWalletEnabled } from '../_shared/guardian-client.mjs';

Deno.serve(guardianClientHandler({
  enabled: () => guardianClientEnabled((name: string) => Deno.env.get(name)),
  walletEnabled: () => nativeWalletEnabled((name: string) => Deno.env.get(name)),
  registrationMethod: async (actor: string, input: { action: string }) => {
    const service = (await guardianRuntime()).registrationMethod;
    return input.action === 'registration_method' ? service.submit(actor, input) : service.status(actor, input);
  },
  registrationAction: async (actor: string, input: unknown) => (await guardianRuntime()).registrationAction(actor, input),
  registration: async (actor: string, input: { action: string }) => {
    const service = (await guardianRuntime()).registration;
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
  checkout: async (actor: string, input: unknown) => (await guardianRuntime()).initial.checkout(actor, input),
  defaultMethod: async (actor: string, input: unknown) => (await guardianRuntime()).method.checkout(actor, input),
  removeMethod: async (actor: string, input: unknown) => (await guardianRuntime()).method.checkout(actor, input),
  addCard: async (actor: string, input: unknown) => (await guardianRuntime()).savedCard.checkout(actor, input),
  nativeAddCard: async (actor: string, input: { action: string }) => {
    const service = (await guardianRuntime()).savedNativeCard;
    return input.action === 'native_add_card' ? service.addSubmit(actor, input) : service.addStatus(actor, input);
  },
  addWallet: async (actor: string, input: unknown) => (await guardianRuntime()).savedWallet.submit(actor, input),
  savedCardMethod: async (actor: string, input: unknown) => (await guardianRuntime()).savedCardMethod.submit(actor, input),
  methods: async (actor: string) => (await guardianRuntime()).methods(actor),
  method: async (actor: string, input: unknown) => (await guardianRuntime()).method.checkout(actor, input),
}));
