import { useEffect, useRef, useState } from 'react';
import type { SupabaseClient } from '@supabase/supabase-js';
import Hls from 'hls.js';

export type VideoReviewRow = {id:string;parent_id:string;parent_version:number;current_parent_version:number;purpose:string;technical_state:string;moderation_state:string;duration:number|null};
export type VideoPreview = {hls:string;poster:string;expires_at:number};
export type VideoModerationApi = {
  list():Promise<VideoReviewRow[]>;
  playback(id:string):Promise<VideoPreview>;
  review(row:VideoReviewRow,decision:'approved'|'rejected',note:string):Promise<void>;
  watch(listener:()=>void):()=>void;
};
export function createVideoModerationApi(client:SupabaseClient):VideoModerationApi {
  async function invoke(body:Record<string,unknown>) {
    const {data,error}=await client.functions.invoke('video-media',{body});
    if(error||!data||data.error)throw new Error('No pudimos consultar los videos. Comprueba tu acceso y vuelve a intentar.');
    return data;
  }
  return {
    async list(){return (await invoke({action:'list'})).items;},
    async playback(id){return invoke({action:'playback',id});},
    async review(row,decision,note){await invoke({action:'review',id:row.id,parent_version:row.current_parent_version,decision,note});},
    watch(listener){
      let previous:string|undefined;
      const {data}=client.auth.onAuthStateChange((event,session)=>{
        let next='';
        if(session){try{const part=session.access_token.split('.')[1].replace(/-/g,'+').replace(/_/g,'/');const claims=JSON.parse(atob(part));next=`${session.user.id}:${String(claims.session_id??'')}`;}catch{next='invalid';}}
        if(event==='INITIAL_SESSION'){previous=next;return;}
        if(previous!==next){previous=next;listener();}
      });
      return ()=>data.subscription.unsubscribe();
    },
  };
}
function validPreview(value:VideoPreview) {
  for(const path of [value.hls,value.poster]){const url=new URL(path);if(url.protocol!=='https:'||url.hostname!=='videodelivery.net'||url.username||url.password)throw new Error('invalid_preview');}
  const now=Date.now()/1000;
  if(value.expires_at<=now||value.expires_at>now+180)throw new Error('invalid_preview');
}
export function playedWholeClip(video:HTMLVideoElement) {
  if(!Number.isFinite(video.duration)||video.duration<=0||video.duration>60||video.played.length===0)return false;
  let covered=0;
  for(let i=0;i<video.played.length;i++){if(video.played.start(i)>covered+0.25)return false;covered=Math.max(covered,video.played.end(i));}
  return covered>=video.duration-0.25;
}
const purposes:Record<string,string>={thanks:'Agradecimiento',urgency:'Urgencia',expense_evidence:'Evidencia financiera privada',public_update:'Seguimiento público',farewell:'Despedida'};
export default function VideoModeration({api}:{api:VideoModerationApi}) {
  const [rows,setRows]=useState<VideoReviewRow[]>([]),[selected,setSelected]=useState<VideoReviewRow>();
  const [preview,setPreview]=useState<VideoPreview>(),[note,setNote]=useState(''),[error,setError]=useState(''),[notice,setNotice]=useState('');
  const [busy,setBusy]=useState(false),[watched,setWatched]=useState(false),[playingReady,setPlayingReady]=useState(false);
  const generation=useRef(0),mounted=useRef(true),videoRef=useRef<HTMLVideoElement>(null);
  useEffect(()=>{
    mounted.current=true;
    let active=true;const run=++generation.current;
    setRows([]);setSelected(undefined);setPreview(undefined);setWatched(false);setPlayingReady(false);setBusy(false);setError('');
    void api.list().then(items=>{if(active&&run===generation.current)setRows(items);}).catch(()=>{if(active&&run===generation.current)setError('No pudimos cargar los videos.');});
    const stop=api.watch(()=>{generation.current++;setRows([]);setSelected(undefined);setPreview(undefined);setWatched(false);setBusy(false);setError('Tu sesión cambió. Vuelve a abrir la sección.');});
    return()=>{active=false;mounted.current=false;generation.current++;stop();};
  },[api]);
  async function open(row:VideoReviewRow) {
    const run=++generation.current;setSelected(undefined);setPreview(undefined);setNote('');setWatched(false);setPlayingReady(false);setError('');setNotice('');setBusy(true);
    try{
      const items=await api.list();if(!mounted.current||run!==generation.current)return;
      setRows(items);const current=items.find(item=>item.id===row.id);
      if(!current||current.parent_id!==row.parent_id||current.parent_version!==row.parent_version||current.purpose!==row.purpose||current.technical_state!=='ready'||!Number.isSafeInteger(current.current_parent_version))throw new Error('unavailable_current_video');
      setSelected(current);
      const value=await api.playback(current.id);validPreview(value);if(mounted.current&&run===generation.current)setPreview(value);
    }
    catch{if(mounted.current&&run===generation.current)setError('No pudimos abrir el video. No se ha revisado.');}
    finally{if(mounted.current&&run===generation.current)setBusy(false);}
  }
  useEffect(()=>{
    const video=videoRef.current;if(!video||!preview)return;
    let hls:Hls|undefined;
    const failed=()=>{setPlayingReady(false);setWatched(false);setError('La reproducción se interrumpió. Vuelve a abrir el video.');};
    video.muted=true;
    if(video.canPlayType('application/vnd.apple.mpegurl'))video.src=preview.hls;
    else if(Hls.isSupported()){hls=new Hls({enableWorker:false,debug:false});hls.loadSource(preview.hls);hls.attachMedia(video);hls.on(Hls.Events.ERROR,(_event,data)=>{if(data.fatal)failed();});}
    else failed();
    const timeout=setTimeout(()=>{video.pause();setPreview(undefined);setWatched(false);setPlayingReady(false);setError('La autorización del video venció. Vuelve a abrirlo para continuar.');},Math.max(0,preview.expires_at*1000-Date.now()));
    const background=()=>{if(document.hidden){video.pause();setWatched(false);}else if(selected){void open(selected);}};
    document.addEventListener('visibilitychange',background);
    return()=>{clearTimeout(timeout);document.removeEventListener('visibilitychange',background);video.pause();hls?.destroy();video.removeAttribute('src');video.load();};
    // Selecting or renewing a preview always creates a fresh authorized media lifecycle.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  },[preview]);
  async function review(decision:'approved'|'rejected') {
    if(!selected||selected.technical_state!=='ready'||!preview||!watched||!playingReady||busy||preview.expires_at*1000<=Date.now()||!Number.isSafeInteger(selected.current_parent_version))return;
    const run=++generation.current;setBusy(true);setError('');setNotice('');
    try{await api.review(selected,decision,note);const items=await api.list();if(mounted.current&&run===generation.current){setRows(items);setSelected(undefined);setPreview(undefined);setWatched(false);setNotice(decision==='approved'?'Video aprobado. La publicación también depende del expediente.':'Video rechazado.');}}
    catch{if(mounted.current&&run===generation.current){setWatched(false);setError('No pudimos guardar la revisión. Recarga el expediente y reproduce el video otra vez.');}}
    finally{if(mounted.current&&run===generation.current)setBusy(false);}
  }
  const canReview=watched&&playingReady&&!!preview&&!busy&&selected?.technical_state==='ready'&&Number.isSafeInteger(selected?.current_parent_version);
  return <section aria-label="Revisión de videos"><h2>Videos</h2><p>El procesamiento y la aprobación son pasos separados. La evidencia financiera permanece privada.</p>
    {error&&<p role="alert">{error}</p>}{notice&&<p role="status">{notice}</p>}
    <ul>{rows.map(row=><li key={row.id}><button disabled={busy} onClick={()=>void open(row)}>{purposes[row.purpose]??'Video'} · {row.technical_state==='ready'?'Procesado':row.technical_state==='failed'?'No procesado':'En procesamiento'}</button></li>)}</ul>
    {selected&&<div><h3>{purposes[selected.purpose]??'Video'}</h3><p>Expediente {selected.parent_id}. Versión {selected.current_parent_version}.</p>
      {preview&&<video ref={videoRef} aria-label="Video para revisión" controls playsInline muted poster={preview.poster} onCanPlay={()=>setPlayingReady(true)} onError={()=>{setPlayingReady(false);setWatched(false);setError('No pudimos reproducir el clip. No se ha revisado.');}} onEnded={event=>setWatched(playedWholeClip(event.currentTarget))}/>}
      <p>{watched?'Reproducción completa comprobada.':'Reproduce el video completo antes de guardar la revisión.'}</p>
      <button disabled={busy} onClick={()=>void open(selected)}>Volver a abrir video</button>
      <label>Observaciones<textarea value={note} maxLength={1000} onChange={event=>setNote(event.target.value)}/></label>
      <button disabled={!canReview} onClick={()=>void review('approved')}>Aprobar video</button><button disabled={!canReview} onClick={()=>void review('rejected')}>Rechazar video</button>
    </div>}
  </section>;
}
