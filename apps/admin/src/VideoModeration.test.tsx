import {afterEach,describe,expect,it,vi} from 'vitest';
import {act,cleanup,fireEvent,render,screen,waitFor} from '@testing-library/react';
import VideoModeration,{createVideoModerationApi,playedWholeClip,type VideoModerationApi,type VideoReviewRow,type VideoPreview} from './VideoModeration';
vi.mock('hls.js',()=>({default:class {static isSupported(){return false;}static Events={ERROR:'error'};}}));
afterEach(()=>{cleanup();vi.restoreAllMocks();});
const row:VideoReviewRow={id:'asset',parent_id:'case',parent_version:1,current_parent_version:3,purpose:'thanks',technical_state:'ready',moderation_state:'pending',duration:4};
function fixture(overrides:Partial<VideoModerationApi>={}) {
  let listener=()=>{};
  const api:VideoModerationApi={list:vi.fn(async()=>[row]),playback:vi.fn(async()=>({hls:'https://videodelivery.net/signed/manifest/video.m3u8',poster:'https://videodelivery.net/signed/thumbnails/thumbnail.jpg',expires_at:Math.floor(Date.now()/1000)+120})),review:vi.fn(async()=>{}),watch:callback=>{listener=callback;return ()=>{};},...overrides};
  vi.spyOn(HTMLMediaElement.prototype,'canPlayType').mockReturnValue('probably');vi.spyOn(HTMLMediaElement.prototype,'pause').mockImplementation(()=>{});vi.spyOn(HTMLMediaElement.prototype,'load').mockImplementation(()=>{});
  return {api,changed:()=>listener()};
}
async function opened(api:VideoModerationApi){render(<VideoModeration api={api}/>);fireEvent.click(await screen.findByRole('button',{name:'Agradecimiento · Procesado'}));await screen.findByLabelText('Video para revisión');return screen.getByLabelText('Video para revisión') as HTMLVideoElement;}
function whole(video:HTMLVideoElement){Object.defineProperty(video,'duration',{configurable:true,value:4});Object.defineProperty(video,'played',{configurable:true,value:{length:1,start:()=>0,end:()=>4}});fireEvent.canPlay(video);fireEvent.ended(video);}
function deferred<T>(){let resolve!:(value:T)=>void;const promise=new Promise<T>(done=>{resolve=done;});return {promise,resolve};}
describe('video moderation contracts, not a real browser decoder test',()=>{
 it('a signed poster and readiness alone never permit review',async()=>{const {api}=fixture();const video=await opened(api);expect(screen.getByRole('button',{name:'Aprobar video'})).toBeDisabled();fireEvent.canPlay(video);fireEvent.ended(video);expect(screen.getByRole('button',{name:'Aprobar video'})).toBeDisabled();expect(api.review).not.toHaveBeenCalled();});
 it('reviews the current parent version only after full played range, with note',async()=>{const {api}=fixture();const video=await opened(api);whole(video);fireEvent.change(screen.getByLabelText('Observaciones'),{target:{value:'Clip contrastado con expediente'}});fireEvent.click(screen.getByRole('button',{name:'Aprobar video'}));await waitFor(()=>expect(api.review).toHaveBeenCalledWith(row,'approved','Clip contrastado con expediente'));});
 it('refreshes a processing list row before reviewing the now ready video at its current parent version',async()=>{
  const processing={...row,technical_state:'processing'},current={...row,current_parent_version:4};
  const {api}=fixture({list:vi.fn().mockResolvedValueOnce([processing]).mockResolvedValue([current])});
  render(<VideoModeration api={api}/>);fireEvent.click(await screen.findByRole('button',{name:'Agradecimiento · En procesamiento'}));
  const video=await screen.findByLabelText('Video para revisión') as HTMLVideoElement;whole(video);
  expect(screen.getByRole('button',{name:'Aprobar video'})).toBeEnabled();
  fireEvent.click(screen.getByRole('button',{name:'Aprobar video'}));
  await waitFor(()=>expect(api.review).toHaveBeenCalledWith(current,'approved',''));
 });
 it('refreshes again on reopening and requires the new playback before reviewing its latest version',async()=>{
  const first={...row,current_parent_version:4},latest={...row,current_parent_version:5};
  const {api}=fixture({list:vi.fn().mockResolvedValueOnce([row]).mockResolvedValueOnce([first]).mockResolvedValue([latest])});
  whole(await opened(api));fireEvent.click(screen.getByRole('button',{name:'Volver a abrir video'}));
  const video=await screen.findByLabelText('Video para revisión') as HTMLVideoElement;
  expect(screen.getByRole('button',{name:'Aprobar video'})).toBeDisabled();expect(api.review).not.toHaveBeenCalled();
  whole(video);fireEvent.click(screen.getByRole('button',{name:'Aprobar video'}));
  await waitFor(()=>expect(api.review).toHaveBeenCalledWith(latest,'approved',''));
 });
 it.each([
  ['withdrawn',[]],['still processing',[{...row,technical_state:'processing'}]],
  ['another parent',[{...row,parent_id:'another-case'}]],['invalid current version',[{...row,current_parent_version:NaN}]],
 ] as const)('does not reuse the old row when refreshed data is %s',async(_reason,items)=>{
  const {api}=fixture({list:vi.fn().mockResolvedValueOnce([row]).mockResolvedValue([...items])});
  render(<VideoModeration api={api}/>);fireEvent.click(await screen.findByRole('button',{name:'Agradecimiento · Procesado'}));
  expect(await screen.findByRole('alert')).toHaveTextContent('No pudimos abrir el video. No se ha revisado.');
  expect(screen.queryByLabelText('Video para revisión')).toBeNull();expect(screen.queryByRole('button',{name:'Aprobar video'})).toBeNull();
  expect(api.playback).not.toHaveBeenCalled();expect(api.review).not.toHaveBeenCalled();
 });
 it('fails closed when refreshing the selected row fails',async()=>{
  const {api}=fixture({list:vi.fn().mockResolvedValueOnce([row]).mockRejectedValue(new Error('refresh unavailable'))});
  render(<VideoModeration api={api}/>);fireEvent.click(await screen.findByRole('button',{name:'Agradecimiento · Procesado'}));
  expect(await screen.findByRole('alert')).toHaveTextContent('No pudimos abrir el video. No se ha revisado.');
  expect(api.playback).not.toHaveBeenCalled();expect(api.review).not.toHaveBeenCalled();expect(screen.queryByLabelText('Video para revisión')).toBeNull();
 });
 it('does not start playback from a row refresh completed after an account change',async()=>{
  const pending=deferred<VideoReviewRow[]>();const {api,changed}=fixture({list:vi.fn().mockResolvedValueOnce([row]).mockReturnValue(pending.promise)});
  render(<VideoModeration api={api}/>);fireEvent.click(await screen.findByRole('button',{name:'Agradecimiento · Procesado'}));
  await waitFor(()=>expect(api.list).toHaveBeenCalledTimes(2));changed();pending.resolve([{...row,current_parent_version:9}]);
  await waitFor(()=>expect(screen.getByRole('alert')).toHaveTextContent('Tu sesión cambió'));
  expect(api.playback).not.toHaveBeenCalled();expect(api.review).not.toHaveBeenCalled();expect(screen.queryByLabelText('Video para revisión')).toBeNull();
 });
 it('does not replace a newer selection with the late playback of the previous API',async()=>{
  const pending=deferred<VideoPreview>();const old=fixture({playback:vi.fn(()=>pending.promise)});
  const current={...row,id:'new-asset',parent_id:'new-case',current_parent_version:9,purpose:'farewell'};
  const next=fixture({list:vi.fn(async()=>[current])});const view=render(<VideoModeration api={old.api}/>);
  fireEvent.click(await screen.findByRole('button',{name:'Agradecimiento · Procesado'}));await waitFor(()=>expect(old.api.playback).toHaveBeenCalled());
  view.rerender(<VideoModeration api={next.api}/>);fireEvent.click(await screen.findByRole('button',{name:'Despedida · Procesado'}));
  const video=await screen.findByLabelText('Video para revisión') as HTMLVideoElement;
  await act(async()=>pending.resolve({hls:'https://videodelivery.net/old/manifest/video.m3u8',poster:'https://videodelivery.net/old/poster.jpg',expires_at:Math.floor(Date.now()/1000)+120}));
  expect(video).toHaveAttribute('poster','https://videodelivery.net/signed/thumbnails/thumbnail.jpg');
  whole(video);fireEvent.click(screen.getByRole('button',{name:'Aprobar video'}));
  await waitFor(()=>expect(next.api.review).toHaveBeenCalledWith(current,'approved',''));expect(old.api.review).not.toHaveBeenCalled();
 });
 it('does not restore a late preview after account changes',async()=>{let resolve!:(value:unknown)=>void;const pending=new Promise(resolveValue=>{resolve=resolveValue;});const {api,changed}=fixture({playback:vi.fn(()=>pending as ReturnType<VideoModerationApi['playback']>)});render(<VideoModeration api={api}/>);fireEvent.click(await screen.findByRole('button',{name:'Agradecimiento · Procesado'}));await waitFor(()=>expect(api.playback).toHaveBeenCalledWith(row.id));changed();resolve({hls:'https://videodelivery.net/old/manifest/video.m3u8',poster:'https://videodelivery.net/old/poster.jpg',expires_at:Math.floor(Date.now()/1000)+120});await waitFor(()=>expect(screen.getByRole('alert')).toHaveTextContent('Tu sesión cambió'));expect(screen.queryByLabelText('Video para revisión')).toBeNull();});
 it('rejects ended after seeking across unplayed content',()=>{const video={duration:10,played:{length:2,start:(index:number)=>index===0?0:9,end:(index:number)=>index===0?1:10}} as HTMLVideoElement;expect(playedWholeClip(video)).toBe(false);});
 it('ignores initial-session/token refresh but invalidates after actor changes',()=>{
   let callback!:(event:string,session:unknown)=>void;const unsub=vi.fn();const api=createVideoModerationApi({auth:{onAuthStateChange:(fn:typeof callback)=>{callback=fn;return {data:{subscription:{unsubscribe:unsub}}};}}} as never);
   const listener=vi.fn(),stop=api.watch(listener);const session=(id:string)=>({user:{id},access_token:`a.${btoa(JSON.stringify({session_id:'session'}))}.c`});
   callback('INITIAL_SESSION',session('one'));callback('TOKEN_REFRESHED',session('one'));expect(listener).not.toHaveBeenCalled();callback('SIGNED_IN',session('two'));expect(listener).toHaveBeenCalledTimes(1);stop();expect(unsub).toHaveBeenCalled();
 });
 it('sends backend review version instead of upload origin version',async()=>{const invoke=vi.fn(async()=>({data:{ok:true},error:null}));const api=createVideoModerationApi({functions:{invoke}} as never);await api.review(row,'rejected','Otro expediente');expect(invoke).toHaveBeenCalledWith('video-media',{body:{action:'review',id:'asset',parent_version:3,decision:'rejected',note:'Otro expediente'}});});
});
