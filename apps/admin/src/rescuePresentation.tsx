import type { ReactNode } from 'react';
import type { RescueRecord } from './api';

export const roles: Record<string,string> = {identity:'Identificación oficial · privada',address:'Domicilio · privado',receipt:'Comprobante · privado',proof:'Evidencia del gasto · privada',public:'Foto para publicación'};
const labels: Record<string,string> = {public_name:'Nombre público',bio:'Presentación pública',city:'Ciudad',state:'Estado',legal_name:'Nombre legal',phone:'Teléfono',experience:'Experiencia',social_url:'Perfil social',identity_type:'Identificación',pet_name:'Mascota',species:'Especie',sex:'Sexo',age:'Edad aproximada',size:'Tamaño',story:'Historia',need:'Necesidad',title:'Título',description:'Descripción',category:'Necesidad cubierta',round_label:'Ronda de comida',paid_on:'Fecha de pago',vendor:'Proveedor',amount_cents:'Importe pagado',receipt_reference:'Folio o referencia',urgency_reason:'Urgencia solicitada'};
const choices: Record<string,string> = {dog:'Perro',cat:'Gato',female:'Hembra',male:'Macho',unknown:'Por determinar',small:'Pequeño',medium:'Mediano',large:'Grande',food:'Comida',veterinary:'Atención veterinaria',medicine:'Medicamentos',other:'Otro gasto',ine:'INE',passport:'Pasaporte',license:'Licencia'};
export function money(cents: number) { return new Intl.NumberFormat('es-MX',{style:'currency',currency:'MXN'}).format(cents/100); }
export function text(value: unknown): string { return typeof value === 'string' || typeof value === 'number' ? String(value) : typeof value === 'boolean' ? (value ? 'Sí' : 'No') : 'Sin dato'; }
export function title(r: RescueRecord) { return text(r.public_data.public_name||r.public_data.pet_name||r.public_data.title||'Sin título'); }
export function date(value: string | null) { return value?new Date(value).toLocaleString('es-MX'):'Sin enviar'; }

export function Fields({data,needFeedback}:{data:Record<string,unknown>;needFeedback?:(item:Record<string,unknown>)=>ReactNode}) {
  return <><dl className="rescue-fields">{Object.entries(data).filter(([key])=>key!=='need_items').map(([key,value])=><div key={key}><dt>{labels[key]||key}</dt><dd>{key==='amount_cents'?money(Number(value)):choices[text(value)]||text(value)}</dd></div>)}</dl>
    {Array.isArray(data.need_items)&&data.need_items.length>0&&<section aria-label="Necesidades previstas"><h3>Necesidades previstas</h3><p>Estos importes son estimaciones y no sustituyen los comprobantes de los gastos ya pagados.</p><div className="rescue-needs">{data.need_items.map((raw:unknown,index:number)=>{
      if(typeof raw!=='object'||raw===null||Array.isArray(raw))return null;
      const item=raw as Record<string,unknown>;
      return <article className="rescue-need" key={typeof item.id==='string'?item.id:index}><div className="need-heading"><h4>{text(item.title)}</h4>{item.urgent===true&&<span className="badge">Urgente</span>}</div><p>{choices[text(item.type)]||text(item.type)} · {money(Number(item.amount_cents))}</p><p className="authored-text">{text(item.detail)}</p>{needFeedback?.(item)}</article>;
    })}</div></section>}
  </>;
}
