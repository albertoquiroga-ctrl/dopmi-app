import { useEffect, useRef, useState } from 'react';
import { errorMessage, type AdminApi, type CaseRevisionDecision, type CaseRevisionExpense, type CaseRevisionPacket, type NeedCommentInput } from './api';
import NeedFeedback, { CommentHistory, needKey, validateNeedComments } from './NeedFeedback';
import { mergeRevisionPacketPage, revisionExpenseReviews, revisionPageIdentity, type RevisionPacketCache } from './caseRevisionPacket';
import type { ExpenseReviewDraft } from './initialCasePacket';
import { Fields, date, money, roles, text, title } from './rescuePresentation';

type CommentAttempt = { revision: { id: string; version: number }; caseId: string; caseVersion: number; requestId: string; comments: NeedCommentInput[] };
type DecisionAttempt = { revision: { id: string; version: number }; caseId: string; caseVersion: number; caseStatus: string; sourceExpenses: Record<string,CaseRevisionExpense>; decision: CaseRevisionDecision };
const changedRevisionMessage='La edición, una necesidad o sus medios cambiaron. Pide al rescatista retirar y reenviar la edición completa para actualizar sus documentos y medios antes de volver a revisarla.';
function denied(cause: unknown) {
  const value=cause as { code?: string; status?: number; statusCode?: number } | null;
  return value?.code==='42501'||String(value?.status)==='403'||String(value?.statusCode)==='403';
}
function message(cause: unknown) {
  const value=cause as {code?:string;message?:string}|null;
  return value?.message&&['22023','40001'].includes(value.code??'')?value.message:errorMessage(cause);
}

