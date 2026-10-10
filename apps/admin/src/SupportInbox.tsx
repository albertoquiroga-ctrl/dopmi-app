import {useEffect,useState} from 'react';
import {errorMessage,type AdminApi} from './api';
import type {SupportPage} from './supportApi';
const topics:Record<string,string>={support_rules:'Cómo funcionan los apoyos',contribute:'Apoyar',guardian:'Guardián',adopt:'Adoptar',verification:'Verificación',publish_cases:'Publicar casos',funds_evidence:'Fondos y evidencia',account:'Mi cuenta',trust_safety:'Confianza y seguridad'};
function SupportAttachment({api,path}:{api:AdminApi;path:string}) {
  const [url,setUrl]=useState(''),[error,setError]=useState(''),[revision,setRevision]=useState(0);
  useEffect(()=>{
    let active=true;setUrl('');setError('');
    if(!api.supportAttachmentUrl){setError('La imagen de soporte no está disponible.');return;}
    api.supportAttachmentUrl(path).then(value=>{if(active)setUrl(value);}).catch(()=>{if(active)setError('No pudimos cargar la imagen adjunta.');});
    return()=>{active=false;};
  },[api,path,revision]);
  return <div>{url&&<img src={url} alt="Imagen adjunta a la solicitud" style={{maxWidth:'100%',maxHeight:360,objectFit:'contain'}} onError={()=>{setUrl('');setError('No pudimos cargar la imagen adjunta.');}}/>}
    {error?<><p role="alert">{error}</p><button onClick={()=>setRevision(value=>value+1)}>Reintentar imagen</button></>:!url&&<p role="status">Cargando imagen…</p>}</div>;
}
export default function SupportInbox({api}:{api:AdminApi}) {
  const [page,setPage]=useState(1),[revision,setRevision]=useState(0);
  const [data,setData]=useState<SupportPage|null>(null),[error,setError]=useState(''),[loading,setLoading]=useState(true);
  useEffect(()=>{
    let active=true;setLoading(true);setError('');setData(null);
    if(!api.listSupportRequests){setLoading(false);setError('La consulta de soporte no está disponible.');return;}
    api.listSupportRequests(page).then(value=>{if(active)setData(value);}).catch(cause=>{if(active)setError(errorMessage(cause));}).finally(()=>{if(active)setLoading(false);});
    return()=>{active=false;};
  },[api,page,revision]);
  return <section aria-label="Solicitudes de soporte"><h2>Soporte</h2>
    <button disabled={loading} onClick={()=>setRevision(value=>value+1)}>Actualizar solicitudes</button>
    {loading&&<p role="status">Cargando solicitudes…</p>}
    {error&&<p role="alert">{error}</p>}
    {data&&!data.items.length&&<p>No hay solicitudes en esta página.</p>}
    {data?.items.map(item=><article className="access-card" key={`${item.owner_id}:${item.request_id}`}>
      <h3>{topics[item.topic]??'Solicitud de soporte'}</h3>
      <p>{item.display_name} · {new Date(item.created_at).toLocaleString('es-MX')}</p>
      {item.case_name&&<p>Caso relacionado: {item.case_name}</p>}
      <p style={{whiteSpace:'pre-wrap',overflowWrap:'anywhere'}}>{item.message}</p>
      {item.attachment_path&&<SupportAttachment api={api} path={item.attachment_path}/>}
      {item.email&&<a href={`mailto:${encodeURIComponent(item.email)}?subject=${encodeURIComponent('Respuesta de Dopmi: '+(topics[item.topic]??'Soporte'))}`}>Responder por correo</a>}
    </article>)}
    <div className="moderation-filters"><button disabled={loading||page===1} onClick={()=>setPage(value=>value-1)}>Anterior</button>
      <span>Página {page}</span><button disabled={loading||!data||page*25>=data.total} onClick={()=>setPage(value=>value+1)}>Siguiente</button></div>
  </section>;
}
