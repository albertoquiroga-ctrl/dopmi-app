import { useEffect, useState } from 'react';
import { errorMessage, type AdminApi, type CaseUpdate, type ContentReport } from './api';

export default function ModerationQueues({api}:{api:AdminApi}) {
  const [view,setView]=useState<'updates'|'reports'>('updates');
  return <><header className="page-heading"><div><p className="eyebrow">Moderación</p><h1>Contenido y reportes</h1><p>Publica avances revisados y resuelve alertas sin abrir datos privados ajenos.</p></div></header>
    <div className="moderation-filters"><button className={view==='updates'?'':'secondary'} onClick={()=>setView('updates')}>Avances</button><button className={view==='reports'?'':'secondary'} onClick={()=>setView('reports')}>Reportes</button></div>
    {view==='updates'?<Updates api={api}/>:<Reports api={api}/>}</>;
}

function Updates({api}:{api:AdminApi}) {
  const [items,setItems]=useState<CaseUpdate[]>([]); const [error,setError]=useState(''); const [loading,setLoading]=useState(true); const [revision,setRevision]=useState(0);
  useEffect(()=>{let alive=true;setLoading(true);setError('');api.listCaseUpdates!('submitted',1).then(v=>{if(alive)setItems(v.items)}).catch(e=>{if(alive)setError(errorMessage(e))}).finally(()=>{if(alive)setLoading(false)});return()=>{alive=false}},[api,revision]);
  async function decide(item:CaseUpdate,decision:string){const feedback=decision==='published'?'':'Revisa el texto o las fotografías antes de volver a enviarlo.';try{await api.reviewCaseUpdate!(item,decision,feedback);setRevision(v=>v+1)}catch(e){setError(errorMessage(e))}}
  if(error)return <div className="empty-state"><div className="notice" role="alert">{error}</div><button onClick={()=>setRevision(v=>v+1)}>Volver a intentar</button></div>;
  if(loading)return <div className="empty-state" role="status">Cargando avances…</div>;
  if(!items.length)return <div className="empty-state"><h2>Avances al día</h2><p>No hay historias esperando revisión.</p></div>;
  return <div className="moderation-list">{items.map(item=><article key={item.id}><div><p className="eyebrow">Caso {item.case_id}</p><h2>{item.body}</h2><p>{item.photos.length} fotografías · versión {item.version}</p></div><div><button onClick={()=>void decide(item,'published')}>Publicar</button><button className="secondary" onClick={()=>void decide(item,'changes_requested')}>Pedir cambios</button></div></article>)}</div>;
}

function Reports({api}:{api:AdminApi}) {
  const [items,setItems]=useState<ContentReport[]>([]); const [error,setError]=useState(''); const [loading,setLoading]=useState(true); const [revision,setRevision]=useState(0);
  useEffect(()=>{let alive=true;setLoading(true);setError('');api.listReports!('open',1).then(v=>{if(alive)setItems(v.items)}).catch(e=>{if(alive)setError(errorMessage(e))}).finally(()=>{if(alive)setLoading(false)});return()=>{alive=false}},[api,revision]);
  async function resolve(item:ContentReport,status:string){try{await api.resolveReport!(item.id,status,status==='resolved'?'Contenido revisado y atendido.':'No se encontró una infracción.');setRevision(v=>v+1)}catch(e){setError(errorMessage(e))}}
  if(error)return <div className="empty-state"><div className="notice" role="alert">{error}</div><button onClick={()=>setRevision(v=>v+1)}>Volver a intentar</button></div>;
  if(loading)return <div className="empty-state" role="status">Cargando reportes…</div>;
  if(!items.length)return <div className="empty-state"><h2>Reportes al día</h2><p>No hay alertas abiertas.</p></div>;
  return <div className="moderation-list">{items.map(item=><article key={item.id}><div><p className="eyebrow">{item.target_type} · {item.reason}</p><h2>{item.target_id}</h2><p>{item.details||'Sin detalles adicionales.'}</p></div><div><button onClick={()=>void resolve(item,'resolved')}>Resolver</button><button className="secondary" onClick={()=>void resolve(item,'dismissed')}>Descartar</button></div></article>)}</div>;
}