export default function CaseRevisionReview({api,caseId,revisionId,close,updated,lock,denied:accessDenied}:{api:AdminApi;caseId:string;revisionId:string;close:()=>void;updated:()=>void;lock:(locked:boolean)=>void;denied:()=>void}) {
  const dialog=useRef<HTMLDialogElement>(null),generation=useRef(0),saving=useRef(false),cache=useRef<RevisionPacketCache|null>(null);
  const [packet,setPacket]=useState<CaseRevisionPacket|null>(null),[records,setRecords]=useState<Record<string,CaseRevisionExpense>>({});
  const [urls,setUrls]=useState<Record<string,string>>({}),[fileErrors,setFileErrors]=useState<Record<string,string>>({});
  const [loaded,setLoaded]=useState<string[]>([]),[seen,setSeen]=useState<string[]>([]),[page,setPage]=useState(1),[reload,setReload]=useState(0);
  const [loading,setLoading]=useState(true),[busy,setBusy]=useState(false),[error,setError]=useState(''),[note,setNote]=useState(''),[publish,setPublish]=useState(false);
  const [publicationRejected,setPublicationRejected]=useState(false);
  const [priorities,setPriorities]=useState<Record<string,ExpenseReviewDraft>>({}),[comments,setComments]=useState<Record<string,NeedCommentInput>>({}),[saved,setSaved]=useState(false);
  const [commentAttempt,setCommentAttempt]=useState<CommentAttempt|null>(null),[decisionAttempt,setDecisionAttempt]=useState<DecisionAttempt|null>(null);
  const dirty=Object.values(comments).some(comment=>comment.body.length>0),protectedComments=dirty||commentAttempt!==null,blocked=busy||commentAttempt!==null||decisionAttempt!==null;
  useEffect(()=>{dialog.current?.showModal();},[]);
  useEffect(()=>{cache.current=null;setRecords({});setLoaded([]);setSeen([]);setPriorities({});setPublish(false);setPublicationRejected(false);setNote('');setComments({});setSaved(false);setCommentAttempt(null);setDecisionAttempt(null);setBusy(false);saving.current=false;},[api,caseId,revisionId,reload]);
  useEffect(()=>{lock(busy||protectedComments||decisionAttempt!==null);},[busy,protectedComments,decisionAttempt,lock]);
  useEffect(()=>{
    if(!protectedComments&&!decisionAttempt)return;
    const protect=(event:BeforeUnloadEvent)=>{event.preventDefault();event.returnValue='';};
    window.addEventListener('beforeunload',protect);return()=>window.removeEventListener('beforeunload',protect);
  },[protectedComments,decisionAttempt]);
  useEffect(()=>{
    const current=++generation.current;
    setLoading(true);setPacket(null);setUrls({});setFileErrors({});setError('');
    async function read() {
      if(!api.caseRevisionDetail)throw {code:'22023',message:'La revisión de ediciones no está disponible. Actualiza el panel antes de continuar.'};
      const value=await api.caseRevisionDetail(revisionId,page);
      if(current!==generation.current)return;
      if(value.revision.id!==revisionId||value.record.id!==caseId)throw {code:'40001',message:'La edición no corresponde al caso seleccionado.'};
      mergeRevisionPacketPage(cache.current,value);
      const paths=[...new Set([value.record,...value.expenses.items].flatMap(record=>record.files.map(file=>file.path)))];
      const signed=await Promise.allSettled(paths.map(path=>api.rescueFileUrl(path)));
      if(current!==generation.current)return;
      if(signed.some(result=>result.status==='rejected'&&denied(result.reason)))throw {code:'42501'};
      let verified=value;
      if(signed.some(result=>result.status==='rejected')){
        verified=await api.caseRevisionDetail(revisionId,page);
        if(current!==generation.current)return;
        if(revisionPageIdentity(verified)!==revisionPageIdentity(value))throw {code:'40001',message:'La edición cambió. Recarga antes de continuar.'};
      }
      const next=mergeRevisionPacketPage(cache.current,verified);
      cache.current=next;setRecords(next.records);setPacket(verified);
      setUrls(Object.fromEntries(signed.flatMap((result,index)=>result.status==='fulfilled'?[[paths[index],result.value]]:[])));
      setFileErrors(Object.fromEntries(signed.flatMap((result,index)=>result.status==='rejected'?[[paths[index],'Archivo no disponible. Recarga los archivos para volver a intentarlo.']]:[])));
      const failed=paths.filter((_,index)=>signed[index].status==='rejected');
      setLoaded(value=>value.filter(path=>!failed.includes(path)));setSeen(value=>value.filter(path=>!failed.includes(path)));
    }
    void read().catch(cause=>{
      if(current!==generation.current)return;
      if(denied(cause)){purge();accessDenied();}
      else if((cause as {code?:string})?.code==='40001'){purge();setError(changedRevisionMessage);}
      else setError(message(cause));
    }).finally(()=>{if(current===generation.current)setLoading(false);});
    return()=>{generation.current++;};
    // A reload resets the frozen cache; a page change retains seen evidence.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  },[api,caseId,revisionId,page,reload]);
  function purge() {
    cache.current=null;setPacket(null);setRecords({});setUrls({});setFileErrors({});setSeen([]);setLoaded([]);setPriorities({});setComments({});setCommentAttempt(null);setDecisionAttempt(null);setNote('');setPublish(false);setSaved(false);
  }
  function leave(action:()=>void) {
    if(blocked||saving.current)return;
    if(protectedComments){setError('Guarda los comentarios o descártalos antes de cerrar, recargar o cambiar de página.');return;}
    action();
  }
  const ready=(path:string)=>loaded.includes(path)&&seen.includes(path)&&!fileErrors[path];
  const reviews=packet?revisionExpenseReviews(packet,records,priorities,ready):null;
  const canApprove=!!packet&&!!api.reviewCaseRevision&&!publicationRejected&&packet.publication_blockers.length===0&&publish&&reviews!==null&&packet.record.files.every(file=>!!urls[file.path]&&ready(file.path));
  const commentsEnabled=!!api.saveCaseRevisionComments;
  function feedback(kind:NeedCommentInput['target_kind'],id:string,version:number,heading:string) {
    if(!packet||!commentsEnabled)return null;
    const key=needKey(kind,id);
    return <NeedFeedback kind={kind} id={id} version={version} caseId={caseId} caseVersion={packet.revision.base_case_version} title={heading} comments={packet.need_comments} value={comments[key]?.body??''} disabled={blocked} editable onChange={body=>{setSaved(false);setComments(value=>({...value,[key]:{target_kind:kind,target_id:id,target_version:version,body}}));}}/>;
  }
  async function saveComments() {
    if(!packet||!api.saveCaseRevisionComments||saving.current||busy||decisionAttempt)return;
    const current=generation.current;
    const batch=commentAttempt??{revision:{id:packet.revision.id,version:packet.revision.version},caseId,caseVersion:packet.revision.base_case_version,requestId:crypto.randomUUID(),comments:Object.values(comments).filter(comment=>comment.body.trim()).map(comment=>({...comment,body:comment.body.trim()}))};
    const invalid=validateNeedComments(batch.comments);if(invalid){setError(invalid);return;}
    saving.current=true;setBusy(true);setCommentAttempt(batch);setSaved(false);setError('');
    try {
      const result=await api.saveCaseRevisionComments(batch.revision,batch.comments,batch.requestId);
      if(current!==generation.current)return;
      if(result.request_id!==batch.requestId||result.revision_id!==batch.revision.id||result.revision_version!==batch.revision.version||result.record_id!==batch.caseId||result.case_version!==batch.caseVersion||!Array.isArray(result.comments))throw new Error('invalid_response');
      setPacket(value=>value?{...value,need_comments:[...new Map([...result.comments,...value.need_comments].map(comment=>[comment.id,comment])).values()].slice(0,100)}:value);
      setComments({});setCommentAttempt(null);setSaved(true);
    } catch(cause) {
      if(current!==generation.current)return;
      if(denied(cause)){purge();accessDenied();}
      else if((cause as {code?:string})?.code==='40001'){purge();setError(changedRevisionMessage);}
      else if((cause as {code?:string})?.code==='22023'){setCommentAttempt(null);setError(message(cause));}
      else setError('No pudimos confirmar los comentarios. Reintenta el mismo guardado antes de continuar.');
    } finally {if(current===generation.current){saving.current=false;setBusy(false);}}
  }
  async function decide(decision:string) {
    if(!packet||!api.reviewCaseRevision||blocked||protectedComments||saving.current)return;
    if(note.trim().length<5){setError('Escribe un motivo de al menos 5 caracteres.');return;}
    if(decision==='approved'&&!canApprove)return;
    await sendDecision({revision:{id:packet.revision.id,version:packet.revision.version},caseId,caseVersion:packet.revision.base_case_version,caseStatus:packet.base_record.status,sourceExpenses:{...records},decision:{request_id:crypto.randomUUID(),decision,note:note.trim(),publish_content:publish,expense_reviews:decision==='approved'?reviews!:[]}});
  }
  async function sendDecision(batch:DecisionAttempt) {
    if(!api.reviewCaseRevision||busy||saving.current)return;
    const current=generation.current;
    saving.current=true;setBusy(true);setDecisionAttempt(batch);setError('');
    try {
      const result=await api.reviewCaseRevision(batch.revision,batch.decision);
      if(current!==generation.current)return;
      if(result.request_id!==batch.decision.request_id||result.decision!==batch.decision.decision||result.revision_id!==batch.revision.id||result.revision_version!==batch.revision.version+1||result.revision?.id!==batch.revision.id||result.revision.version!==batch.revision.version+1||result.revision.status!==batch.decision.decision||result.record?.id!==batch.caseId)throw new Error('invalid_response');
      if(batch.decision.decision==='approved'){
        const items=result.expenses?.items;
        if(result.record.status!=='approved'||result.record.version<=batch.caseVersion||!Array.isArray(items)||result.expenses.total!==batch.decision.expense_reviews.length||items.length!==batch.decision.expense_reviews.length||batch.decision.expense_reviews.some(review=>!items.some(expense=>{
          const source=batch.sourceExpenses[review.expense_id];
          if(!source||expense.id!==review.expense_id||expense.version<=review.expense_version)return false;
          if(source.financial_inactive)return source.status!=='approved'&&expense.financial_inactive===true&&expense.review_amount_cents===0&&expense.status===source.status&&expense.reimbursable_cents===source.reimbursable_cents&&expense.urgent===source.urgent&&expense.priority_reason===source.priority_reason&&expense.approved_at===source.approved_at&&JSON.stringify(expense.approved_snapshot)===JSON.stringify(source.approved_snapshot);
          return expense.financial_inactive===false&&expense.status==='approved'&&expense.reimbursable_cents===review.amount_cents&&expense.urgent===review.is_urgent&&expense.priority_reason===review.urgency_note;
        })))throw new Error('invalid_response');
      } else if(result.record.status!==batch.caseStatus||result.record.version!==batch.caseVersion)throw new Error('invalid_response');
      updated();close();
    } catch(cause) {
      if(current!==generation.current)return;
      if(denied(cause)){purge();accessDenied();}
      else if((cause as {code?:string})?.code==='40001'){purge();setError(changedRevisionMessage);}
      else if((cause as {code?:string})?.code==='23514'){setDecisionAttempt(null);setPublicationRejected(true);setError('No se aprobó la edición porque falta una condición de publicación. Revisa el caso y sus medios existentes; después recarga la edición. Puedes pedir correcciones o no aprobarla.');}
      else if((cause as {code?:string})?.code==='22023'){setDecisionAttempt(null);setError(message(cause));}
      else setError('No pudimos confirmar la decisión de la edición. Reintenta el mismo envío antes de continuar.');
    } finally {if(current===generation.current){saving.current=false;setBusy(false);}}
  }
  function evidence(record:CaseRevisionPacket['record'],isCase=false) {
    return <div className="rescue-documents">{record.files.map((file,index)=>{
      const name=isCase?`del caso · Archivo ${index+1}`:`de ${title(record)} · Archivo ${index+1}`;
      return <section className="rescue-document" key={file.path}><h5>{roles[file.role]||'Evidencia privada'} · Archivo {index+1}</h5>
        {fileErrors[file.path]?<p role="alert" className="notice">{fileErrors[file.path]}</p>:/\.pdf$/i.test(file.path)?<a href={urls[file.path]} target="_blank" rel="noreferrer" onClick={()=>setLoaded(value=>[...new Set([...value,file.path])])}>Abrir PDF {name}</a>:<a href={urls[file.path]} target="_blank" rel="noreferrer"><img alt={`${roles[file.role]||'Evidencia privada'} ${name}`} src={urls[file.path]} onLoad={()=>setLoaded(value=>[...new Set([...value,file.path])])} onError={()=>{setLoaded(value=>value.filter(path=>path!==file.path));setSeen(value=>value.filter(path=>path!==file.path));setFileErrors(value=>({...value,[file.path]:'No pudimos cargar el archivo. Recarga antes de aprobar.'}));}}/></a>}
        <label className="check-label"><input type="checkbox" disabled={blocked||!loaded.includes(file.path)} checked={seen.includes(file.path)} onChange={event=>setSeen(value=>event.target.checked?[...new Set([...value,file.path])]:value.filter(path=>path!==file.path))}/>Revisé el archivo {index+1} {isCase?'del caso':`de ${title(record)}`}</label>
      </section>;
    })}</div>;
  }
  return <dialog ref={dialog} className="rescue-dialog" aria-labelledby="case-revision-title" onCancel={event=>{event.preventDefault();leave(close);}}>
    <div className="dialog-header"><p className="eyebrow">Edición privada del caso</p><button className="text-button" disabled={blocked} onClick={()=>leave(close)}>Cerrar</button></div>
    <h2 id="case-revision-title">{packet?title(packet.record):'Edición del caso'}</h2>
    {error&&<p className="notice" role="alert">{error}</p>}
    <button className="secondary" disabled={blocked} onClick={()=>leave(()=>setReload(value=>value+1))}>Recargar edición y archivos</button>
    {loading?<p role="status">Cargando la edición y sus documentos privados…</p>:packet&&<>
      <p className="muted">Edición {packet.revision.version} · En revisión · Enviada {date(packet.revision.submitted_at)}</p>
      <p className="notice">{packet.public_version_visible?'La versión aprobada sigue visible. Solo se sustituirá cuando apruebes esta edición completa; pedir correcciones o no aprobar conserva la publicación vigente.':'Este caso está oculto. Solo volverá a publicarse cuando apruebes la edición completa; pedir correcciones o no aprobar conserva el caso oculto.'}</p>
      {packet.publication_blockers.length>0&&<p className="notice" role="status">{packet.publication_blockers.includes('approved_thanks_required')?'El video de agradecimiento necesita revisión antes de publicar el caso. Revisa el video existente en Videos; si cambió después del envío, el rescatista debe retirar y reenviar la edición completa.':'Hay una revisión pendiente que impide publicar esta edición. Revisa el caso y sus medios existentes antes de continuar.'}</p>}
      <section className="revision-reason" aria-label="Motivo de la edición"><h3>Motivo de la edición</h3><p className="authored-text">{packet.revision.reason}</p></section>
      <details className="approved-case-version"><summary>{packet.public_version_visible?'Versión aprobada que sigue publicada':'Versión anterior del caso (oculta)'}</summary><Fields data={packet.base_record.public_data}/></details>
      <h3>Contenido propuesto para publicación</h3><p>Revisa los textos, las fotos y todas las necesidades del mismo caso. Las necesidades adicionales requieren un caso nuevo.</p>
      <Fields data={packet.record.public_data} needFeedback={item=>typeof item.id==='string'?feedback('planned',item.id,packet.revision.base_case_version,text(item.title)):null}/>
      {Object.keys(packet.record.private_data).length>0&&<><h3>Solo para revisión privada</h3><Fields data={packet.record.private_data}/></>}
      {packet.preserved_media.length>0&&<p className="notice">Se conservarán los medios ya aprobados. Los videos pendientes de revisión conservan su proceso por separado.</p>}
      <h3>Documentos y evidencia del caso</h3>{evidence(packet.record,true)}
      <section className="case-expenses" aria-label="Necesidades de la edición"><h3>Necesidades del caso completo</h3>
        <p>Los importes se muestran para revisión y no se ajustan desde el panel. Una edición sin cambios de importe conserva la autorización previa.</p>
        <p className="muted">{packet.expenses.total} necesidades · Página {packet.expenses.page} de {Math.max(1,Math.ceil(packet.expenses.total/20))}</p>
        <p role="status">{Object.keys(records).length} de {packet.expense_ids.length} necesidades consultadas. La evidencia revisada se conserva al cambiar de página.</p>
        {packet.expenses.items.map(expense=>{
          const priority=priorities[expense.id]??{urgent:expense.urgent,urgency:expense.priority_reason};
          return <article className="rescue-need case-expense" key={expense.id}><div className="need-heading"><h4>{title(expense)}</h4><span className="badge">Incluida en la edición</span></div>
            <Fields data={expense.public_data}/><Fields data={expense.private_data}/>
            {expense.financial_inactive?<p className="notice">Necesidad retirada previamente; sin importe disponible</p>:<><p aria-label={`Importe de revisión de ${title(expense)}`}>{expense.review_amount_cents<Number(expense.private_data.amount_cents)?'Importe autorizado que se conserva':'Importe completo a autorizar'}: <strong>{money(expense.review_amount_cents)}</strong></p>
            {expense.financial_locked&&<p className="notice">Esta necesidad tiene una reserva o aportación. Sus datos, importe autorizado y prioridad están protegidos.</p>}</>}
            {evidence(expense)}{feedback('expense',expense.id,expense.version,title(expense))}
            {expense.financial_inactive?<p>Prioridad histórica: {expense.urgent?'Urgente':'Por antigüedad'}{expense.priority_reason&&<> · {expense.priority_reason}</>}</p>:<><label className="check-label"><input type="checkbox" checked={priority.urgent} disabled={blocked||expense.financial_locked} onChange={event=>setPriorities(value=>({...value,[expense.id]:{...priority,urgent:event.target.checked}}))}/>Prioridad urgente para {title(expense)}</label>
            {priority.urgent&&<label>Motivo de prioridad para {title(expense)}<textarea maxLength={1000} value={priority.urgency} disabled={blocked||expense.financial_locked} onChange={event=>setPriorities(value=>({...value,[expense.id]:{...priority,urgency:event.target.value}}))}/></label>}</>}
          </article>;
        })}
        <nav className="pagination expense-pagination" aria-label="Páginas de necesidades de la edición"><span>20 necesidades por página</span><div><button className="secondary" disabled={blocked||page<=1} onClick={()=>leave(()=>setPage(value=>value-1))}>Necesidades anteriores</button><button className="secondary" disabled={blocked||page*20>=packet.expenses.total} onClick={()=>leave(()=>setPage(value=>value+1))}>Necesidades siguientes</button></div></nav>
      </section>
      {commentsEnabled&&<section className="need-comment-save" aria-label="Guardar comentarios de la edición"><h3>Comentarios por necesidad</h3><p>Se guardan para esta edición privada. Guarda los comentarios antes de registrar la decisión del caso completo.</p>
        {packet.need_comments.length>0&&<details><summary>Todos los comentarios de esta edición</summary><CommentHistory comments={packet.need_comments}/></details>}
        {saved&&<p role="status">Comentarios guardados. La decisión de la edición sigue pendiente.</p>}
        <div className="review-actions"><button disabled={busy||decisionAttempt!==null||(!dirty&&!commentAttempt)} onClick={()=>void saveComments()}>{commentAttempt?'Reintentar el mismo guardado':'Guardar comentarios'}</button>{dirty&&!commentAttempt&&<button className="secondary" disabled={blocked} onClick={()=>{setComments({});setError('');}}>Descartar comentarios</button>}</div>
      </section>}
      <section className="rescue-decision" aria-label="Decisión de la edición"><label>Motivo de la decisión (visible para el rescatista)<textarea value={note} maxLength={2000} rows={3} disabled={blocked} onChange={event=>setNote(event.target.value)}/></label>
        <label className="check-label"><input type="checkbox" checked={publish} disabled={blocked} onChange={event=>setPublish(event.target.checked)}/>Autorizo el contenido propuesto del caso y todas las necesidades de esta edición</label>
        <p>Consulta todas las páginas y revisa cada archivo antes de aprobar. {packet.public_version_visible?'Cualquier corrección devuelve la edición completa y conserva la versión ya publicada.':'Cualquier corrección devuelve la edición completa y conserva el caso oculto.'}</p>
        <div className="review-actions"><button disabled={blocked||protectedComments||!canApprove} onClick={()=>void decide('approved')}>Aprobar edición del caso</button><button className="secondary" disabled={blocked||protectedComments||!api.reviewCaseRevision} onClick={()=>void decide('changes_requested')}>Pedir correcciones de la edición</button><button className="secondary" disabled={blocked||protectedComments||!api.reviewCaseRevision} onClick={()=>void decide('rejected')}>No aprobar edición</button></div>
      </section>
    </>}
    {decisionAttempt&&<button disabled={busy} onClick={()=>void sendDecision(decisionAttempt)}>{busy?'Confirmando decisión…':'Reintentar la misma decisión de la edición'}</button>}
    <p className="muted">La edición y los comentarios son privados. Las decisiones se registran con tu cuenta; la aprobación no genera cobros ni depósitos.</p>
  </dialog>;
}
