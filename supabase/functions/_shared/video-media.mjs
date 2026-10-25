// Provider credentials and upload capabilities never belong in client logs.
export const VIDEO_LIMITS = Object.freeze({ seconds: 60, bytes: 200 * 1024 * 1024 });
const uid = /^[a-f0-9]{32}$/;
const uuid = /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i;
export class VideoError extends Error { constructor(code, status=400) { super(code); this.status=status; } }
const providerOperations=new Set(['create','inspect','playback','remove']);
class VideoProviderError extends VideoError {
  constructor(operation,status) {
    super('video_provider_unavailable',502);
    if(providerOperations.has(operation)&&Number.isInteger(status)&&status>=100&&status<=599) { this.providerOperation=operation; this.providerStatus=status; }
  }
}
const diagnosticActions=new Set(['begin','status','playback','cancel','review','list','public_list','webhook']);
const diagnosticCodes=new Set(['invalid_upload','invalid_provider_response','video_not_configured',
  'video_provider_unavailable','unsafe_provider_asset','invalid_webhook','expired_webhook',
  'origin_denied','method_not_allowed','request_too_large','video_unavailable',
  'authentication_required','invalid_action','upload_canceled','video_not_ready',
  'video_access_denied','video_conflict','video_required','video_database_unavailable']);
