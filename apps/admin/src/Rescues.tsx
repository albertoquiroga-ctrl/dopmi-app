import { useEffect, useRef, useState } from 'react';
import { errorMessage, type AdminApi, type RescueDetail, type RescueRecord } from './api';

export const rescueStatus: Record<string,string> = {submitted:'En revisión',changes_requested:'Con correcciones',approved:'Aprobados',rejected:'No aprobados',closed:'Casos cerrados'};
const kinds: Record<string,string> = {verification:'Verificaciones',case:'Casos',expense:'Gastos'};
const roles: Record<string,string> = {identity:'Identificación oficial · privada',address:'Domicilio · privado',receipt:'Comprobante · privado',proof:'Evidencia del gasto · privada',public:'Foto para publicación'};
const labels: Record<string,string> = {public_name:'Nombre público',bio:'Presentación pública',city:'Ciudad',state:'Estado',legal_name:'Nombre legal',phone:'Teléfono',experience:'Experiencia',social_url:'Perfil social',identity_type:'Identificación',pet_name:'Mascota',species:'Especie',sex:'Sexo',age:'Edad aproximada',story:'Historia',need:'Necesidad',title:'Título',description:'Descripción',category:'Necesidad cubierta',round_label:'Ronda de comida',paid_on:'Fecha de pago',vendor:'Proveedor',amount_cents:'Importe pagado',receipt_reference:'Folio o referencia',urgency_reason:'Urgencia solicitada'};
const choices: Record<string,string> = {dog:'Perro',cat:'Gato',female:'Hembra',male:'Macho',unknown:'Por determinar',food:'Comida',veterinary:'Atención veterinaria',medicine:'Medicamentos',other:'Otro gasto',ine:'INE',passport:'Pasaporte',license:'Licencia'};
export function money(cents: number) { return new Intl.NumberFormat('es-MX',{style:'currency',currency:'MXN'}).format(cents/100); }
export function amount(text: string): number | null { if(!/^\d{1,7}(\.\d{1,2})?$/.test(text)) return null; const [whole,decimal='']=text.split('.'); const value=Number(whole)*100+Number(decimal.padEnd(2,'0')); return value>0&&value<=100000000?value:null; }
function message(cause: unknown) { if(typeof cause==='object'&&cause&&'code' in cause&&'message' in cause&&['22023','40001'].includes(String(cause.code))) return String(cause.message); return errorMessage(cause); }
function title(r: RescueRecord) { return r.public_data.public_name||r.public_data.pet_name||r.public_data.title||'Sin título'; }
function date(value: string | null) { return value?new Date(value).toLocaleString('es-MX'):'Sin enviar'; }

