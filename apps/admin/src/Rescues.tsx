import { useEffect, useRef, useState } from 'react';
import { errorMessage, type AdminApi, type InitialCaseDecision, type NeedCommentInput, type RescueDetail, type RescueRecord } from './api';
import NeedFeedback, { CommentHistory, needKey, validateNeedComments } from './NeedFeedback';
import { mergeInitialPacketPage, packetExpenseReviews, type ExpenseReviewDraft, type InitialPacketCache } from './initialCasePacket';
import { Fields, roles, money, text, title, date } from './rescuePresentation';
import CaseRevisionReview from './CaseRevisionReview';

export const rescueStatus: Record<string,string> = {submitted:'En revisión',changes_requested:'Con correcciones',approved:'Aprobados',rejected:'No aprobados',closed:'Casos cerrados'};
const kinds: Record<string,string> = {verification:'Verificaciones',case:'Casos'};
function message(cause: unknown) { if(typeof cause==='object'&&cause&&'code' in cause&&'message' in cause&&['22023','40001'].includes(String(cause.code))) return String(cause.message); return errorMessage(cause); }
type ReviewSelection = { id: string; revisionId?: string };
export default function Rescues({api,initialKind='case'}:{api:AdminApi;initialKind?:'case'|'verification'}) {
  const [kind,setKind]=useState<string>(initialKind),[status,setStatus]=useState('submitted'),[page,setPage]=useState(1),[revision,setRevision]=useState(0);
  const [data,setData]=useState<{total:number;items:RescueRecord[]}>({total:0,items:[]}),[selected,setSelected]=useState<ReviewSelection|null>(null);
  const [loading,setLoading]=useState(true),[error,setError]=useState('');
  const [reviewLocked,setReviewLocked]=useState(false);
  useEffect(()=>{setKind(initialKind);setPage(1);},[initialKind]);
  useEffect(()=>{let alive=true;setLoading(true);setData({total:0,items:[]});setSelected(null);setReviewLocked(false);setError('');
    api.listRescue(kind,status,page).then(r=>{if(alive)setData(r);}).catch(e=>{if(alive)setError(message(e));}).finally(()=>{if(alive)setLoading(false);});return()=>{alive=false;};
  },[api,kind,status,page,revision]);
  return <><header className="page-heading"><div><p className="eyebrow">Confianza y transparencia</p><h1>Casos y necesidades</h1><p>Consulta el expediente, sus necesidades y la evidencia. El sello Dopmi es opcional.</p></div><span className="read-only">Revisión privada</span></header>
    <section className="users-card"><div className="table-toolbar"><div><h2>Solicitudes del equipo rescatista</h2><p aria-live="polite">{loading?'Consultando…':`${data.total} solicitudes`}</p></div><div className="moderation-filters">
      <label>Tipo<select disabled={reviewLocked} value={kind} onChange={e=>{setKind(e.target.value);setPage(1);}}>{Object.entries(kinds).map(([v,l])=><option key={v} value={v}>{l}</option>)}</select></label>
      <label>Estado<select disabled={reviewLocked} value={status} onChange={e=>{setStatus(e.target.value);setPage(1);}}>{Object.entries(rescueStatus).map(([v,l])=><option key={v} value={v}>{l}</option>)}</select></label>
      <button className="secondary" disabled={reviewLocked} onClick={()=>setRevision(v=>v+1)}>Actualizar</button></div></div>
      {error?<div className="empty-state"><div role="alert" className="notice">{error}</div><button onClick={()=>setRevision(v=>v+1)}>Volver a intentar</button></div>:loading?<div className="empty-state" role="status">Cargando solicitudes…</div>:!data.items.length?<div className="empty-state"><span className="empty-icon" aria-hidden="true">♡</span><h2>Todo al día por aquí</h2><p>No hay solicitudes con estos filtros.</p></div>:<div className="table-scroll"><table className="rescue-table"><thead><tr><th>Solicitud</th><th>Envío</th><th>Versión</th><th>Revisión</th></tr></thead><tbody>{data.items.map(r=><tr key={r.revision_id??r.id}><td data-label="Solicitud"><strong>{title(r)}</strong><small>{r.review_kind==='revision'?'Edición del caso':text(r.public_data.city)}</small>{r.review_kind==='revision'&&<small className="authored-text">Motivo: {r.reason}</small>}</td><td data-label="Envío">{date(r.submitted_at)}</td><td data-label="Versión">{r.review_kind==='revision'?r.revision_version:r.version}</td><td data-label="Revisión"><button className="text-button" disabled={reviewLocked||r.review_kind==='revision'&&!r.revision_id} onClick={()=>setSelected({id:r.id,revisionId:r.review_kind==='revision'?r.revision_id:undefined})}>{r.review_kind==='revision'?`Revisar edición de ${title(r)}`:`Revisar ${title(r)}`}</button></td></tr>)}</tbody></table></div>}
      <footer className="pagination"><span>Página {page} de {Math.max(1,Math.ceil(data.total/20))}</span><div><button className="secondary" disabled={reviewLocked||loading||page===1} onClick={()=>setPage(p=>p-1)}>Anterior</button><button className="secondary" disabled={reviewLocked||loading||page*20>=data.total} onClick={()=>setPage(p=>p+1)}>Siguiente</button></div></footer>
    </section>
    {selected&&(selected.revisionId?<CaseRevisionReview key={selected.revisionId} api={api} caseId={selected.id} revisionId={selected.revisionId} close={()=>{setSelected(null);setReviewLocked(false);}} updated={()=>setRevision(v=>v+1)} lock={setReviewLocked} denied={()=>{setSelected(null);setReviewLocked(false);setData({total:0,items:[]});setError('El acceso cambió. Actualiza la lista para volver a comprobarlo.');}}/>:<RescueReview key={selected.id} api={api} id={selected.id} close={()=>{setSelected(null);setReviewLocked(false);}} updated={()=>setRevision(v=>v+1)} openParent={id=>setSelected({id})} lock={setReviewLocked} denied={()=>{setSelected(null);setReviewLocked(false);setData({total:0,items:[]});setError('El acceso cambió. Actualiza la lista para volver a comprobarlo.');}}/>)}
  </>;
}