function logVideoFailure(action,error) {
  // Stable operational signal only. Never pass an Error, request or provider data to logs.
  const code=error instanceof VideoError&&diagnosticCodes.has(error.message)?error.message:'video_request_failed';
  const status=error instanceof VideoError&&[400,401,403,405,409,413,500,502,503].includes(error.status)?error.status:500;
  const provider=error instanceof VideoProviderError&&providerOperations.has(error.providerOperation)&&Number.isInteger(error.providerStatus)&&error.providerStatus>=100&&error.providerStatus<=599?{provider_operation:error.providerOperation,provider_status:error.providerStatus}:{};
  try { console.warn({event:'video_request_failed',action:diagnosticActions.has(action)?action:'unknown',code,status,...provider}); } catch { /* Logging never changes the HTTP contract. */ }
}
export function validateUpload(input) {
  if (!uuid.test(input.parent_id ?? '') || !uuid.test(input.request_key ?? '') || !Number.isSafeInteger(input.parent_version) || input.parent_version < 1 || !['thanks','urgency','expense_evidence','public_update','farewell'].includes(input.purpose) || !Number.isSafeInteger(input.bytes) || input.bytes<1 || input.bytes>VIDEO_LIMITS.bytes) throw new VideoError('invalid_upload');
}
function providerId(value) { if (!uid.test(value ?? '')) throw new VideoError('invalid_provider_response',502); return value; }
function uploadLocation(value) { const url = new URL(value); if(url.protocol!=='https:' || !['upload.videodelivery.net','upload.cloudflarestream.com'].includes(url.hostname) || url.username || url.password) throw new VideoError('invalid_provider_response',502); return url.toString(); }
export function streamProvider({accountId,apiToken,fetcher=fetch}) {
  if(!/^[a-f0-9]{32}$/.test(accountId??'') || !apiToken) throw new VideoError('video_not_configured',503);
  const base=`https://api.cloudflare.com/client/v4/accounts/${accountId}/stream`;
  const headers={Authorization:`Bearer ${apiToken}`};
  const request=async(operation,path,init={})=>{ const response=await fetcher(base+path,{...init,headers:{...headers,...init.headers},redirect:'error'}); if(!response.ok)throw new VideoProviderError(operation,response.status); return response; };
  const result=async(response)=>{const json=await response.json();if(json.success!==true||!json.result)throw new VideoError('invalid_provider_response',502);return json.result;};
  return {
    async create(asset) {
      validateUpload(asset);
      const metadata=`maxDurationSeconds ${btoa('60')},requiresignedurls,asset_id ${btoa(asset.id)}`;
      const response=await request('create','?direct_user=true',{method:'POST',headers:{'Tus-Resumable':'1.0.0','Upload-Length':String(asset.bytes),'Upload-Metadata':metadata}});
      return {provider_id:providerId(response.headers.get('stream-media-id')),upload_url:uploadLocation(response.headers.get('Location'))};
    },
    async inspect(id) { const item=await result(await request('inspect','/'+providerId(id))); if(item.uid!==id || item.requireSignedURLs!==true)throw new VideoError('unsafe_provider_asset',502); return {state:item.status?.state==='pendingupload'?'uploading':item.status?.state==='error'?'failed':item.status?.state==='ready'&&item.readyToStream===true&&Number.isFinite(item.duration)&&item.duration>0&&item.duration<=60?'ready':item.readyToStream===true?'failed':'processing',duration:Number.isFinite(item.duration)&&item.duration>=0?item.duration:null}; },
    async playback(id, now=Math.floor(Date.now()/1000)) { const item=await result(await request('playback','/'+providerId(id)+'/token',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({exp:now+120})})); if(typeof item.token!=='string'||!item.token||item.token.length>8192)throw new VideoError('invalid_provider_response',502); return {hls:`https://videodelivery.net/${encodeURIComponent(item.token)}/manifest/video.m3u8`,poster:`https://videodelivery.net/${encodeURIComponent(item.token)}/thumbnails/thumbnail.jpg`,expires_at:now+120}; },
    async remove(id) { const response=await fetcher(base+'/'+providerId(id),{method:'DELETE',headers,redirect:'error'});if(!response.ok&&response.status!==404)throw new VideoProviderError('remove',response.status); }
  };
}
export async function verifyStreamWebhook(body, signature, secret, now=Math.floor(Date.now()/1000)) {
  if(!secret || typeof body!=='string' || body.length>65536 || !/^time=\d+,sig1=[a-f0-9]{64}$/.test(signature??''))throw new VideoError('invalid_webhook',401);
  const [time,sig]=signature.split(',').map(s=>s.split('=')[1]);
  if(Math.abs(now-Number(time))>300)throw new VideoError('expired_webhook',401);
  const enc=new TextEncoder(); const key=await crypto.subtle.importKey('raw',enc.encode(secret),{name:'HMAC',hash:'SHA-256'},false,['verify']);
  const bytes=Uint8Array.from(sig.match(/../g),x=>parseInt(x,16));
  if(!await crypto.subtle.verify('HMAC',key,bytes,enc.encode(`${time}.${body}`)))throw new VideoError('invalid_webhook',401);
  const data=JSON.parse(body); providerId(data.uid); return data.uid;
}
export function createVideoHandler(runtime) {
  return async(request)=>{
    let diagnosticAction=new URL(request.url).pathname.endsWith('/webhook')?'webhook':'unknown';
    const origin=request.headers.get('origin');
    const allowed=(runtime.env('DOPMI_VIDEO_ALLOWED_ORIGINS')??'').split(',').map(x=>x.trim()).filter(Boolean);
    const cors=origin&&allowed.includes(origin)?{'access-control-allow-origin':origin,'vary':'Origin','access-control-allow-headers':'authorization, apikey, content-type, x-client-info','access-control-allow-methods':'POST, OPTIONS'}:{};
    const reply=(data,status=200)=>new Response(JSON.stringify(data),{status,headers:{'content-type':'application/json','cache-control':'no-store',...cors}});
    try {
      if(origin&&!allowed.includes(origin))throw new VideoError('origin_denied',403);
      if(request.method==='OPTIONS')return reply({ok:true});
      if(request.method!=='POST')throw new VideoError('method_not_allowed',405);
      const raw=await request.text();if(raw.length>65536)throw new VideoError('request_too_large',413);
      if(runtime.env('DOPMI_VIDEO_ENABLED')!=='true'){if(!new URL(request.url).pathname.endsWith('/webhook')&&JSON.parse(raw).action==='public_list')return reply({items:[],enabled:false});throw new VideoError('video_unavailable',503);}
      const provider=runtime.provider();
      if(new URL(request.url).pathname.endsWith('/webhook')) {
        const id=await verifyStreamWebhook(raw,request.headers.get('Webhook-Signature'),runtime.env('CLOUDFLARE_STREAM_WEBHOOK_SECRET'));
        const facts=await provider.inspect(id); // Read back authoritative state, never webhook fields.
        await runtime.service({action:'refresh',provider_id:id,...facts});return reply({ok:true});
      }
      const data=JSON.parse(raw);
      diagnosticAction=diagnosticActions.has(data.action)&&data.action!=='webhook'?data.action:'unknown';
      const token=request.headers.get('authorization');if(!['public_list','playback'].includes(data.action)&&!token?.startsWith('Bearer '))throw new VideoError('authentication_required',401); if(!['begin','status','playback','cancel','review','list','public_list'].includes(data.action))throw new VideoError('invalid_action');
      if(data.action==='begin')validateUpload(data);
      const asset=await runtime.user(token,data);
      if(data.action==='begin') {
        if(asset.upload_url||['processing','ready','failed','canceled','deleted'].includes(asset.technical_state))return reply(asset);
        const claim=await runtime.service({action:'claim',id:asset.id});
        if(!claim.claimed)return reply({...asset,upload_state:'provisioning_unknown'},202);
        // Deliberately no retry here: Stream creation has no documented idempotency key.
        const created=await provider.create({...data,id:asset.id});
        const registered=await runtime.service({action:'created',id:asset.id,provider_id:created.provider_id});
        if(['canceled','deleted'].includes(registered.technical_state))throw new VideoError('upload_canceled',409);
        try { return reply(await runtime.service({action:'bind',id:asset.id,...created})); } catch(error) {
          // A committed bind can lose its response. Read back before any deletion.
          const binding=await runtime.service({action:'binding',id:asset.id,provider_id:created.provider_id});
          if(binding.bound)return reply(binding);
          await runtime.service({action:'orphan_enqueue',provider_id:created.provider_id});
          throw error;
        }
      }
      if(data.action==='playback') {
        if(asset.technical_state!=='ready')throw new VideoError('video_not_ready',409);
        const facts=await provider.inspect(asset.provider_id);if(facts.state!=='ready')throw new VideoError('video_not_ready',409);
        // Reauthorize after network I/O so a concurrent withdrawal cannot issue a new token.
        await runtime.user(token,data); const lease=await provider.playback(asset.provider_id); await runtime.user(token,data); return reply({id:asset.id,...lease});
      }
      if(data.action==='status' && asset.provider_id && !['canceled','deleted'].includes(asset.technical_state)) {
        await runtime.service({action:'refresh',provider_id:asset.provider_id,...await provider.inspect(asset.provider_id)});
        return reply(await runtime.user(token,data));
      }
      if(data.action==='cancel' && asset.provider_id) { await provider.remove(asset.provider_id); await runtime.service({action:'deleted',id:asset.id}); await runtime.service({action:'cleanup_done',provider_id:asset.provider_id}); }
      return reply(asset);
    }catch(error){ logVideoFailure(diagnosticAction,error);return reply({error:error instanceof VideoError?error.message:'video_request_failed'},error instanceof VideoError?error.status:500); }
  };
}

// Server-only operation runner. Schedule only in the explicitly authorized provider
// operation package; no HTTP route exposes this capability to app clients.
export async function drainVideoDeletionQueue(runtime) {
  const provider=runtime.provider(); const queue=await runtime.service({action:'cleanup_list'});
  let removed=0,failed=0;
  for(const provider_id of queue.items) {
    try { await provider.remove(provider_id);await runtime.service({action:'cleanup_done',provider_id});removed++; }
    catch { failed++; } // Keep durable task for retry; never emit sensitive IDs or provider errors.
  }
  return {removed,failed};
}
