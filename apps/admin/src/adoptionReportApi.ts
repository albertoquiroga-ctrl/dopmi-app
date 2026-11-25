import type { SupabaseClient } from '@supabase/supabase-js';

export type AdoptionReportRow = {
  id: string; pet_name: string; species: 'dog' | 'cat'; publisher_name: string;
  city: string; region: string; published_at: string | null;
  detail_viewers: number; current_favorites: number; contacts: number; first_replies: number;
};
export type AdoptionReportPage = {
  total: number; items: AdoptionReportRow[]; detail_tracking_started_at: string; generated_at: string;
};
export type AdoptionReportReader = (search: string, species: string, page: number) => Promise<AdoptionReportPage>;

const count = (value: unknown): value is number => typeof value === 'number' && Number.isSafeInteger(value) && value >= 0;
const timestamp = (value: unknown): value is string => typeof value === 'string' && Number.isFinite(Date.parse(value));
export function createAdoptionReportReader(client: SupabaseClient): AdoptionReportReader {
  return async (search, species, page) => {
    const { data, error } = await client.rpc('dopmi_admin_adoption_report', { search_text: search, species_filter: species, page_number: page });
    if (error) throw error;
    if (!data || !count(data.total) || !timestamp(data.generated_at) || !timestamp(data.detail_tracking_started_at)
      || !Array.isArray(data.items) || data.items.length > 20 || data.items.length > data.total
      || !data.items.every((row: AdoptionReportRow) => row && typeof row.id === 'string'
        && ['pet_name', 'publisher_name', 'city', 'region'].every(key => typeof row[key as keyof AdoptionReportRow] === 'string')
        && ['dog', 'cat'].includes(row.species) && (row.published_at === null || timestamp(row.published_at))
        && [row.detail_viewers, row.current_favorites, row.contacts, row.first_replies].every(count)
        && row.first_replies <= row.contacts)
      || new Set(data.items.map((row: AdoptionReportRow) => row.id)).size !== data.items.length) throw new Error('invalid_response');
    return data as AdoptionReportPage;
  };
}