type CommentAttempt = { requestId: string; record: { id: string; version: number }; comments: NeedCommentInput[] };
type PacketAttempt = { record: { id: string; version: number }; decision: InitialCaseDecision };
function packetIdentity(detail: RescueDetail) {
  return JSON.stringify([detail.initial_packet,detail.expenses?.total,detail.expenses?.page,[detail.record,...(detail.expenses?.items??[])].map(record=>({
    id:record.id,owner:record.owner_id,parent:record.parent_id,kind:record.kind,
    version:record.version,status:record.status,
    files:record.files.map(file=>`${file.role}:${file.path}`).sort(),
  })).sort((a,b)=>a.id.localeCompare(b.id))]);
}
function deniedFile(cause: unknown) {
  const error=cause as {code?:unknown;status?:unknown;statusCode?:unknown}|null;
  return error?.code==='42501'||String(error?.status)==='403'||String(error?.statusCode)==='403';
}

function RescueReview({api,id,close,updated,openParent,denied,lock}:{api:AdminApi;id:string;close:()=>void;updated:()=>void;openParent:(id:string)=>void;denied:()=>void;lock:(locked:boolean)=>void}) {
  const dialog=useRef<HTMLDialogElement>(null), generation=useRef(0), saving=useRef(false);
  const packetCache=useRef<InitialPacketCache|null>(null);
  const [packetRecords,setPacketRecords]=useState<Record<string,RescueRecord>>({}),[expenseDrafts,setExpenseDrafts]=useState<Record<string,ExpenseReviewDraft>>({});
  const [packetAttempt,setPacketAttempt]=useState<PacketAttempt|null>(null);
  const [detail,setDetail]=useState<RescueDetail|null>(null),[urls,setUrls]=useState<Record<string,string>>({});
  const [fileErrors,setFileErrors]=useState<Record<string,string>>({});
  const [seen,setSeen]=useState<string[]>([]),[loaded,setLoaded]=useState<string[]>([]),[published,setPublished]=useState(false);
  const [retry,setRetry]=useState(0),[expensePage,setExpensePage]=useState(1),[loading,setLoading]=useState(true),[busy,setBusy]=useState(false),[commentBusy,setCommentBusy]=useState(false),[error,setError]=useState('');
  const [note,setNote]=useState('');
  const [drafts,setDrafts]=useState<Record<string,NeedCommentInput>>({}),[attempt,setAttempt]=useState<CommentAttempt|null>(null),[saved,setSaved]=useState(false);
  const dirty=Object.values(drafts).some(comment=>comment.body.length>0), protectedComments=dirty||attempt!==null;
  const blocked=busy||commentBusy||attempt!==null||packetAttempt!==null;
  useEffect(()=>{dialog.current?.showModal();},[]);
  useEffect(()=>{setDrafts({});setAttempt(null);setCommentBusy(false);setSaved(false);saving.current=false;setPacketAttempt(null);},[api,id]);
  useEffect(()=>{packetCache.current=null;setPacketRecords({});setExpenseDrafts({});setSeen([]);setLoaded([]);setPublished(false);setNote('');},[api,id,retry]);
  useEffect(()=>{lock(busy||commentBusy||protectedComments||packetAttempt!==null);},[busy,commentBusy,protectedComments,packetAttempt,lock]);
  useEffect(()=>{
    if(!protectedComments&&!commentBusy&&!packetAttempt)return;
    const beforeUnload=(event:BeforeUnloadEvent)=>{event.preventDefault();event.returnValue='';};
    window.addEventListener('beforeunload',beforeUnload);
    return()=>window.removeEventListener('beforeunload',beforeUnload);
  },[protectedComments,commentBusy,packetAttempt]);
  useEffect(()=>{
    const current=++generation.current;
    setLoading(true);setError('');setDetail(null);setUrls({});setFileErrors({});
    if(!packetCache.current){setSeen([]);setLoaded([]);setPublished(false);setNote('');}
    api.rescueDetail(id,expensePage).then(async value=>{
      if(current!==generation.current)return;
      const records=[value.record,...(value.expenses?.items??[])];
      const paths=[...new Set(records.flatMap(record=>record.files.map(file=>file.path)))];
      const signed=await Promise.allSettled(paths.map(path=>api.rescueFileUrl(path)));
      if(current!==generation.current)return;
      if(signed.some(result=>result.status==='rejected'&&deniedFile(result.reason)))throw {code:'42501'};
      let verified=value;
      if(signed.some(result=>result.status==='rejected')){
        // A missing object can also conceal revoked access. Revalidate once;
        // partial results are safe only while the same packet remains visible.
        verified=await api.rescueDetail(id,expensePage);
        if(current!==generation.current)return;
        if(packetIdentity(verified)!==packetIdentity(value))throw {code:'40001',message:'El expediente cambió. Recarga antes de continuar.'};
      }
      if(verified.initial_packet){
        const cache=mergeInitialPacketPage(packetCache.current,verified);
        packetCache.current=cache;setPacketRecords(cache.records);
      } else if(packetCache.current) throw {code:'40001',message:'El paquete inicial cambió. Recarga el expediente antes de continuar.'};
      setDetail(verified);
      setUrls(Object.fromEntries(signed.flatMap((result,index)=>result.status==='fulfilled'?[[paths[index],result.value]]:[])));
      setFileErrors(Object.fromEntries(signed.flatMap((result,index)=>result.status==='rejected'?[[paths[index],'Archivo no disponible. Puedes volver a intentarlo.']]:[])));
      const failed=paths.filter((_,index)=>signed[index].status==='rejected');
      setSeen(value=>value.filter(path=>!failed.includes(path)));setLoaded(value=>value.filter(path=>!failed.includes(path)));
    }).catch(cause=>{if(current===generation.current){if(deniedFile(cause)&&cause?.message!=='Otra persona del equipo debe revisar tu solicitud'){purgePrivate();denied();}else{if(cause?.code==='40001')purgePrivate();setError(message(cause));}}}).finally(()=>{if(current===generation.current)setLoading(false);});
    // Any actor/API change or unmount invalidates reads AND writes in flight.
    return()=>{generation.current++;};
    // eslint-disable-next-line react-hooks/exhaustive-deps
  },[api,id,retry,expensePage]);
  const r=detail?.record;
  const initial=detail?.initial_packet;
  const commentsEnabled=!!r&&r.kind==='case'&&!!detail?.expenses&&Array.isArray(detail.need_comments)&&!!api.saveNeedComments;
  const fileReady=(path:string)=>loaded.includes(path)&&seen.includes(path)&&!fileErrors[path];
  const expenseReviews=initial?packetExpenseReviews(initial,packetRecords,expenseDrafts,fileReady):null;
  const canApprove=!!r&&r.kind!=='expense'&&r.status==='submitted'&&published&&r.files.every(file=>!!urls[file.path]&&fileReady(file.path))&&(r.kind!=='case'||!!initial)&&(!initial||!!api.reviewInitialCasePacket&&expenseReviews!==null);
  function purgePrivate() {
    packetCache.current=null;setPacketRecords({});setExpenseDrafts({});setPacketAttempt(null);setDrafts({});setAttempt(null);setDetail(null);setUrls({});setFileErrors({});setSeen([]);setLoaded([]);setNote('');setPublished(false);
  }
  function updateExpense(id:string,patch:Partial<ExpenseReviewDraft>) {
    setExpenseDrafts(value=>({...value,[id]:{...(value[id]??{urgent:false,urgency:''}),...patch}}));
  }
  function leave(action:()=>void) {
    if(blocked||saving.current)return;
    if(protectedComments){setError('Guarda los comentarios o descártalos antes de cerrar, recargar o cambiar de página.');return;}
    action();
  }
  function unavailableFile(path:string) {
    return <div className="notice" role="alert"><p>{fileErrors[path]}</p><button className="secondary" disabled={blocked} onClick={()=>leave(()=>setRetry(value=>value+1))}>Reintentar archivo</button></div>;
  }
  function feedback(kind:NeedCommentInput['target_kind'],targetId:string,targetVersion:number,targetTitle:string) {
    if(!commentsEnabled||!r)return null;
    const key=needKey(kind,targetId);
    return <NeedFeedback kind={kind} id={targetId} version={targetVersion} caseId={r.id} caseVersion={r.version} title={targetTitle} comments={detail!.need_comments!} value={drafts[key]?.body??''} disabled={blocked} editable={r.status==='submitted'} onChange={body=>{setSaved(false);setDrafts(value=>({...value,[key]:{target_kind:kind,target_id:targetId,target_version:targetVersion,body}}));}}/>;
  }
  async function saveComments() {
    if(!r||!commentsEnabled||!api.saveNeedComments||saving.current||busy)return;
    const current=generation.current;
    const batch=attempt??{requestId:crypto.randomUUID(),record:{id:r.id,version:r.version},comments:Object.values(drafts).filter(comment=>comment.body.trim()).map(comment=>({...comment,body:comment.body.trim()}))};
    const validation=validateNeedComments(batch.comments);
    if(validation){setError(validation);return;}
    saving.current=true;setCommentBusy(true);setAttempt(batch);setError('');setSaved(false);
    try {
      const result=await api.saveNeedComments(batch.record,batch.comments,batch.requestId);
      if(current!==generation.current)return;
      if(result.request_id!==batch.requestId||result.record_id!==batch.record.id||result.case_version!==batch.record.version||!Array.isArray(result.comments))throw new Error('invalid_response');
      setDetail(value=>value&&value.record.id===batch.record.id&&value.record.version===batch.record.version?{...value,need_comments:[...new Map([...result.comments,...(value.need_comments??[])].map(comment=>[comment.id,comment])).values()].slice(0,100)}:value);
      setDrafts({});setAttempt(null);setSaved(true);
    } catch(cause) {
      if(current!==generation.current)return;
      const code=(cause as {code?:string})?.code;
      if(deniedFile(cause)){purgePrivate();denied();}
      else if(code==='40001'){
        purgePrivate();
        setError('El expediente o una necesidad cambió. Recarga el expediente antes de escribir comentarios nuevos.');
      } else if(code==='22023') {setAttempt(null);setError('No pudimos guardar estos comentarios. Revisa su contenido y vuelve a intentarlo.');}
      else setError('No pudimos confirmar el guardado. Reintenta el mismo envío antes de continuar; tus comentarios siguen aquí.');
    } finally {
      if(current===generation.current){saving.current=false;setCommentBusy(false);}
    }
  }
  async function decide(decision:string) {
    if(!r||r.kind==='expense'||blocked||saving.current)return;
    if(protectedComments){setError('Guarda los comentarios antes de registrar la decisión.');return;}
    if(note.trim().length<5){setError('Escribe un motivo de al menos 5 caracteres.');return;}
    if(decision==='approved'&&!canApprove)return;
    if(initial){
      if(!api.reviewInitialCasePacket)return;
      await sendPacket({record:{id:r.id,version:r.version},decision:{submission_id:initial.id,request_id:crypto.randomUUID(),decision,note:note.trim(),publish_content:published,expense_reviews:decision==='approved'?expenseReviews!:[]}});
      return;
    }
    const current=generation.current;
    setBusy(true);setError('');
    try{await api.reviewRescue(r,{decision,note:note.trim(),amount_cents:0,is_urgent:false,urgency_note:'',publish_content:published});if(current===generation.current){updated();close();}}
    catch(cause){if(current===generation.current){if((cause as {code?:string;message?:string})?.code==='42501'&&(cause as {message?:string})?.message!=='Otra persona del equipo debe revisar tu solicitud')denied();else{setError(message(cause));if((cause as {code?:string})?.code==='40001'){setDetail(null);setUrls({});}}}}
    finally{if(current===generation.current)setBusy(false);}
  }
  async function sendPacket(batch:PacketAttempt) {
    if(!api.reviewInitialCasePacket||busy||saving.current)return;
    const current=generation.current;
    saving.current=true;setBusy(true);setPacketAttempt(batch);setError('');
    try {
      const result=await api.reviewInitialCasePacket(batch.record,batch.decision);
      if(current!==generation.current)return;
      if(result.request_id!==batch.decision.request_id||result.submission_id!==batch.decision.submission_id||result.record_id!==batch.record.id||result.case_version!==batch.record.version||result.decision!==batch.decision.decision||result.record?.id!==batch.record.id||result.record.status!==batch.decision.decision||result.record.version<=batch.record.version||!Array.isArray(result.expenses))throw new Error('invalid_response');
      if(batch.decision.decision==='approved'&&(result.expenses.length!==batch.decision.expense_reviews.length||batch.decision.expense_reviews.some(review=>!result.expenses.some(expense=>expense.id===review.expense_id&&expense.version>review.expense_version&&expense.status==='approved'&&expense.reimbursable_cents===review.amount_cents&&expense.urgent===review.is_urgent&&expense.priority_reason===review.urgency_note))))throw new Error('invalid_response');
      updated();close();
    } catch(cause) {
      if(current!==generation.current)return;
      const code=(cause as {code?:string})?.code;
      if(deniedFile(cause)){purgePrivate();denied();}
      else if(code==='40001'){purgePrivate();setError('El expediente o una necesidad cambió. Recarga el paquete antes de registrar otra decisión.');}
      else if(code==='22023'){setPacketAttempt(null);setError(message(cause));}
      else setError('No pudimos confirmar la decisión del paquete. Reintenta el mismo envío antes de continuar; tus datos siguen aquí.');
    } finally {if(current===generation.current){saving.current=false;setBusy(false);}}
  }
  const expenseRecords=detail?.expenses?.items??[];
  const plannedIds=new Set(Array.isArray(r?.public_data.need_items)?r.public_data.need_items.flatMap((item:unknown)=>typeof item==='object'&&item!==null&&'id' in item&&typeof item.id==='string'?[item.id]:[]):[]);
  const outsideComments=commentsEnabled?detail!.need_comments!.filter(comment=>comment.case_id===r!.id&&!(comment.target_kind==='planned'?plannedIds.has(comment.target_id):expenseRecords.some(expense=>expense.id===comment.target_id))):[];
  return <dialog ref={dialog} className="rescue-dialog" onCancel={event=>{event.preventDefault();leave(close);}} aria-labelledby="rescue-review-title"><div className="dialog-header"><p className="eyebrow">Revisión de expediente</p><button className="text-button" disabled={blocked} onClick={()=>leave(close)}>Cerrar</button></div>
    <h2 id="rescue-review-title">{r?title(r):'Solicitud'}</h2>
    {error&&<div className="notice" role="alert">{error}</div>}
    <button className="secondary" disabled={blocked} onClick={()=>leave(()=>{setSaved(false);setRetry(value=>value+1);})}>Recargar expediente y archivos</button>
    {loading?<p role="status">Cargando documentos privados…</p>:r&&<>
      <p className="muted">Versión {r.version} · {rescueStatus[r.status]||r.status} · Enviado {date(r.submitted_at)}</p>
      <div className="notice">{detail.verified?'Sello Dopmi aprobado.':'Sin sello Dopmi. Esto no impide revisar esta solicitud.'}{r.parent_id&&<> Caso: {detail.case_status==='approved'?'aprobado y abierto':detail.case_status==='closed'?'cerrado':'requiere revisión'}. <button className="text-button" disabled={blocked} onClick={()=>leave(()=>openParent(r.parent_id!))}>Ver expediente del caso</button></>}</div>
      {r.feedback&&<p className="notice">Respuesta anterior: {r.feedback}</p>}
      <h3>Contenido para publicación</h3><p>Comprueba que los textos y fotos no expongan documentos, domicilios particulares ni otros datos privados.</p><Fields data={r.public_data} needFeedback={item=>typeof item.id==='string'?feedback('planned',item.id,r.version,text(item.title)):null}/>
      {Object.keys(r.private_data).length>0&&<><h3>Solo para revisión privada</h3><Fields data={r.private_data}/></>}
      <h3>Documentos y evidencia</h3><div className="rescue-documents">{r.files.map((file,index)=><section className="rescue-document" key={file.path}><h4>{roles[file.role]} · Archivo {index+1}</h4>
        {fileErrors[file.path]?unavailableFile(file.path):/\.pdf$/i.test(file.path)?<a href={urls[file.path]} target="_blank" rel="noreferrer" onClick={()=>setLoaded(value=>[...value,file.path])}>Abrir PDF {index+1}</a>:<a href={urls[file.path]} target="_blank" rel="noreferrer"><img alt={`${roles[file.role]} ${index+1}`} src={urls[file.path]} onLoad={()=>setLoaded(value=>[...value,file.path])} onError={()=>{setSeen(value=>value.filter(path=>path!==file.path));setLoaded(value=>value.filter(path=>path!==file.path));setError('Un archivo no pudo cargarse. Recarga los archivos antes de aprobar.');}}/></a>}
        <label className="check-label"><input type="checkbox" disabled={blocked||!loaded.includes(file.path)} checked={seen.includes(file.path)} onChange={event=>setSeen(value=>event.target.checked?[...value,file.path]:value.filter(path=>path!==file.path))}/>Revisé el archivo {index+1}</label>
      </section>)}</div>
      {(commentsEnabled||initial)&&<section className="case-expenses" aria-label="Gastos del caso">
        <h3>{initial?'Necesidades pagadas del caso':'Gastos enviados con este caso'}</h3><p>{initial?'Revisa todas las necesidades y sus archivos. Aprobar el caso autoriza los importes pagados completos que aparecen en esta versión. Si algo requiere corrección, devuelve el caso completo con tus comentarios.':'Consulta las necesidades, sus comprobantes y el historial del caso. La revisión se registra para el caso completo.'}</p>
        <p className="muted">{detail.expenses!.total} gastos accesibles · Página {detail.expenses!.page} de {Math.max(1,Math.ceil(detail.expenses!.total/20))}</p>
        {initial&&<p role="status">{Object.keys(packetRecords).length} de {initial.expense_ids.length} necesidades consultadas. Los archivos revisados y la prioridad se conservan al cambiar de página.</p>}
        {!expenseRecords.length&&<p>No hay gastos enviados accesibles en esta página.</p>}
        {expenseRecords.map(expense=><article className="rescue-need case-expense" key={expense.id}>
          <div className="need-heading"><h4>{title(expense)}</h4><span className="badge">{initial?'Incluida en esta revisión':rescueStatus[expense.status]||expense.status}</span></div>
          <p className="muted">{initial?`Versión capturada ${expense.version}`:<>Gasto versión {expense.version} · Enviado {date(expense.submitted_at)}</>}</p>
          <Fields data={expense.public_data}/><Fields data={expense.private_data}/>
          {!initial&&expense.reimbursable_cents>0&&<p>Importe autorizado en el historial: {money(expense.reimbursable_cents)} · {expense.urgent?'Urgente':'Prioridad por antigüedad'}</p>}
          <div className="rescue-documents">{expense.files.map((file,index)=><section className="rescue-document" key={file.path}><h5>{roles[file.role]||'Evidencia privada'} · Archivo {index+1}</h5>
            {fileErrors[file.path]?unavailableFile(file.path):/\.pdf$/i.test(file.path)?<a href={urls[file.path]} target="_blank" rel="noreferrer" onClick={()=>{if(initial)setLoaded(value=>[...new Set([...value,file.path])]);}}>Abrir PDF de {title(expense)} · Archivo {index+1}</a>:<a href={urls[file.path]} target="_blank" rel="noreferrer"><img alt={`${roles[file.role]||'Evidencia privada'} de ${title(expense)} ${index+1}`} src={urls[file.path]} onLoad={()=>{if(initial)setLoaded(value=>[...new Set([...value,file.path])]);}} onError={()=>{if(initial){setSeen(value=>value.filter(path=>path!==file.path));setLoaded(value=>value.filter(path=>path!==file.path));setError('Un archivo no pudo cargarse. Recarga los archivos antes de aprobar.');}}}/></a>}
            {initial&&<label className="check-label"><input type="checkbox" disabled={blocked||!loaded.includes(file.path)} checked={seen.includes(file.path)} onChange={event=>setSeen(value=>event.target.checked?[...new Set([...value,file.path])]:value.filter(path=>path!==file.path))}/>Revisé el archivo {index+1} de {title(expense)}</label>}
          </section>)}</div>
          {feedback('expense',expense.id,expense.version,title(expense))}
          {initial&&<div className="initial-expense-review">
            <p aria-label={`Importe pagado de ${title(expense)}`}>Importe pagado: <strong>{money(Number(expense.private_data.amount_cents))}</strong>. Se autoriza completo al aprobar el caso.</p>
            <label className="check-label"><input type="checkbox" checked={expenseDrafts[expense.id]?.urgent??false} disabled={blocked} onChange={event=>updateExpense(expense.id,{urgent:event.target.checked})}/>Prioridad urgente para {title(expense)}</label>
            {expenseDrafts[expense.id]?.urgent&&<label>Motivo de prioridad para {title(expense)}<textarea value={expenseDrafts[expense.id]?.urgency??''} maxLength={1000} disabled={blocked} onChange={event=>updateExpense(expense.id,{urgency:event.target.value})}/></label>}
          </div>}
        </article>)}
        <nav className="pagination expense-pagination" aria-label="Páginas de gastos"><span>20 gastos por página</span><div>
          <button className="secondary" disabled={blocked||expensePage<=1} onClick={()=>leave(()=>setExpensePage(value=>value-1))}>Gastos anteriores</button>
          <button className="secondary" disabled={blocked||expensePage*20>=detail.expenses!.total} onClick={()=>leave(()=>setExpensePage(value=>value+1))}>Gastos siguientes</button>
        </div></nav>
      </section>}
      {commentsEnabled&&<section className="need-comment-save" aria-label="Guardar comentarios por necesidad">
        <h3>Comentarios por necesidad</h3><p>Se guardan como observaciones privadas de esta versión. Para registrar una decisión, guarda primero tus comentarios.</p>
        {outsideComments.length>0&&<details><summary>Comentarios de necesidades anteriores o de otra página</summary><CommentHistory comments={outsideComments}/></details>}
        {saved&&<p role="status">Comentarios guardados. La decisión del caso sigue pendiente.</p>}
        {r.status==='submitted'&&<div className="review-actions"><button disabled={busy||commentBusy||(!dirty&&!attempt)} onClick={()=>void saveComments()}>{commentBusy?'Guardando comentarios…':attempt?'Reintentar el mismo guardado':'Guardar comentarios'}</button>
          {dirty&&!attempt&&<button className="secondary" disabled={blocked} onClick={()=>{setDrafts({});setError('');}}>Descartar comentarios</button>}
        </div>}
        {protectedComments&&<p className="muted">{attempt?'Este envío debe confirmarse antes de editar, cerrar o registrar una decisión.':'Tienes comentarios sin guardar. Guárdalos o descártalos antes de salir o cambiar de página.'}</p>}
      </section>}
      {r.kind==='expense'&&<><p className="notice">Esta necesidad se consulta dentro del expediente de su caso. Las decisiones se registran para el caso completo.</p>{r.reimbursable_cents>0&&<p>Importe autorizado en el historial: {money(r.reimbursable_cents)} · {r.urgent?'Urgente':'Prioridad por antigüedad'}</p>}</>}
      {r.kind==='case'&&r.status==='submitted'&&!initial&&<p className="notice">Este envío anterior no tiene un conjunto capturado de necesidades. Devuelve el caso para que el rescatista lo reenvíe completo antes de aprobarlo.</p>}
      {r.kind!=='expense'&&['submitted','approved'].includes(r.status)&&<div className="rescue-decision">
        <label>Motivo de la decisión (visible para el rescatista)<textarea value={note} maxLength={2000} rows={3} disabled={blocked} onChange={event=>setNote(event.target.value)}/></label>
        {r.status==='submitted'&&<label className="check-label"><input type="checkbox" checked={published} disabled={blocked} onChange={event=>setPublished(event.target.checked)}/>{initial?'Autorizo los textos y las fotos marcadas para publicación del caso y de todas las necesidades de este paquete':'Autorizo los textos y las fotos marcadas para publicación'}</label>}
        {initial&&<p className="muted">Para aprobar el caso, consulta todas las páginas y revisa cada archivo. Los importes pagados se autorizan completos. La prioridad urgente es opcional y requiere un motivo.</p>}
        <div className="review-actions">{r.status==='submitted'&&<><button disabled={blocked||protectedComments||!canApprove} onClick={()=>void decide('approved')}>{r.kind==='case'?'Aprobar caso':'Aprobar solicitud'}</button><button className="secondary" disabled={blocked||protectedComments||!!initial&&!api.reviewInitialCasePacket} onClick={()=>void decide('rejected')}>No aprobar</button></>}
          <button className="secondary" disabled={blocked||protectedComments||!!initial&&!api.reviewInitialCasePacket} onClick={()=>void decide('changes_requested')}>{r.status==='approved'?'Retirar aprobación y pedir correcciones':'Pedir correcciones'}</button>
          {packetAttempt&&<button disabled={busy} onClick={()=>void sendPacket(packetAttempt)}>{busy?'Confirmando decisión…':'Reintentar la misma decisión del paquete'}</button>}</div>
        {r.status==='approved'&&<p className="muted">{r.kind==='verification'?'Pedir correcciones retira el sello Dopmi; los casos conservan su aprobación.':'Pedir correcciones retira la aprobación y oculta el caso hasta una nueva revisión.'}</p>}
      </div>}
      <h3>Historial (últimos 100 movimientos)</h3>{detail.history.length?detail.history.map(event=><article key={event.id} className="review-event"><strong>{rescueStatus[event.action]||({submit:'Enviado',withdraw:'Retirado a borrador',close:'Caso cerrado',need_comments:'Comentarios por necesidad'} as Record<string,string>)[event.action]||'Actualización'}</strong><small>{date(event.created_at)} · Versión revisada {event.version}</small><p className="authored-text">{event.feedback}</p>{event.reimbursable_cents>0&&<p>{money(event.reimbursable_cents)} · {event.urgent?'Urgente':'Por antigüedad'}</p>}</article>):<p>Sin decisiones anteriores.</p>}
      <p className="muted">La consulta de expedientes y las decisiones quedan registradas en el servidor. Los enlaces a archivos vencen en un minuto.</p>
    </>}
  </dialog>;
}