export default function Rescues({api}:{api:AdminApi}) {
  const [kind,setKind]=useState('verification'),[status,setStatus]=useState('submitted'),[page,setPage]=useState(1),[revision,setRevision]=useState(0);
  const [data,setData]=useState<{total:number;items:RescueRecord[]}>({total:0,items:[]}),[selected,setSelected]=useState<string|null>(null);
  const [loading,setLoading]=useState(true),[error,setError]=useState('');
  useEffect(()=>{let alive=true;setLoading(true);setData({total:0,items:[]});setSelected(null);setError('');
    api.listRescue(kind,status,page).then(r=>{if(alive)setData(r);}).catch(e=>{if(alive)setError(message(e));}).finally(()=>{if(alive)setLoading(false);});return()=>{alive=false;};
  },[api,kind,status,page,revision]);
  return <><header className="page-heading"><div><p className="eyebrow">Confianza y transparencia</p><h1>Rescates y gastos</h1><p>Verifica a la persona, revisa el caso y comprueba cada gasto realizado.</p></div><span className="read-only">Sin cobros activos</span></header>
    <section className="users-card"><div className="table-toolbar"><div><h2>Solicitudes del equipo rescatista</h2><p aria-live="polite">{loading?'Consultando…':`${data.total} solicitudes`}</p></div><div className="moderation-filters">
      <label>Tipo<select value={kind} onChange={e=>{setKind(e.target.value);setPage(1);}}>{Object.entries(kinds).map(([v,l])=><option key={v} value={v}>{l}</option>)}</select></label>
      <label>Estado<select value={status} onChange={e=>{setStatus(e.target.value);setPage(1);}}>{Object.entries(rescueStatus).map(([v,l])=><option key={v} value={v}>{l}</option>)}</select></label>
      <button className="secondary" onClick={()=>setRevision(v=>v+1)}>Actualizar</button></div></div>
      {error?<div className="empty-state"><div role="alert" className="notice">{error}</div><button onClick={()=>setRevision(v=>v+1)}>Volver a intentar</button></div>:loading?<div className="empty-state" role="status">Cargando solicitudes…</div>:!data.items.length?<div className="empty-state"><span className="empty-icon" aria-hidden="true">♡</span><h2>Todo al día por aquí</h2><p>No hay solicitudes con estos filtros.</p></div>:<div className="table-scroll"><table><thead><tr><th>Solicitud</th><th>Envío</th><th>Versión</th><th>Revisión</th></tr></thead><tbody>{data.items.map(r=><tr key={r.id}><td><strong>{title(r)}</strong><small>{r.public_data.city}</small></td><td>{date(r.submitted_at)}</td><td>{r.version}</td><td><button className="text-button" onClick={()=>setSelected(r.id)}>Revisar {title(r)}</button></td></tr>)}</tbody></table></div>}
      <footer className="pagination"><span>Página {page} de {Math.max(1,Math.ceil(data.total/20))}</span><div><button className="secondary" disabled={loading||page===1} onClick={()=>setPage(p=>p-1)}>Anterior</button><button className="secondary" disabled={loading||page*20>=data.total} onClick={()=>setPage(p=>p+1)}>Siguiente</button></div></footer>
    </section>
    {selected&&<RescueReview key={selected} api={api} id={selected} close={()=>setSelected(null)} updated={()=>setRevision(v=>v+1)} openParent={setSelected} denied={()=>{setSelected(null);setData({total:0,items:[]});setError('El acceso cambió. Actualiza la lista para volver a comprobarlo.');}}/>}
  </>;
}

function Fields({data}:{data:Record<string,string>}) { return <dl className="rescue-fields">{Object.entries(data).map(([key,value])=><div key={key}><dt>{labels[key]||key}</dt><dd>{key==='amount_cents'?money(Number(value)):choices[value]||value||'Sin dato'}</dd></div>)}</dl>; }

