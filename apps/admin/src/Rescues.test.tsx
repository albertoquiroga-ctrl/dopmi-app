import { act, fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import Rescues from './Rescues';
import type { AdminApi, InitialCaseDecision, InitialCaseDecisionResult, NeedCommentInput, NeedCommentResult, RescueDetail, RescueRecord } from './api';
const record: RescueRecord={id:'expense',owner_id:'owner',kind:'expense',parent_id:'case',public_data:{title:'Comida de Luna',category:'food',round_label:'Primera ronda'},private_data:{amount_cents:'25050',vendor:'Veterinaria'},files:[{path:'private/receipt.jpg',role:'receipt'}],status:'submitted',version:9,feedback:'',reimbursable_cents:0,urgent:false,priority_reason:'',submitted_at:'2026-09-13T12:00:00Z',updated_at:'2026-09-13T12:00:00Z'};
function api(overrides:Partial<AdminApi>={}):AdminApi { return {session:async()=>true,watch:()=>()=>{},login:async()=>{},logout:async()=>{},isAdmin:async()=>true,listUsers:async()=>({total:0,users:[]}),listAdoptions:async()=>({total:0,items:[]}),reviews:async()=>[],reviewAdoption:async p=>p,photoUrl:async()=>'',listContributions:async()=>({total:0,items:[]}),listRescue:vi.fn(async()=>({total:1,items:[record]})),rescueDetail:vi.fn(async()=>({record,verified:true,case_status:'approved',history:[]})),rescueFileUrl:vi.fn(async()=> 'https://example.test/signed'),reviewRescue:vi.fn(async r=>({...r,status:'approved'})),...overrides}; }
async function open(client:AdminApi) { render(<Rescues api={client}/>);const user=userEvent.setup();await user.click(await screen.findByRole('button',{name:'Revisar Comida de Luna'}));await screen.findByText('Solo para revisión privada');return user; }
describe('rescue review',()=>{
  it('opens cases first and renders structured planned needs without exposing raw JSON',async()=>{
    const planned={...record,kind:'case',parent_id:null,public_data:{pet_name:'Luna',city:'Monterrey',need_items:[{id:'need-one',type:'veterinary',title:'Consulta veterinaria',amount_cents:25000,detail:'Valoración inicial',urgent:true}]}};
    const client=api({listRescue:vi.fn(async()=>({total:1,items:[planned]})),rescueDetail:vi.fn(async()=>({record:planned,verified:false,case_status:null,history:[]}))});
    render(<Rescues api={client}/>);const user=userEvent.setup();
    await user.click(await screen.findByRole('button',{name:'Revisar Luna'}));
    expect(client.listRescue).toHaveBeenCalledWith('case','submitted',1);
    expect(await screen.findByRole('region',{name:'Necesidades previstas'})).toHaveTextContent('Consulta veterinaria');
    expect(screen.getByText('Valoración inicial')).toBeInTheDocument();
    expect(screen.getByText(/Atención veterinaria ·/)).toHaveTextContent('$250.00');
    expect(screen.queryByText('need_items')).not.toBeInTheDocument();
    expect(screen.queryByText('Sin cobros activos')).not.toBeInTheDocument();
  });

  it('keeps optional verification review available with loaded evidence and explicit public approval',async()=>{
    const ordinary={...record,kind:'verification',parent_id:null};
    const client=api({rescueDetail:vi.fn(async()=>({record:ordinary,verified:false,case_status:null,history:[]}))});
    const user=await open(client), button=screen.getByRole('button',{name:'Aprobar solicitud'});
    expect(button).toBeDisabled();
    fireEvent.load(screen.getByAltText('Comprobante · privado 1'));
    await user.click(screen.getByLabelText('Revisé el archivo 1'));expect(button).toBeDisabled();
    await user.click(screen.getByLabelText('Autorizo los textos y las fotos marcadas para publicación'));
    await user.type(screen.getByLabelText('Motivo de la decisión (visible para el rescatista)'),'Expediente revisado');
    expect(button).toBeEnabled();await user.click(button);
    await waitFor(()=>expect(client.reviewRescue).toHaveBeenCalledWith(ordinary,expect.objectContaining({decision:'approved',publish_content:true})));
  });
  it.each(['submitted','approved','changes_requested'])('keeps a historical expense read only without any individual decision (%s)',async status=>{
    const client=api({rescueDetail:vi.fn(async()=>({record:{...record,status},verified:false,case_status:'approved',history:[]}))});
    await open(client);
    expect(screen.getByText(/Las decisiones se registran para el caso completo/)).toBeInTheDocument();
    expect(screen.queryByRole('button',{name:/Aprobar|No aprobar|Pedir correcciones/})).not.toBeInTheDocument();
    expect(screen.queryByLabelText('Monto reembolsable en pesos MXN')).not.toBeInTheDocument();
    expect(screen.queryByRole('option',{name:'Gastos'})).not.toBeInTheDocument();
    expect(client.reviewRescue).not.toHaveBeenCalled();
  });
  it('requires a future complete submission before approving a legacy case without a frozen manifest',async()=>{
    const legacy={...record,kind:'case',parent_id:null};
    const client=api({rescueDetail:vi.fn(async()=>({record:legacy,verified:false,case_status:null,history:[]}))}),user=await open(client);
    fireEvent.load(screen.getByAltText('Comprobante · privado 1'));
    await user.click(screen.getByLabelText('Revisé el archivo 1'));
    await user.click(screen.getByLabelText('Autorizo los textos y las fotos marcadas para publicación'));
    expect(screen.getByRole('button',{name:'Aprobar caso'})).toBeDisabled();
    expect(screen.getByText(/Este envío anterior no tiene un conjunto capturado/)).toBeInTheDocument();
    expect(screen.getByRole('button',{name:'Pedir correcciones'})).toBeEnabled();
    expect(client.reviewRescue).not.toHaveBeenCalled();
  });
  it('clears private details when a review conflicts and requires a fresh load',async()=>{
    const client=api({rescueDetail:vi.fn(async()=>({record:{...record,kind:'case',parent_id:null},verified:false,case_status:null,history:[]})),reviewRescue:vi.fn(async()=>{throw {code:'40001',message:'La solicitud cambió'};})}),user=await open(client);
    await user.type(screen.getByLabelText('Motivo de la decisión (visible para el rescatista)'),'Adjunta una foto legible');await user.click(screen.getByRole('button',{name:'Pedir correcciones'}));
    await screen.findByText('La solicitud cambió');expect(screen.queryByText('Solo para revisión privada')).not.toBeInTheDocument();expect(screen.queryByRole('button',{name:'Aprobar solicitud'})).not.toBeInTheDocument();
  });
  it('discards the private record when the server denies access',async()=>{
    const client=api({rescueDetail:vi.fn(async()=>{throw {code:'42501'};})});render(<Rescues api={client}/>);const user=userEvent.setup();await user.click(await screen.findByRole('button',{name:'Revisar Comida de Luna'}));await screen.findByText('El acceso cambió. Actualiza la lista para volver a comprobarlo.');expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
  });
});

function initialPacketApi(expenses:RescueRecord[],overrides:Partial<AdminApi>={}) {
  const initial={id:'initial-submission',case_version:caseRecord.version,source_case_version:caseRecord.version-1,expense_ids:expenses.map(expense=>expense.id)};
  return packetApi({rescueDetail:vi.fn(async(_id,page=1)=>({...packet,initial_packet:initial,expenses:{total:expenses.length,page,items:expenses.slice((page-1)*20,page*20)}})),reviewInitialCasePacket:vi.fn(async(record,decision)=>packetResult(record,decision)),...overrides});
}
function packetResult(record:{id:string;version:number},decision:InitialCaseDecision):InitialCaseDecisionResult {
  return {request_id:decision.request_id,submission_id:decision.submission_id,record_id:record.id,case_version:record.version,decision:decision.decision,record:{...caseRecord,status:decision.decision,version:record.version+1},expenses:decision.expense_reviews.map(review=>({...packetExpense,id:review.expense_id,version:review.expense_version+2,status:'approved',reimbursable_cents:review.amount_cents,urgent:review.is_urgent,priority_reason:review.urgency_note}))};
}
function initialExpense(index:number,files:RescueRecord['files']=[]):RescueRecord {
  return {...packetExpense,id:`expense-${String(index).padStart(3,'0')}`,public_data:{title:`Necesidad ${index}`},submission_id:'initial-submission',status:'draft',urgent:true,priority_reason:'Urgencia del autor',files};
}

describe('one decision for the initial packet',()=>{
  it('preserves paid snapshot amounts and reviewed evidence through 21 items and sends one complete atomic case approval without a badge',async()=>{
    const expenses=Array.from({length:21},(_,index)=>initialExpense(index+1,index===0?[{path:'private/first.PDF',role:'receipt'},{path:'private/first.jpg',role:'proof'}]:[]));
    const client=initialPacketApi(expenses),{user}=await openPacket(client);
    const approve=()=>screen.getByRole('button',{name:'Aprobar caso'});
    expect(screen.queryByRole('button',{name:/Abrir revisión individual/})).not.toBeInTheDocument();
    expect(screen.getByLabelText('Importe pagado de Necesidad 1')).toHaveTextContent('$250.50');
    expect(screen.queryByLabelText(/Monto autorizado/)).not.toBeInTheDocument();
    expect(screen.getByText('Sin sello Dopmi. Esto no impide revisar esta solicitud.')).toBeInTheDocument();
    expect(screen.getByLabelText('Prioridad urgente para Necesidad 1')).not.toBeChecked();
    expect(screen.getByLabelText('Revisé el archivo 1 de Necesidad 1')).toBeDisabled();
    await user.click(screen.getByRole('link',{name:'Abrir PDF de Necesidad 1 · Archivo 1'}));
    await user.click(screen.getByLabelText('Revisé el archivo 1 de Necesidad 1'));
    await user.type(screen.getByLabelText('Motivo de la decisión (visible para el rescatista)'),'Expediente completo revisado');
    await user.click(screen.getByLabelText('Autorizo los textos y las fotos marcadas para publicación del caso y de todas las necesidades de este paquete'));
    expect(approve()).toBeDisabled();
    fireEvent.load(screen.getByAltText('Evidencia del gasto · privada de Necesidad 1 2'));
    await user.click(screen.getByLabelText('Revisé el archivo 2 de Necesidad 1'));
    expect(approve()).toBeDisabled();
    await user.click(screen.getByRole('button',{name:'Gastos siguientes'}));
    expect(await screen.findByLabelText('Importe pagado de Necesidad 21')).toHaveTextContent('$250.50');
    expect(screen.getByText('21 de 21 necesidades consultadas. Los archivos revisados y la prioridad se conservan al cambiar de página.')).toBeInTheDocument();
    expect(approve()).toBeEnabled();
    await user.click(screen.getByRole('button',{name:'Gastos anteriores'}));
    expect(await screen.findByLabelText('Importe pagado de Necesidad 1')).toHaveTextContent('$250.50');
    expect(screen.getByLabelText('Revisé el archivo 1 de Necesidad 1')).toBeChecked();
    expect(screen.getByLabelText('Revisé el archivo 2 de Necesidad 1')).toBeChecked();
    expect(screen.getByLabelText('Motivo de la decisión (visible para el rescatista)')).toHaveValue('Expediente completo revisado');
    expect(approve()).toBeEnabled();await user.click(approve());
    await waitFor(()=>expect(client.reviewInitialCasePacket).toHaveBeenCalledTimes(1));
    const [reviewed,decision]=vi.mocked(client.reviewInitialCasePacket!).mock.calls[0];
    expect(reviewed).toEqual({id:caseRecord.id,version:12});
    expect(decision).toMatchObject({submission_id:'initial-submission',decision:'approved',publish_content:true});
    expect(decision.expense_reviews).toEqual(expenses.map(expense=>({expense_id:expense.id,expense_version:expense.version,amount_cents:25050,is_urgent:false,urgency_note:'',publish_content:true})));
    expect(client.reviewRescue).not.toHaveBeenCalled();
  });

  it('keeps an uncertain decision frozen until the same request confirms, including rejection without money',async()=>{
    const review=vi.fn<NonNullable<AdminApi['reviewInitialCasePacket']>>().mockRejectedValueOnce(new TypeError('network')).mockImplementationOnce(async(record,decision)=>packetResult(record,decision));
    const client=initialPacketApi([initialExpense(1)],{reviewInitialCasePacket:review}),{user}=await openPacket(client);
    await user.type(screen.getByLabelText('Motivo de la decisión (visible para el rescatista)'),'Falta comprobante legible');
    await user.click(screen.getByRole('button',{name:'No aprobar'}));
    await screen.findByText(/No pudimos confirmar la decisión del paquete/);
    for(const name of ['Cerrar','Recargar expediente y archivos','No aprobar','Pedir correcciones','Revisar Luna'])expect(screen.getByRole('button',{name})).toBeDisabled();
    expect(screen.getByLabelText('Prioridad urgente para Necesidad 1')).toBeDisabled();
    expect(screen.getByLabelText('Comentario para Necesidad 1')).toBeDisabled();
    expect(review.mock.calls[0][1]).toMatchObject({decision:'rejected',expense_reviews:[]});
    await user.click(screen.getByRole('button',{name:'Reintentar la misma decisión del paquete'}));
    await waitFor(()=>expect(screen.queryByRole('dialog')).not.toBeInTheDocument());
    expect(review.mock.calls[1]).toEqual(review.mock.calls[0]);expect(client.reviewRescue).not.toHaveBeenCalled();
  });

  it.each([{code:'40001'},{status:403}])('purges frozen private data after decision refusal %j',async failure=>{
    const client=initialPacketApi([initialExpense(1)],{reviewInitialCasePacket:vi.fn().mockRejectedValue(failure)}),{user}=await openPacket(client);
    await user.type(screen.getByLabelText('Motivo de la decisión (visible para el rescatista)'),'Requiere correcciones');
    await user.click(screen.getByRole('button',{name:'Pedir correcciones'}));
    await screen.findByRole('alert');
    expect(screen.queryByLabelText('Importe pagado de Necesidad 1')).not.toBeInTheDocument();
    expect(screen.queryByRole('button',{name:'Reintentar la misma decisión del paquete'})).not.toBeInTheDocument();
  });

  it('retains the entire approved financial payload when a response cannot be reconciled',async()=>{
    const review=vi.fn<NonNullable<AdminApi['reviewInitialCasePacket']>>().mockImplementationOnce(async(record,decision)=>({...packetResult(record,decision),request_id:'wrong-request'})).mockImplementationOnce(async(record,decision)=>packetResult(record,decision));
    const client=initialPacketApi([initialExpense(1)],{reviewInitialCasePacket:review}),{user}=await openPacket(client);
    const paid=screen.getByLabelText('Importe pagado de Necesidad 1');
    await user.click(screen.getByLabelText('Prioridad urgente para Necesidad 1'));
    await user.type(screen.getByLabelText('Motivo de prioridad para Necesidad 1'),'Atención inmediata');
    await user.type(screen.getByLabelText('Motivo de la decisión (visible para el rescatista)'),'Contenido y monto revisados');
    await user.click(screen.getByLabelText('Autorizo los textos y las fotos marcadas para publicación del caso y de todas las necesidades de este paquete'));
    await user.click(screen.getByRole('button',{name:'Aprobar caso'}));
    await screen.findByText(/No pudimos confirmar la decisión del paquete/);
    expect(paid).toHaveTextContent('$250.50');
    expect(screen.getByLabelText('Motivo de prioridad para Necesidad 1')).toBeDisabled();
    await user.click(screen.getByRole('button',{name:'Reintentar la misma decisión del paquete'}));
    await waitFor(()=>expect(screen.queryByRole('dialog')).not.toBeInTheDocument());
    expect(review.mock.calls[1]).toEqual(review.mock.calls[0]);
    expect(review.mock.calls[0][1].expense_reviews).toEqual([{expense_id:'expense-001',expense_version:9,amount_cents:25050,is_urgent:true,urgency_note:'Atención inmediata',publish_content:true}]);
  });

  it('keeps the same approval pending when its receipt confirms a different reimbursable amount',async()=>{
    const review=vi.fn<NonNullable<AdminApi['reviewInitialCasePacket']>>().mockImplementation(async(record,decision)=>{
      const result=packetResult(record,decision);
      return {...result,expenses:result.expenses.map(expense=>({...expense,reimbursable_cents:expense.reimbursable_cents-1}))};
    });
    const client=initialPacketApi([initialExpense(1)],{reviewInitialCasePacket:review}),{user}=await openPacket(client);
    await user.type(screen.getByLabelText('Motivo de la decisión (visible para el rescatista)'),'Contenido e importe revisados');
    await user.click(screen.getByLabelText('Autorizo los textos y las fotos marcadas para publicación del caso y de todas las necesidades de este paquete'));
    await user.click(screen.getByRole('button',{name:'Aprobar caso'}));
    await screen.findByText(/No pudimos confirmar la decisión del paquete/);
    expect(screen.getByRole('dialog')).toBeInTheDocument();
    expect(screen.getByRole('button',{name:'Reintentar la misma decisión del paquete'})).toBeEnabled();
    expect(client.reviewRescue).not.toHaveBeenCalled();
  });

  it('ignores a late initial decision after the authenticated API changes',async()=>{
    let finish!:(value:InitialCaseDecisionResult)=>void;
    const review=vi.fn<NonNullable<AdminApi['reviewInitialCasePacket']>>(()=>new Promise(resolve=>{finish=resolve;}));
    const clientA=initialPacketApi([initialExpense(1)],{reviewInitialCasePacket:review}),{user,rerender}=await openPacket(clientA);
    await user.type(screen.getByLabelText('Motivo de la decisión (visible para el rescatista)'),'Privado de otra cuenta');
    await user.click(screen.getByRole('button',{name:'Pedir correcciones'}));
    const clientB=initialPacketApi([initialExpense(2)]);rerender(<Rescues api={clientB}/>);
    await user.click(await screen.findByRole('button',{name:'Revisar Luna'}));await screen.findByLabelText('Importe pagado de Necesidad 2');
    await act(async()=>finish(packetResult(...review.mock.calls[0])));
    expect(screen.getByRole('dialog')).toBeInTheDocument();expect(screen.getByLabelText('Motivo de la decisión (visible para el rescatista)')).toHaveValue('');
    expect(clientB.reviewInitialCasePacket).not.toHaveBeenCalled();
  });
});

const plannedId='00000000-0000-4000-8000-000000000001';
const caseRecord:RescueRecord={...record,id:'case-packet',kind:'case',parent_id:null,version:12,public_data:{pet_name:'Luna',need_items:[{id:plannedId,type:'veterinary',title:'Consulta veterinaria',amount_cents:25000,detail:'Valoración inicial'}]},private_data:{},files:[]};
const packetExpense:RescueRecord={...record,id:'00000000-0000-4000-8000-000000000002',parent_id:caseRecord.id,files:[{path:'private/receipt.PDF',role:'receipt'}]};
const packet:RescueDetail={record:caseRecord,verified:false,case_status:null,history:[],expenses:{total:21,page:1,items:[packetExpense]},need_comments:[]};
function savedResult(record:{id:string;version:number},comments:NeedCommentInput[],requestId:string):NeedCommentResult {
  return {request_id:requestId,record_id:record.id,case_version:record.version,comments:comments.map(comment=>({...comment,id:`${requestId}:${comment.target_kind}:${comment.target_id}`,request_id:requestId,case_id:record.id,case_version:record.version,target_title:comment.target_kind==='planned'?'Consulta veterinaria':'Comida de Luna',created_at:'2026-11-02T10:00:00Z'}))};
}
function packetApi(overrides:Partial<AdminApi>={}):AdminApi {
  return api({listRescue:vi.fn(async()=>({total:1,items:[caseRecord]})),rescueDetail:vi.fn(async(_id,page=1)=>({...packet,expenses:{...packet.expenses!,page}})),saveNeedComments:vi.fn<NonNullable<AdminApi['saveNeedComments']>>(async(record,comments,requestId)=>savedResult(record,comments,requestId)),...overrides});
}
async function openPacket(client:AdminApi) {
  const view=render(<Rescues api={client}/>), user=userEvent.setup();
  await user.click(await screen.findByRole('button',{name:'Revisar Luna'}));
  await screen.findByRole('region',{name:'Gastos del caso'});
  return {user,...view};
}

describe('case needs packet',()=>{
  it('saves comments with destination versions and shows legacy evidence without any individual expense action',async()=>{
    const client=packetApi(),{user}=await openPacket(client);
    expect(client.rescueDetail).toHaveBeenCalledWith(caseRecord.id,1);
    expect(client.rescueFileUrl).toHaveBeenCalledWith('private/receipt.PDF');
    expect(screen.getByRole('link',{name:'Abrir PDF de Comida de Luna · Archivo 1'})).toHaveAttribute('href','https://example.test/signed');
    expect(screen.getByText('21 gastos accesibles · Página 1 de 2')).toBeInTheDocument();
    expect(screen.queryByRole('button',{name:'Abrir revisión individual de Comida de Luna'})).not.toBeInTheDocument();
    await user.type(screen.getByLabelText('Comentario para Consulta veterinaria'),'  Aclara la valoración  ');
    await user.type(screen.getByLabelText('Comentario para Comida de Luna'),'Confirma el proveedor');
    expect(screen.getByRole('button',{name:'Pedir correcciones'})).toBeDisabled();
    await user.click(screen.getByRole('button',{name:'Guardar comentarios'}));
    await screen.findByText('Comentarios guardados. La decisión del caso sigue pendiente.');
    expect(client.saveNeedComments).toHaveBeenCalledWith({id:caseRecord.id,version:12},[
      {target_kind:'planned',target_id:plannedId,target_version:12,body:'Aclara la valoración'},
      {target_kind:'expense',target_id:packetExpense.id,target_version:9,body:'Confirma el proveedor'},
    ],expect.any(String));
    expect(screen.getByLabelText('Comentario para Consulta veterinaria')).toHaveValue('');
    expect(screen.getByText('Aclara la valoración')).toBeInTheDocument();
    expect(screen.getByText(/Versión 12 · En revisión/)).toBeInTheDocument();
    expect(client.reviewRescue).not.toHaveBeenCalled();
    // Viewing child files never grants the legacy case publication checkbox.
    expect(screen.getByRole('button',{name:'Aprobar caso'})).toBeDisabled();
  });

  it('protects unsaved comments when closing, reloading or changing expense page and pages only through the server',async()=>{
    const client=packetApi(),{user}=await openPacket(client);
    await user.type(screen.getByLabelText('Comentario para Consulta veterinaria'),'Pendiente de guardar');
    for(const name of ['Cerrar','Recargar expediente y archivos','Gastos siguientes'])await user.click(screen.getByRole('button',{name}));
    expect(screen.getByRole('dialog')).toBeInTheDocument();
    expect(screen.getByLabelText('Comentario para Consulta veterinaria')).toHaveValue('Pendiente de guardar');
    expect(client.rescueDetail).toHaveBeenCalledTimes(1);
    expect(screen.getByRole('alert')).toHaveTextContent('Guarda los comentarios o descártalos');
    await user.click(screen.getByRole('button',{name:'Descartar comentarios'}));
    await user.click(screen.getByRole('button',{name:'Gastos siguientes'}));
    await waitFor(()=>expect(client.rescueDetail).toHaveBeenLastCalledWith(caseRecord.id,2));
    expect(await screen.findByText('21 gastos accesibles · Página 2 de 2')).toBeInTheDocument();
  });

  it('retries an uncertain write with the exact payload and request ID while blocking edits and decisions',async()=>{
    const save=vi.fn<NonNullable<AdminApi['saveNeedComments']>>().mockRejectedValueOnce(new TypeError('network')).mockImplementationOnce(async(...args)=>savedResult(...args));
    const client=packetApi({saveNeedComments:save}),{user}=await openPacket(client);
    await user.type(screen.getByLabelText('Comentario para Comida de Luna'),'Confirma la fecha');
    await user.click(screen.getByRole('button',{name:'Guardar comentarios'}));
    await screen.findByText(/No pudimos confirmar el guardado/);
    expect(screen.getByLabelText('Comentario para Comida de Luna')).toBeDisabled();
    expect(screen.getByRole('button',{name:'Cerrar'})).toBeDisabled();
    expect(screen.getByRole('button',{name:'Revisar Luna'})).toBeDisabled();
    expect(screen.getByRole('button',{name:'Pedir correcciones'})).toBeDisabled();
    expect(screen.getByRole('button',{name:'Gastos siguientes'})).toBeDisabled();
    await user.click(screen.getByRole('button',{name:'Reintentar el mismo guardado'}));
    await screen.findByText('Comentarios guardados. La decisión del caso sigue pendiente.');
    expect(save).toHaveBeenCalledTimes(2);
    expect(save.mock.calls[1]).toEqual(save.mock.calls[0]);
    expect(screen.getAllByText('Confirma la fecha')).toHaveLength(1);
    expect(client.reviewRescue).not.toHaveBeenCalled();
  });

  it('requires fresh details after a version conflict and never replays the old notes',async()=>{
    const save=vi.fn().mockRejectedValue({code:'40001'});
    const client=packetApi({saveNeedComments:save}),{user}=await openPacket(client);
    await user.type(screen.getByLabelText('Comentario para Consulta veterinaria'),'Comentario viejo');
    await user.click(screen.getByRole('button',{name:'Guardar comentarios'}));
    await screen.findByText(/El expediente o una necesidad cambió/);
    expect(screen.queryByLabelText('Comentario para Consulta veterinaria')).not.toBeInTheDocument();
    expect(screen.queryByRole('region',{name:'Gastos del caso'})).not.toBeInTheDocument();
    await user.click(screen.getByRole('button',{name:'Recargar expediente y archivos'}));
    expect(await screen.findByLabelText('Comentario para Consulta veterinaria')).toHaveValue('');
    expect(save).toHaveBeenCalledTimes(1);
    expect(client.reviewRescue).not.toHaveBeenCalled();
  });

  it('purges the packet and drafts if comment permission was revoked',async()=>{
    const client=packetApi({saveNeedComments:vi.fn().mockRejectedValue({code:'42501'})}),{user}=await openPacket(client);
    await user.type(screen.getByLabelText('Comentario para Consulta veterinaria'),'Texto privado');
    await user.click(screen.getByRole('button',{name:'Guardar comentarios'}));
    await screen.findByText('El acceso cambió. Actualiza la lista para volver a comprobarlo.');
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
    expect(screen.queryByText('Texto privado')).not.toBeInTheDocument();
    expect(screen.queryByText('Comida de Luna')).not.toBeInTheDocument();
  });

  it('keeps the packet and working files available when one expense PDF is missing',async()=>{
    const second={...packetExpense,id:'second-expense',public_data:{title:'Medicinas'},files:[{path:'private/medicine.PDF',role:'receipt'}]};
    const value={...packet,expenses:{total:2,page:1,items:[packetExpense,second]}};
    const detail=vi.fn(async()=>value);
    const client=packetApi({rescueDetail:detail,rescueFileUrl:vi.fn(async path=>{
      if(path==='private/receipt.PDF')throw {status:404};
      return 'https://example.test/working-file';
    })});
    await openPacket(client);
    expect(detail).toHaveBeenCalledTimes(2);
    expect(screen.getByRole('region',{name:'Necesidades previstas'})).toHaveTextContent('Consulta veterinaria');
    expect(screen.getByRole('link',{name:'Abrir PDF de Medicinas · Archivo 1'})).toHaveAttribute('href','https://example.test/working-file');
    expect(screen.getByRole('alert')).toHaveTextContent('Archivo no disponible');
    expect(screen.getByRole('button',{name:'Reintentar archivo'})).toBeEnabled();
    expect(screen.getByLabelText('Comentario para Comida de Luna')).toBeEnabled();
    expect(client.reviewRescue).not.toHaveBeenCalled();
  });

  it('purges partial file results if revalidation reveals lost packet access',async()=>{
    const detail=vi.fn().mockResolvedValueOnce(packet).mockRejectedValueOnce({code:'42501'});
    const client=packetApi({rescueDetail:detail,rescueFileUrl:vi.fn().mockRejectedValue({status:404})});
    render(<Rescues api={client}/>);
    await userEvent.setup().click(await screen.findByRole('button',{name:'Revisar Luna'}));
    await screen.findByText('El acceso cambió. Actualiza la lista para volver a comprobarlo.');
    expect(detail).toHaveBeenCalledTimes(2);
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
    expect(screen.queryByText('Comida de Luna')).not.toBeInTheDocument();
    expect(client.reviewRescue).not.toHaveBeenCalled();
  });

  it('cannot approve the case when its own publication file is unavailable',async()=>{
    const value={...packet,record:{...caseRecord,files:[{path:'private/case-photo.jpg',role:'public'}]}};
    const client=packetApi({rescueDetail:vi.fn(async()=>value),rescueFileUrl:vi.fn(async path=>{
      if(path==='private/case-photo.jpg')throw {status:404};
      return 'https://example.test/working-file';
    })});
    const {user}=await openPacket(client);
    await user.click(screen.getByLabelText('Autorizo los textos y las fotos marcadas para publicación'));
    expect(screen.getByLabelText('Revisé el archivo 1')).toBeDisabled();
    expect(screen.getByRole('button',{name:'Aprobar caso'})).toBeDisabled();
    expect(client.reviewRescue).not.toHaveBeenCalled();
  });

  it('ignores a late A response after the actor/API changes and B has been opened',async()=>{
    let finish!:(result:NeedCommentResult)=>void;
    const save=vi.fn<NonNullable<AdminApi['saveNeedComments']>>(()=>new Promise(resolve=>{finish=resolve;}));
    const clientA=packetApi({saveNeedComments:save}),{user,rerender}=await openPacket(clientA);
    await user.type(screen.getByLabelText('Comentario para Consulta veterinaria'),'Texto privado de A');
    await user.click(screen.getByRole('button',{name:'Guardar comentarios'}));
    const b={...caseRecord,id:'case-b',public_data:{pet_name:'Sol'}};
    const clientB=packetApi({listRescue:vi.fn(async()=>({total:1,items:[b]})),rescueDetail:vi.fn(async()=>({...packet,record:b,expenses:{total:0,page:1,items:[]}}))});
    rerender(<Rescues api={clientB}/>);
    await user.click(await screen.findByRole('button',{name:'Revisar Sol'}));
    await screen.findByRole('region',{name:'Gastos del caso'});
    await act(async()=>finish(savedResult(...save.mock.calls[0])));
    expect(within(screen.getByRole('dialog')).getByRole('heading',{name:'Sol'})).toBeInTheDocument();
    expect(screen.queryByText('Texto privado de A')).not.toBeInTheDocument();
    expect(screen.queryByText(/Comentarios guardados\. El estado/)).not.toBeInTheDocument();
    expect(clientB.saveNeedComments).not.toHaveBeenCalled();
  });
});
