import type { SupabaseClient } from '@supabase/supabase-js';
export type SupportRequest = { request_id:string;owner_id:string;topic:string;case_name:string;message:string;created_at:string;display_name:string;email:string|null;attachment_path?:string|null };
export type SupportPage = { total:number;items:SupportRequest[] };
export function supportRequests(client:SupabaseClient) {
  return async (page:number):Promise<SupportPage> => {
    const {data,error}=await client.rpc('dopmi_admin_support_requests',{page_number:page,page_size:25});
    if(error) throw error;
    return data;
  };
}
