import { useEffect, useState } from 'react';
import type { SupabaseClient } from '@supabase/supabase-js';

export type StoreRow = { id: string; version: number; merchant_id?: string; data: Record<string, string | number | boolean> };
export type StoreState = { enabled: boolean; merchants: StoreRow[]; products: StoreRow[] };
export type StoreCatalogApi = {
  list(): Promise<StoreState>;
  save(entity: 'merchant' | 'product', row: StoreRow): Promise<unknown>;
  remove(entity: 'merchant' | 'product', row: StoreRow): Promise<void>;
};
export function createStoreCatalogApi(client: SupabaseClient): StoreCatalogApi {
  return {
    async list() { const {data,error}=await client.rpc('dopmi_admin_store_catalog'); if(error) throw error; return data; },
    async save(entity,row) { const {data,error}=await client.rpc('dopmi_admin_save_store',{entity,item_id:row.id || null,expected_version:row.version,payload:row.data,merchant:row.merchant_id || null}); if(error) throw error; return data; },
    async remove(entity,row) { const {error}=await client.rpc('dopmi_admin_delete_store',{entity,item_id:row.id,expected_version:row.version}); if(error) throw error; },
  };
}
const merchantDefaults = {name:'',domain:'',image_domain:'',enabled:false,permission_reviewed:false,rights_reviewed:false,links_reviewed:false,approval_reference:''};
const productDefaults = {name:'',brand:'',species:'dog',age:'adult',size:'small',weight_kg:1,position:0,image_url:'',image_rights_reference:'',external_url:'',published:false};
const labels: Record<string,string> = {name:'Nombre',domain:'Dominio autorizado',image_domain:'Dominio autorizado para imágenes (opcional)',enabled:'Comercio habilitado',permission_reviewed:'Permiso comercial comprobado',rights_reviewed:'Derechos comprobados',links_reviewed:'Enlaces comprobados',approval_reference:'Referencia de la revisión comercial',brand:'Marca real',species:'Especie',age:'Edad',size:'Tamaño',weight_kg:'Peso en kg',position:'Orden editorial',image_url:'URL de imagen',image_rights_reference:'Referencia de derechos de imagen',external_url:'Enlace exacto al comercio',published:'Producto publicado'};
const choices: Record<string, [string,string][]> = {species:[['dog','Perro'],['cat','Gato']],age:[['puppy','Cachorro'],['adult','Adulto'],['senior','Senior']],size:[['small','Chico'],['medium','Mediano'],['large','Grande']]};

export default function StoreCatalog({api}:{api:StoreCatalogApi}) {
  const [state,setState]=useState<StoreState>();
  const [entity,setEntity]=useState<'merchant'|'product'>('merchant');
  const [row,setRow]=useState<StoreRow>(()=>({id:crypto.randomUUID(),version:0,data:{...merchantDefaults}}));
  const [error,setError]=useState(''); const [busy,setBusy]=useState(false); const [notice,setNotice]=useState('');
  const load=async()=>setState(await api.list());
  useEffect(()=>{let active=true; api.list().then(value=>{if(active)setState(value);}).catch(()=>{if(active)setError('No pudimos cargar el catálogo.');});return()=>{active=false;};},[api]);
  const fresh=(kind:'merchant'|'product')=>{setEntity(kind);setRow({id:crypto.randomUUID(),version:0,merchant_id:kind==='product'?state?.merchants[0]?.id:undefined,data:{...(kind==='merchant'?merchantDefaults:productDefaults)}});setError('');setNotice('');};
  const mutate=async(action:'save'|'remove')=>{setBusy(true);setError('');setNotice('');let confirmed=false;try {
    if(action==='save') {
      const result=await api.save(entity,row);
      if(result && typeof result==='object' && 'id' in result && 'version' in result && typeof result.id==='string' && typeof result.version==='number') {
        setRow({...row,id:result.id,version:result.version});
      }
    } else await api.remove(entity,row);
    confirmed=true;
    await load();fresh(entity);setNotice(action==='save'?'Cambios guardados.':'Registro eliminado.');
  }catch(e){setError(confirmed ? 'Los cambios se guardaron, pero no pudimos actualizar la lista. Conservamos el registro para reintentar sin duplicarlo.' : e && typeof e==='object' && 'message' in e ? String(e.message):'No pudimos guardar. Intenta de nuevo.');}finally{setBusy(false);}};
  return <section aria-label="Catálogo editorial de Tienda"><h2>Tienda</h2>
    <p>{state?.enabled?'Tienda pública habilitada.':'Tienda oculta al público. La activación comercial requiere una operación autorizada por separado.'}</p>
    <p>Compra externa en el comercio. Las comisiones corresponden a Dopmi.</p>
    {error&&<p role="alert">{error}</p>}{notice&&<p role="status">{notice}</p>}
    <button disabled={busy} onClick={()=>fresh('merchant')}>Nuevo comercio</button> <button disabled={busy || !state?.merchants.length} onClick={()=>fresh('product')}>Nuevo producto</button>
    <h3>Comercios</h3>{state?.merchants.map(item=><button key={item.id} disabled={busy} onClick={()=>{setEntity('merchant');setRow({...item,data:{...item.data}});setError('');}}>{String(item.data.name)}</button>)}
    <h3>Productos</h3>{state?.products.map(item=><button key={item.id} disabled={busy} onClick={()=>{setEntity('product');setRow({...item,data:{...item.data}});setError('');}}>{String(item.data.name)}</button>)}
    <form onSubmit={event=>{event.preventDefault();void mutate('save');}}><fieldset disabled={busy}><legend>{entity==='merchant'?'Editar comercio':'Editar producto'}</legend>
      {entity==='product'&&<label>Comercio<select value={row.merchant_id || ''} onChange={event=>setRow({...row,merchant_id:event.target.value})} required>{state?.merchants.map(item=><option key={item.id} value={item.id}>{String(item.data.name)}</option>)}</select></label>}
      {Object.entries(entity==='merchant'?merchantDefaults:productDefaults).map(([key,defaultValue])=><label key={key}>{labels[key]}{choices[key]?<select value={String(row.data[key]??defaultValue)} onChange={event=>setRow({...row,data:{...row.data,[key]:event.target.value}})}>{choices[key].map(([value,label])=><option key={value} value={value}>{label}</option>)}</select>:<input type={typeof defaultValue==='boolean'?'checkbox':typeof defaultValue==='number'?'number':'text'} checked={typeof defaultValue==='boolean'?Boolean(row.data[key]):undefined} value={typeof defaultValue==='boolean'?undefined:String(row.data[key]??defaultValue)} step={key==='weight_kg'?'any':undefined} onChange={event=>setRow({...row,data:{...row.data,[key]:typeof defaultValue==='boolean'?event.target.checked:typeof defaultValue==='number'?Number(event.target.value):event.target.value}})}/>}</label>)}
      <button type="submit">Guardar {entity==='merchant'?'comercio':'producto'}</button>{row.version>0&&<button type="button" onClick={()=>void mutate('remove')}>Eliminar {entity==='merchant'?'comercio':'producto'}</button>}
    </fieldset></form>
  </section>;
}
