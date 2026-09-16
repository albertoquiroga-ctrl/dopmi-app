import { createClient, type SupabaseClient } from '@supabase/supabase-js';

export type AdminUser = {
  id: string; display_name: string; email: string | null; phone: string; city: string;
  active_mode: 'donor' | 'rescuer'; account_status: 'active' | 'suspended';
  created_at: string; email_confirmed_at: string | null; last_sign_in_at: string | null;
};
export type UserPage = { total: number; users: AdminUser[] };
export type Adoption = {
  id: string; owner_id: string; pet_name: string; species: string; sex: string; age_months: number; size: string;
  breed: string; city: string; region: string; story: string; special_care: string; publisher_name: string; publisher_bio: string;
  vaccinated: boolean | null; sterilized: boolean | null; social_dogs: boolean | null; social_cats: boolean | null; social_children: boolean | null;
  photos: string[]; status: string; version: number; review_feedback: string; submitted_at: string | null; updated_at: string;
};
export type Review = { id: string; decision: string; feedback: string; version: number; created_at: string };
export type RescueRecord = { id: string; owner_id: string; kind: string; parent_id: string | null; public_data: Record<string,string>; private_data: Record<string,string>; files: { path: string; role: string }[]; status: string; version: number; feedback: string; reimbursable_cents: number; urgent: boolean; priority_reason: string; submitted_at: string | null; updated_at: string };
export type RescueDetail = { record: RescueRecord; verified: boolean; case_status: string | null; history: { id: string; action: string; feedback: string; version: number; created_at: string; reimbursable_cents: number; urgent: boolean }[] };
export type RescueDecision = { decision: string; note: string; amount_cents: number; is_urgent: boolean; urgency_note: string; publish_content: boolean };
export type Contribution = {
  id: string;
  donor_id: string;
  donor_name: string;
  donor_email: string | null;
  status: 'pending' | 'allocated' | 'partial' | 'unassigned' | 'canceled' | 'refunded';
  expense_title: string;
  payment_status: string;
  transfer_status: string;
  refund_status: string;
  processor: string;
  stripe_charge_id: string | null;
  stripe_transfer_id: string | null;
  gross_cents: number;
  platform_fee_cents: number;
  stripe_fee_cents: number | null;
  net_cents: number | null;
  allocated_cents: number;
  refund_cents: number;
  created_at: string;
  updated_at: string;
  processed_at: string | null;
};
export const adoptionStatus: Record<string, string> = { submitted: 'En revisión', published: 'Publicadas', changes_requested: 'Con correcciones', rejected: 'No aprobadas', adopted: 'Adopciones realizadas', archived: 'Retiradas', draft: 'Borradores' };
export type AdminApi = {
  session: () => Promise<boolean>;
  watch: (onChange: () => void) => () => void;
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  isAdmin: () => Promise<boolean>;
  listUsers: (search: string, page: number) => Promise<UserPage>;
  listAdoptions: (status: string, page: number) => Promise<{ total: number; items: Adoption[] }>;
  reviews: (postId: string) => Promise<Review[]>;
  reviewAdoption: (post: Adoption, decision: string, feedback: string) => Promise<Adoption>;
  photoUrl: (path: string) => Promise<string>;
  listRescue: (kind: string, status: string, page: number) => Promise<{ total: number; items: RescueRecord[] }>;
  rescueDetail: (id: string) => Promise<RescueDetail>;
  reviewRescue: (record: RescueRecord, decision: RescueDecision) => Promise<RescueRecord>;
  rescueFileUrl: (path: string) => Promise<string>;
  listContributions: (status: string, page: number) => Promise<{ total: number; items: Contribution[] }>;
};

export function createAdminApi(client: SupabaseClient): AdminApi {
  return {
    async listRescue(kind, status, page) { const {data,error}=await client.rpc('dopmi_admin_rescue',{kind_filter:kind,status_filter:status,page_number:page}); if(error) throw error; return data; },
    async rescueDetail(id) { const {data,error}=await client.rpc('dopmi_rescue_detail',{record_id:id}); if(error) throw error; return data; },
    async reviewRescue(record, decision) { const {data,error}=await client.rpc('dopmi_review_rescue',{record_id:record.id,expected_version:record.version,...decision}); if(error) throw error; return data; },
    async rescueFileUrl(path) { const {data,error}=await client.storage.from('dopmi-rescue-evidence').createSignedUrl(path,60); if(error) throw error; return data.signedUrl; },
    async listContributions(status, page) { const {data,error}=await client.rpc('dopmi_admin_donations',{status_filter:status,page_number:page}); if(error) throw error; if (!data || !Array.isArray(data.items) || typeof data.total !== 'number') throw new Error('invalid_response'); return data; },
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
    async listAdoptions(status, page) {
      const { data, error } = await client.rpc('dopmi_admin_adoptions', { status_filter: status, page_number: page });
      if (error) throw error; return data;
    },
    async reviews(postId) {
      const { data, error } = await client.rpc('dopmi_adoption_reviews', { post_id: postId });
      if (error) throw error; return data;
    },
    async reviewAdoption(post, decision, feedback) {
      const { data, error } = await client.rpc('dopmi_review_adoption', { post_id: post.id, expected_version: post.version, decision, feedback });
      if (error) throw error; return data;
    },
    async photoUrl(path) {
      const { data, error } = await client.storage.from('dopmi-adoption-photos').createSignedUrl(path, 60);
      if (error) throw error; return data.signedUrl;
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
  if (code === '40001') return 'La publicación cambió. Cierra el detalle y actualiza la lista antes de revisarla otra vez.';
  if (code === '22023') return 'La decisión no está disponible. Revisa el estado y escribe un motivo de 5 a 2000 caracteres.';
  if (code === 'over_request_rate_limit' || code === 'over_email_send_rate_limit') return 'Espera un momento antes de intentarlo otra vez.';
  return 'No pudimos completar la solicitud. Comprueba tu conexión e inténtalo de nuevo.';
}
