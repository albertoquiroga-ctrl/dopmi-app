import { createClient } from 'npm:@supabase/supabase-js@2.57.4';
import { streamProvider, VideoError } from './video-media.mjs';
export function videoRuntime() {
  const options={auth:{persistSession:false,autoRefreshToken:false}};
  const admin=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,options);
  const checked=async(promise:PromiseLike<{data:unknown,error:{code?:string}|null}>)=>{const {data,error}=await promise;if(error)throw new VideoError(error.code==='42501'?'video_access_denied':error.code==='40001'?'video_conflict':error.code==='23514'?'video_required':'video_database_unavailable',error.code==='42501'?403:['40001','23514','55000'].includes(error.code??'')?409:500);return data;};
  return {
    env:(name:string)=>Deno.env.get(name),
    provider:()=>streamProvider({accountId:Deno.env.get('CLOUDFLARE_ACCOUNT_ID'),apiToken:Deno.env.get('CLOUDFLARE_STREAM_API_TOKEN')}),
    user:async(token:string|null,data:{action?:string})=>{
      const user=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_ANON_KEY')!,{...options,global:{headers:token?{Authorization:token}:{}}});
      if(!['public_list','playback'].includes(data.action??'')){const verified=await user.auth.getUser();if(verified.error||!verified.data.user||verified.data.user.is_anonymous)throw new VideoError('authentication_required',401);}
      return checked(user.rpc('dopmi_video_action',{data}));
    },
    service:(data:unknown)=>checked(admin.rpc('dopmi_video_service',{data})),
  };
}
