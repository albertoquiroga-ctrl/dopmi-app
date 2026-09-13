import { createClient, type SupabaseClient } from '@supabase/supabase-js';

export type AdminUser = {
  id: string; display_name: string; email: string | null; phone: string; city: string;
  active_mode: 'donor' | 'rescuer'; account_status: 'active' | 'suspended';
  created_at: string; email_confirmed_at: string | null; last_sign_in_at: string | null;
};
export type UserPage = { total: number; users: AdminUser[] };
export type AdminApi = {
  session: () => Promise<boolean>;
  watch: (onChange: () => void) => () => void;
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  isAdmin: () => Promise<boolean>;
  listUsers: (search: string, page: number) => Promise<UserPage>;
};

export function createAdminApi(client: SupabaseClient): AdminApi {
  return {
    async session() { const { data, error } = await client.auth.getSession(); if (error) throw error; return !!data.session; },
    watch(onChange) { const { data } = client.auth.onAuthStateChange(() => onChange()); return () => data.subscription.unsubscribe(); },
    async login(email, password) { const { error } = await client.auth.signInWithPassword({ email, password }); if (error) throw error; },
    async logout() { const { error } = await client.auth.signOut({ scope: 'local' }); if (error) throw error; },
    async isAdmin() { const { data, error } = await client.rpc('dopmi_is_admin'); if (error) throw error; return data === true; },
    async listUsers(search, page) {
      const { data, error } = await client.rpc('admin_list_users', { search_text: search, page_number: page, page_size: 20 });
      if (error) throw error;
      if (!data || !Array.isArray(data.users) || typeof data.total !== 'number') throw new Error('invalid_response');
      return data as UserPage;
    },
  };
}

export function configuredApi(): AdminApi | null {
  const url = import.meta.env.VITE_SUPABASE_URL;
  const key = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key) return null;
  try {
    const parsed = new URL(url);
    if (parsed.protocol !== 'https:' && !['localhost', '127.0.0.1'].includes(parsed.hostname)) return null;
    // Frontends must never accept a secret key or a service-role JWT.
    if (key.startsWith('sb_secret_')) return null;
    if (key.startsWith('eyJ')) {
      const payload = JSON.parse(atob(key.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')));
      if (payload.role !== 'anon') return null;
    }
    return createAdminApi(createClient(url, key));
  } catch { return null; }
}

export function errorMessage(error: unknown): string {
  const code = typeof error === 'object' && error !== null && 'code' in error ? String(error.code) : '';
  if (code === 'invalid_credentials') return 'Revisa tu correo y contraseña.';
  if (code === 'email_not_confirmed') return 'Confirma tu correo antes de iniciar sesión.';
  if (code === '42501') return 'Tu cuenta no tiene acceso administrativo. Vuelve a iniciar sesión o contacta al responsable.';
  if (code === 'over_request_rate_limit' || code === 'over_email_send_rate_limit') return 'Espera un momento antes de intentarlo otra vez.';
  return 'No pudimos completar la solicitud. Comprueba tu conexión e inténtalo de nuevo.';
}