function RescueReview({api,id,close,updated,openParent,denied}:{api:AdminApi;id:string;close:()=>void;updated:()=>void;openParent:(id:string)=>void;denied:()=>void}) {
  const dialog=useRef<HTMLDialogElement>(null);
  const [detail,setDetail]=useState<RescueDetail|null>(null),[urls,setUrls]=useState<Record<string,string>>({});
  const [seen,setSeen]=useState<string[]>([]),[loaded,setLoaded]=useState<string[]>([]),[published,setPublished]=useState(false);
  const [retry,setRetry]=useState(0),[loading,setLoading]=useState(true),[busy,setBusy]=useState(false),[error,setError]=useState('');
  const [note,setNote]=useState(''),[pesos,setPesos]=useState(''),[urgent,setUrgent]=useState(false),[urgency,setUrgency]=useState('');
  useEffect(()=>{dialog.current?.showModal();},[]);
  useEffect(()=>{let alive=true;setLoading(true);setError('');setDetail(null);setUrls({});setSeen([]);setLoaded([]);setPublished(false);
    api.rescueDetail(id).then(async value=>{const paths=await Promise.all(value.record.files.map(async f=>[f.path,await api.rescueFileUrl(f.path)]));
      if(alive){setDetail(value);setUrls(Object.fromEntries(paths));setPesos((Number(value.record.private_data.amount_cents||0)/100).toFixed(2));setUrgent(value.record.urgent);setUrgency(value.record.priority_reason);}
    }).catch(e=>{if(alive){if(e?.code==='42501'&&e?.message!=='Otra persona del equipo debe revisar tu solicitud')denied();else setError(message(e));}}).finally(()=>{if(alive)setLoading(false);});return()=>{alive=false;};
  // The dialog owns these callbacks; an unmounted request never restores private data.
  // eslint-disable-next-line react-hooks/exhaustive-deps
  },[api,id,retry]);
  const r=detail?.record;
  const canApprove=!!r&&r.status==='submitted'&&published&&r.files.every(f=>seen.includes(f.path))&&(r.kind==='verification'||detail.verified)&&(r.kind!=='expense'||detail.case_status==='approved');
  async function decide(decision:string) {
    if(!r||busy)return;
    if(note.trim().length<5){setError('Escribe un motivo de al menos 5 caracteres.');return;}
    const cents=r.kind==='expense'?amount(pesos):0;
    if(decision==='approved'&&r.kind==='expense'&&(cents===null||cents>Number(r.private_data.amount_cents))){setError('El monto debe ser positivo y no exceder el gasto comprobado.');return;}
    if(decision==='approved'&&urgent&&urgency.trim().length<5){setError('Escribe el motivo de la urgencia.');return;}
    setBusy(true);setError('');
    try{await api.reviewRescue(r,{decision,note:note.trim(),amount_cents:cents??0,is_urgent:urgent,urgency_note:urgency,publish_content:published});updated();close();}
    catch(e){if((e as {code?:string;message?:string})?.code==='42501'&&(e as {message?:string})?.message!=='Otra persona del equipo debe revisar tu solicitud')denied();else {setError(message(e));if((e as {code?:string})?.code==='40001'){setDetail(null);setUrls({});}}}
    finally{setBusy(false);}
  }
  return <dialog ref={dialog} className="rescue-dialog" onCancel={e=>{if(busy)e.preventDefault();else close();}} aria-labelledby="rescue-review-title"><div className="dialog-header"><p className="eyebrow">Revisión de expediente</p><button className="text-button" disabled={busy} onClick={close}>Cerrar</button></div>
    <h2 id="rescue-review-title">{r?title(r):'Solicitud'}</h2>
    {error&&<div className="notice" role="alert">{error}</div>}
    <button className="secondary" disabled={busy} onClick={()=>setRetry(v=>v+1)}>Recargar expediente y archivos</button>
    {loading?<p role="status">Cargando documentos privados…</p>:r&&<>
      <p className="muted">Versión {r.version} · {rescueStatus[r.status]||r.status} · Enviado {date(r.submitted_at)}</p>
      <div className="notice">{detail.verified?'Rescatista con verificación vigente.':'Identidad todavía sin verificación vigente.'}{r.parent_id&&<> Caso: {detail.case_status==='approved'?'aprobado y abierto':detail.case_status==='closed'?'cerrado':'requiere revisión'}. <button className="text-button" disabled={busy} onClick={()=>openParent(r.parent_id!)}>Ver expediente del caso</button></>}</div>
      {r.feedback&&<p className="notice">Respuesta anterior: {r.feedback}</p>}
      <h3>Contenido para publicación</h3><p>Comprueba que los textos y fotos no expongan documentos, domicilios particulares ni otros datos privados.</p><Fields data={r.public_data}/>
      {Object.keys(r.private_data).length>0&&<><h3>Solo para revisión privada</h3><Fields data={r.private_data}/></>}
      <h3>Documentos y evidencia</h3><div className="rescue-documents">{r.files.map((file,index)=><section className="rescue-document" key={file.path}><h4>{roles[file.role]} · Archivo {index+1}</h4>
        {file.path.endsWith('.pdf')?<a href={urls[file.path]} target="_blank" rel="noreferrer" onClick={()=>setLoaded(v=>[...v,file.path])}>Abrir PDF {index+1}</a>:<a href={urls[file.path]} target="_blank" rel="noreferrer"><img alt={`${roles[file.role]} ${index+1}`} src={urls[file.path]} onLoad={()=>setLoaded(v=>[...v,file.path])} onError={()=>{setSeen(v=>v.filter(p=>p!==file.path));setLoaded(v=>v.filter(p=>p!==file.path));setError('Un archivo no pudo cargarse. Recarga los archivos antes de aprobar.');}}/></a>}
        <label className="check-label"><input type="checkbox" disabled={busy||!loaded.includes(file.path)} checked={seen.includes(file.path)} onChange={e=>setSeen(v=>e.target.checked?[...v,file.path]:v.filter(p=>p!==file.path))}/>Revisé el archivo {index+1}</label>
      </section>)}</div>
      {r.kind==='expense'&&<><h3>Reembolso y prioridad</h3><p>La referencia es el gasto ya pagado. La aprobación no genera cobros ni depósitos.</p>
        <label>Monto reembolsable en pesos MXN<input inputMode="decimal" value={pesos} maxLength={11} disabled={busy||r.status!=='submitted'} onChange={e=>setPesos(e.target.value)}/></label>
        <label className="check-label"><input type="checkbox" checked={urgent} disabled={busy||r.status!=='submitted'} onChange={e=>setUrgent(e.target.checked)}/>Aprobar urgencia</label>
        {urgent&&<label>Motivo de prioridad<textarea value={urgency} maxLength={1000} disabled={busy||r.status!=='submitted'} onChange={e=>setUrgency(e.target.value)}/></label>}
        {r.status==='approved'&&<p>Monto aprobado: {money(r.reimbursable_cents)} · {r.urgent?'Urgente':'Prioridad por antigüedad'}</p>}
      </>}
      {['submitted','approved'].includes(r.status)&&<div className="rescue-decision">
        <label>Motivo de la decisión (visible para el rescatista)<textarea value={note} maxLength={2000} rows={3} disabled={busy} onChange={e=>setNote(e.target.value)}/></label>
        {r.status==='submitted'&&<label className="check-label"><input type="checkbox" checked={published} disabled={busy} onChange={e=>setPublished(e.target.checked)}/>Autorizo los textos y las fotos marcadas para publicación</label>}
        <div className="review-actions">{r.status==='submitted'&&<><button disabled={busy||!canApprove} onClick={()=>void decide('approved')}>Aprobar solicitud</button><button className="secondary" disabled={busy} onClick={()=>void decide('rejected')}>No aprobar</button></>}
          <button className="secondary" disabled={busy} onClick={()=>void decide('changes_requested')}>{r.status==='approved'?'Retirar aprobación y pedir correcciones':'Pedir correcciones'}</button></div>
        {r.status==='approved'&&<p className="muted">Pedir correcciones retira la aprobación y oculta el contenido correspondiente hasta una nueva revisión.</p>}
      </div>}
      <h3>Historial (últimos 100 movimientos)</h3>{detail.history.length?detail.history.map(event=><article key={event.id} className="review-event"><strong>{rescueStatus[event.action]||({submit:'Enviado',withdraw:'Retirado a borrador',close:'Caso cerrado'} as Record<string,string>)[event.action]||'Actualización'}</strong><small>{date(event.created_at)} · Versión {event.version}</small><p>{event.feedback}</p>{event.reimbursable_cents>0&&<p>{money(event.reimbursable_cents)} · {event.urgent?'Urgente':'Por antigüedad'}</p>}</article>):<p>Sin decisiones anteriores.</p>}
      <p className="muted">La consulta de expedientes y las decisiones quedan registradas en el servidor. Los enlaces a archivos vencen en un minuto.</p>
    </>}
  </dialog>;
}
