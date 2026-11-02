import { act, fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import Rescues from './Rescues';
import type { AdminApi, CaseRevisionCommentResult, CaseRevisionDecision, CaseRevisionDecisionResult, CaseRevisionExpense, CaseRevisionPacket, NeedCommentInput, RescueRecord } from './api';

const record:RescueRecord={id:'case',owner_id:'owner',kind:'case',parent_id:null,public_data:{pet_name:'Luna',story:'Historia corregida',need_items:[{id:'planned',type:'veterinary',title:'Consulta',amount_cents:10000,detail:'Valoración corregida'}]},private_data:{},files:[],status:'approved',version:4,feedback:'',reimbursable_cents:0,urgent:false,priority_reason:'',submitted_at:null,updated_at:''};
const revision={id:'revision',case_id:'case',owner_id:'owner',base_case_version:4,version:2,status:'submitted',reason:'Corregir historia y comprobante',submitted_at:'2026-11-02T18:00:00Z',updated_at:''};
function expense(index:number,patch:Partial<CaseRevisionExpense>={}):CaseRevisionExpense {
  return {...record,id:`expense-${index}`,kind:'expense',parent_id:'case',public_data:{title:`Necesidad ${index}`},private_data:{amount_cents:'10000'},version:8,reimbursable_cents:8000,financial_locked:false,financial_inactive:false,locked_fields:[],review_amount_cents:8000,files:[],...patch};
}
function packet(items:CaseRevisionExpense[],page=1):CaseRevisionPacket {
  return {revision,record,public_version_visible:true,publication_blockers:[],base_record:{...record,public_data:{pet_name:'Luna',story:'Historia que sigue publicada'}},expenses:{total:items.length,page,items:items.slice((page-1)*20,page*20)},expense_ids:items.map(item=>item.id),expense_versions:Object.fromEntries(items.map(item=>[item.id,item.version])),need_comments:[],preserved_media:[{id:'approved-video',parent_id:'case',purpose:'case'}]};
}
function decisionResult(items:CaseRevisionExpense[],decision:CaseRevisionDecision):CaseRevisionDecisionResult {
  const value=packet(items);
  return {...value,request_id:decision.request_id,decision:decision.decision,revision_id:revision.id,revision_version:revision.version+1,revision:{...revision,version:revision.version+1,status:decision.decision},record:decision.decision==='approved'?{...record,version:5}:record,expenses:decision.decision==='approved'?{total:items.length,page:1,items:items.map(item=>{
    const review=decision.expense_reviews.find(review=>review.expense_id===item.id)!;
    return item.financial_inactive?{...item,version:item.version+1}:{...item,version:item.version+1,reimbursable_cents:review.amount_cents,urgent:review.is_urgent,priority_reason:review.urgency_note};
  })}:value.expenses};
}
function commentResult(comments:NeedCommentInput[],requestId:string):CaseRevisionCommentResult {
  return {request_id:requestId,revision_id:revision.id,revision_version:revision.version,record_id:record.id,case_version:record.version,comments:comments.map((comment,index)=>({...comment,id:`comment-${index}`,request_id:requestId,case_id:record.id,case_version:record.version,target_title:comment.target_id==='planned'?'Consulta':'Necesidad 1',created_at:'2026-11-02T18:01:00Z'}))};
}
function api(items:CaseRevisionExpense[]=[expense(1)],overrides:Partial<AdminApi>={}):AdminApi {
  return {session:async()=>true,watch:()=>()=>{},login:async()=>{},logout:async()=>{},isAdmin:async()=>true,listUsers:async()=>({total:0,users:[]}),listAdoptions:async()=>({total:0,items:[]}),reviews:async()=>[],reviewAdoption:async post=>post,photoUrl:async()=>'',listContributions:async()=>({total:0,items:[]}),listRescue:vi.fn(async()=>({total:1,items:[{...record,public_data:{...record.public_data,pet_name:'Luna'},status:'submitted',review_kind:'revision' as const,revision_id:revision.id,revision_version:revision.version,reason:revision.reason}]})),rescueDetail:vi.fn(),reviewRescue:vi.fn(),reviewInitialCasePacket:vi.fn(),rescueFileUrl:vi.fn(async()=> 'https://example.test/private'),caseRevisionDetail:vi.fn(async(_id,page=1)=>packet(items,page)),reviewCaseRevision:vi.fn(async(_revision,decision)=>decisionResult(items,decision)),saveCaseRevisionComments:vi.fn(async(_revision,comments,requestId)=>commentResult(comments,requestId)),...overrides};
}
async function open(client:AdminApi) {
  const view=render(<Rescues api={client}/>),user=userEvent.setup();
  await user.click(await screen.findByRole('button',{name:'Revisar edición de Luna'}));
  await screen.findByRole('region',{name:'Necesidades de la edición'});
  return {...view,user};
}
async function approveFields(user:ReturnType<typeof userEvent.setup>) {
  await user.type(screen.getByLabelText('Motivo de la decisión (visible para el rescatista)'),'Edición y documentos revisados');
  await user.click(screen.getByLabelText('Autorizo el contenido propuesto del caso y todas las necesidades de esta edición'));
}

describe('complete private case revision',()=>{
  it('blocks publication for an existing video publication blocker while keeping complete-edit correction available',async()=>{
    const items=[expense(1)],value=packet(items),blockedPacket={...value,publication_blockers:['approved_thanks_required']};
    const client=api(items,{caseRevisionDetail:vi.fn(async()=>blockedPacket)}),{user}=await open(client);
    expect(screen.getByText(/El video de agradecimiento necesita revisión antes de publicar el caso/)).toHaveTextContent('Revisa el video existente en Videos');
    await approveFields(user);
    expect(screen.getByRole('button',{name:'Aprobar edición del caso'})).toBeDisabled();
    expect(screen.getByRole('button',{name:'Pedir correcciones de la edición'})).toBeEnabled();
    expect(screen.getByRole('button',{name:'Cerrar'})).toBeEnabled();
    await user.click(screen.getByRole('button',{name:'Pedir correcciones de la edición'}));
    await waitFor(()=>expect(screen.queryByRole('dialog')).not.toBeInTheDocument());
    expect(client.reviewCaseRevision).toHaveBeenCalledWith({id:'revision',version:2},expect.objectContaining({decision:'changes_requested',expense_reviews:[]}));
  });
  it('treats 23514 as a conclusive publication refusal, releases the form and permits a different complete-edit decision',async()=>{
    const items=[expense(1)],review=vi.fn<NonNullable<AdminApi['reviewCaseRevision']>>().mockRejectedValueOnce({code:'23514',message:'private_constraint_name'}).mockImplementationOnce(async(_revision,decision)=>decisionResult(items,decision));
    const client=api(items,{reviewCaseRevision:review}),{user}=await open(client);
    await approveFields(user);await user.click(screen.getByRole('button',{name:'Aprobar edición del caso'}));
    expect(await screen.findByRole('alert')).toHaveTextContent('No se aprobó la edición porque falta una condición de publicación');
    expect(screen.queryByText(/private_constraint_name/)).not.toBeInTheDocument();
    expect(screen.queryByRole('button',{name:'Reintentar la misma decisión de la edición'})).not.toBeInTheDocument();
    expect(screen.getByRole('button',{name:'Aprobar edición del caso'})).toBeDisabled();
    for(const name of ['Cerrar','Recargar edición y archivos','No aprobar edición','Pedir correcciones de la edición'])expect(screen.getByRole('button',{name})).toBeEnabled();
    await user.click(screen.getByRole('button',{name:'No aprobar edición'}));
    await waitFor(()=>expect(screen.queryByRole('dialog')).not.toBeInTheDocument());
    expect(review.mock.calls[0][1].decision).toBe('approved');expect(review.mock.calls[1][1].decision).toBe('rejected');
    expect(review.mock.calls[1][1].request_id).not.toBe(review.mock.calls[0][1].request_id);
  });
  it.each(['approved','changes_requested','rejected'])('keeps a withdrawn case hidden through revision review and restores it only on approval (%s)',async decision=>{
    const items=[expense(1)],value=packet(items),hidden={...value,public_version_visible:false,record:{...value.record,status:'changes_requested'},base_record:{...value.base_record,status:'changes_requested'}};
    const review=vi.fn<NonNullable<AdminApi['reviewCaseRevision']>>(async(_revision,payload)=>{
      const result=decisionResult(items,payload);
      return {...result,base_record:hidden.base_record,public_version_visible:payload.decision==='approved',record:payload.decision==='approved'?result.record:hidden.record};
    });
    const client=api(items,{caseRevisionDetail:vi.fn(async()=>hidden),reviewCaseRevision:review}),{user}=await open(client);
    expect(screen.getByText(/Este caso está oculto. Solo volverá a publicarse/)).toBeInTheDocument();
    expect(screen.getByText('Versión anterior del caso (oculta)')).toBeInTheDocument();
    expect(screen.queryByText(/La versión aprobada sigue visible/)).not.toBeInTheDocument();
    expect(screen.getByText(/Cualquier corrección devuelve la edición completa y conserva el caso oculto/)).toBeInTheDocument();
    await approveFields(user);
    await user.click(screen.getByRole('button',{name:decision==='approved'?'Aprobar edición del caso':decision==='changes_requested'?'Pedir correcciones de la edición':'No aprobar edición'}));
    await waitFor(()=>expect(screen.queryByRole('dialog')).not.toBeInTheDocument());
    expect(review.mock.calls[0][1].decision).toBe(decision);
    expect(client.reviewRescue).not.toHaveBeenCalled();
  });
  it('keeps a rejected edit pending when its receipt unexpectedly republishes a withdrawn case',async()=>{
    const items=[expense(1)],value=packet(items),hidden={...value,public_version_visible:false,record:{...value.record,status:'changes_requested'},base_record:{...value.base_record,status:'changes_requested'}};
    const client=api(items,{caseRevisionDetail:vi.fn(async()=>hidden),reviewCaseRevision:vi.fn(async(_revision,payload)=>decisionResult(items,payload))}),{user}=await open(client);
    await user.type(screen.getByLabelText('Motivo de la decisión (visible para el rescatista)'),'La edición aún requiere correcciones');
    await user.click(screen.getByRole('button',{name:'No aprobar edición'}));
    await screen.findByText(/No pudimos confirmar la decisión de la edición/);
    expect(screen.getByRole('button',{name:'Reintentar la misma decisión de la edición'})).toBeEnabled();
  });
  it('approves the complete edit while preserving a withdrawn need and its historical cap, snapshot and priority',async()=>{
    const inactive=expense(2,{status:'changes_requested',financial_inactive:true,review_amount_cents:0,urgent:false,priority_reason:'Prioridad histórica conservada',approved_at:'2026-10-01T12:00:00Z',approved_snapshot:{title:'Necesidad retirada anteriormente',photos:['old/photo.jpg']}});
    const client=api([expense(1),inactive]),{user}=await open(client);
    expect(screen.getByText('Necesidad retirada previamente; sin importe disponible')).toBeInTheDocument();
    expect(screen.queryByLabelText('Importe de revisión de Necesidad 2')).not.toBeInTheDocument();
    expect(screen.queryByLabelText('Prioridad urgente para Necesidad 2')).not.toBeInTheDocument();
    expect(screen.queryByLabelText('Motivo de prioridad para Necesidad 2')).not.toBeInTheDocument();
    expect(screen.getByText('Prioridad histórica: Por antigüedad · Prioridad histórica conservada')).toBeInTheDocument();
    await approveFields(user);await user.click(screen.getByRole('button',{name:'Aprobar edición del caso'}));
    await waitFor(()=>expect(screen.queryByRole('dialog')).not.toBeInTheDocument());
    expect(vi.mocked(client.reviewCaseRevision!).mock.calls[0][1].expense_reviews).toEqual([{expense_id:'expense-1',expense_version:8,amount_cents:8000,is_urgent:false,urgency_note:'',publish_content:true},{expense_id:'expense-2',expense_version:8,amount_cents:0,is_urgent:false,urgency_note:'Prioridad histórica conservada',publish_content:true}]);
    expect(client.reviewRescue).not.toHaveBeenCalled();expect(client.reviewInitialCasePacket).not.toHaveBeenCalled();
  });
  it.each([
    {status:'approved'},
    {reimbursable_cents:0},
    {approved_snapshot:{title:'Reactivada por error'}},
    {priority_reason:'Prioridad cambiada'},
    {financial_inactive:false},
  ])('keeps an approval pending when its receipt mutates withdrawn source metadata %j',async mutation=>{
    const items=[expense(1,{status:'changes_requested',financial_inactive:true,review_amount_cents:0,approved_snapshot:{title:'Snapshot histórico'},priority_reason:'Prioridad conservada'})];
    const review=vi.fn<NonNullable<AdminApi['reviewCaseRevision']>>(async(_revision,decision)=>{
      const result=decisionResult(items,decision);
      return {...result,expenses:{...result.expenses,items:result.expenses.items.map(item=>({...item,...mutation}))}};
    });
    const client=api(items,{reviewCaseRevision:review}),{user}=await open(client);
    await approveFields(user);await user.click(screen.getByRole('button',{name:'Aprobar edición del caso'}));
    await screen.findByText(/No pudimos confirmar la decisión de la edición/);
    expect(screen.getByRole('dialog')).toBeInTheDocument();
    expect(screen.getByRole('button',{name:'Reintentar la misma decisión de la edición'})).toBeEnabled();
    expect(client.reviewRescue).not.toHaveBeenCalled();
  });
  it('reviews 21 fixed needs in the case queue, preserves the published version and partial cap, and submits one decision after all evidence',async()=>{
    const items=Array.from({length:21},(_,index)=>expense(index+1,{review_amount_cents:index===0?8000:10000,financial_locked:index===0,locked_fields:index===0?['public_data','private_data','files','priority']:[],urgent:index===0,priority_reason:index===0?'Prioridad previamente aprobada':'',files:index===0?[{path:'private/first.pdf',role:'receipt'}]:index===20?[{path:'private/last.jpg',role:'proof'}]:[]}));
    const client=api(items),{user}=await open(client);
    expect(client.caseRevisionDetail).toHaveBeenCalledWith('revision',1);
    expect(client.rescueDetail).not.toHaveBeenCalled();
    expect(screen.getByRole('region',{name:'Motivo de la edición'})).toHaveTextContent(revision.reason);
    expect(screen.getByText(/La versión aprobada sigue visible/)).toBeInTheDocument();
    expect(screen.getByText('Historia que sigue publicada')).toBeInTheDocument();
    expect(screen.getByText('Historia corregida')).toBeInTheDocument();
    expect(screen.getByText(/Se conservarán los medios ya aprobados/)).toBeInTheDocument();
    expect(screen.getByLabelText('Importe de revisión de Necesidad 1')).toHaveTextContent('Importe autorizado que se conserva: $80.00');
    expect(screen.getByLabelText('Prioridad urgente para Necesidad 1')).toBeChecked();
    expect(screen.getByLabelText('Prioridad urgente para Necesidad 1')).toBeDisabled();
    expect(screen.getByLabelText('Motivo de prioridad para Necesidad 1')).toBeDisabled();
    expect(screen.queryByLabelText(/Monto autorizado|Monto reembolsable/)).not.toBeInTheDocument();
    const approve=()=>screen.getByRole('button',{name:'Aprobar edición del caso'});
    await approveFields(user);expect(approve()).toBeDisabled();
    await user.click(screen.getByRole('link',{name:'Abrir PDF de Necesidad 1 · Archivo 1'}));
    await user.click(screen.getByLabelText('Revisé el archivo 1 de Necesidad 1'));
    await user.click(screen.getByRole('button',{name:'Necesidades siguientes'}));
    await screen.findByLabelText('Importe de revisión de Necesidad 21');
    expect(approve()).toBeDisabled();
    fireEvent.load(screen.getByAltText('Evidencia del gasto · privada de Necesidad 21 · Archivo 1'));
    await user.click(screen.getByLabelText('Revisé el archivo 1 de Necesidad 21'));
    expect(approve()).toBeEnabled();
    await user.click(screen.getByRole('button',{name:'Necesidades anteriores'}));
    expect(await screen.findByLabelText('Revisé el archivo 1 de Necesidad 1')).toBeChecked();
    await user.click(approve());
    await waitFor(()=>expect(screen.queryByRole('dialog')).not.toBeInTheDocument());
    expect(client.reviewCaseRevision).toHaveBeenCalledTimes(1);
    const [reviewed,decision]=vi.mocked(client.reviewCaseRevision!).mock.calls[0];
    expect(reviewed).toEqual({id:'revision',version:2});
    expect(decision.expense_reviews).toEqual(items.map((item,index)=>({expense_id:item.id,expense_version:8,amount_cents:index===0?8000:10000,is_urgent:index===0,urgency_note:index===0?'Prioridad previamente aprobada':'',publish_content:true})));
    expect(client.reviewRescue).not.toHaveBeenCalled();expect(client.reviewInitialCasePacket).not.toHaveBeenCalled();
  });

  it('requires a review motive and returns the whole revision with exact comments without withdrawing the public case',async()=>{
    const client=api(),{user}=await open(client);
    await user.click(screen.getByRole('button',{name:'Pedir correcciones de la edición'}));
    expect(await screen.findByRole('alert')).toHaveTextContent('al menos 5 caracteres');
    expect(client.reviewCaseRevision).not.toHaveBeenCalled();
    await user.type(screen.getByLabelText('Comentario para Consulta'),'Aclara la valoración');
    await user.type(screen.getByLabelText('Comentario para Necesidad 1'),'Confirma el comprobante');
    expect(screen.getByRole('button',{name:'Pedir correcciones de la edición'})).toBeDisabled();
    await user.click(screen.getByRole('button',{name:'Guardar comentarios'}));
    await screen.findByText('Comentarios guardados. La decisión de la edición sigue pendiente.');
    expect(client.saveCaseRevisionComments).toHaveBeenCalledWith({id:'revision',version:2},[{target_kind:'planned',target_id:'planned',target_version:4,body:'Aclara la valoración'},{target_kind:'expense',target_id:'expense-1',target_version:8,body:'Confirma el comprobante'}],expect.any(String));
    await user.type(screen.getByLabelText('Motivo de la decisión (visible para el rescatista)'),'Corrige las observaciones de esta edición');
    await user.click(screen.getByRole('button',{name:'Pedir correcciones de la edición'}));
    await waitFor(()=>expect(screen.queryByRole('dialog')).not.toBeInTheDocument());
    expect(client.reviewCaseRevision).toHaveBeenCalledWith({id:'revision',version:2},expect.objectContaining({decision:'changes_requested',expense_reviews:[]}));
    expect(client.reviewRescue).not.toHaveBeenCalled();
  });

  it('protects unsaved revision comments across closing, refresh and page changes',async()=>{
    const items=Array.from({length:21},(_,index)=>expense(index+1)),client=api(items),{user}=await open(client);
    await user.type(screen.getByLabelText('Comentario para Necesidad 1'),'Observación pendiente');
    for(const name of ['Cerrar','Recargar edición y archivos','Necesidades siguientes'])await user.click(screen.getByRole('button',{name}));
    expect(screen.getByRole('dialog')).toBeInTheDocument();
    expect(client.caseRevisionDetail).toHaveBeenCalledTimes(1);
    expect(screen.getByLabelText('Comentario para Necesidad 1')).toHaveValue('Observación pendiente');
    await user.click(screen.getByRole('button',{name:'Descartar comentarios'}));
    await user.click(screen.getByRole('button',{name:'Necesidades siguientes'}));
    await screen.findByLabelText('Importe de revisión de Necesidad 21');
    expect(client.caseRevisionDetail).toHaveBeenLastCalledWith('revision',2);
  });

  it('freezes an uncertain approval including its financial cap until the same request is reconciled',async()=>{
    const items=[expense(1)],review=vi.fn<NonNullable<AdminApi['reviewCaseRevision']>>().mockRejectedValueOnce(new TypeError('network')).mockImplementationOnce(async(_revision,decision)=>decisionResult(items,decision));
    const client=api(items,{reviewCaseRevision:review}),{user}=await open(client);
    await approveFields(user);await user.click(screen.getByRole('button',{name:'Aprobar edición del caso'}));
    await screen.findByText(/No pudimos confirmar la decisión de la edición/);
    for(const name of ['Cerrar','Recargar edición y archivos','No aprobar edición','Revisar edición de Luna'])expect(screen.getByRole('button',{name})).toBeDisabled();
    expect(screen.getByLabelText('Prioridad urgente para Necesidad 1')).toBeDisabled();
    expect(screen.getByLabelText('Comentario para Necesidad 1')).toBeDisabled();
    await user.click(screen.getByRole('button',{name:'Reintentar la misma decisión de la edición'}));
    await waitFor(()=>expect(screen.queryByRole('dialog')).not.toBeInTheDocument());
    expect(review.mock.calls[1]).toEqual(review.mock.calls[0]);
    expect(review.mock.calls[0][1].expense_reviews[0].amount_cents).toBe(8000);
  });

  it('retries uncertain revision comments with the same destination versions and request ID',async()=>{
    const save=vi.fn<NonNullable<AdminApi['saveCaseRevisionComments']>>().mockRejectedValueOnce(new TypeError('network')).mockImplementationOnce(async(_revision,comments,requestId)=>commentResult(comments,requestId));
    const client=api([expense(1)],{saveCaseRevisionComments:save}),{user}=await open(client);
    await user.type(screen.getByLabelText('Comentario para Necesidad 1'),'Confirma el folio');
    await user.click(screen.getByRole('button',{name:'Guardar comentarios'}));
    await screen.findByText(/No pudimos confirmar los comentarios/);
    expect(screen.getByRole('button',{name:'Cerrar'})).toBeDisabled();
    expect(screen.getByLabelText('Comentario para Necesidad 1')).toBeDisabled();
    await user.click(screen.getByRole('button',{name:'Reintentar el mismo guardado'}));
    await screen.findByText('Comentarios guardados. La decisión de la edición sigue pendiente.');
    expect(save.mock.calls[1]).toEqual(save.mock.calls[0]);
  });

  it.each([{code:'40001'},{status:403}])('purges private proposals and never falls back to public case approval after refusal %j',async failure=>{
    const client=api([expense(1)],{reviewCaseRevision:vi.fn().mockRejectedValue(failure)}),{user}=await open(client);
    await user.type(screen.getByLabelText('Motivo de la decisión (visible para el rescatista)'),'Corrige los documentos');
    await user.click(screen.getByRole('button',{name:'Pedir correcciones de la edición'}));
    await screen.findByRole('alert');
    if('code' in failure&&failure.code==='40001')expect(screen.getByRole('alert')).toHaveTextContent('Pide al rescatista retirar y reenviar la edición completa');
    expect(screen.queryByLabelText('Importe de revisión de Necesidad 1')).not.toBeInTheDocument();
    expect(screen.queryByText('Historia corregida')).not.toBeInTheDocument();
    expect(screen.queryByRole('button',{name:'Reintentar la misma decisión de la edición'})).not.toBeInTheDocument();
    expect(client.reviewRescue).not.toHaveBeenCalled();expect(client.reviewInitialCasePacket).not.toHaveBeenCalled();
  });

  it('keeps missing evidence unavailable and revalidates access before showing partial file results',async()=>{
    const items=[expense(1,{files:[{path:'private/missing.pdf',role:'receipt'}]})],client=api(items,{rescueFileUrl:vi.fn().mockRejectedValue({status:404})}),{user}=await open(client);
    expect(client.caseRevisionDetail).toHaveBeenCalledTimes(2);
    expect(screen.getByRole('alert')).toHaveTextContent('Archivo no disponible');
    expect(screen.getByLabelText('Revisé el archivo 1 de Necesidad 1')).toBeDisabled();
    await approveFields(user);
    expect(screen.getByRole('button',{name:'Aprobar edición del caso'})).toBeDisabled();
  });

  it('ignores a late decision after the authenticated API changes',async()=>{
    let finish!:(value:CaseRevisionDecisionResult)=>void;
    const items=[expense(1)],review=vi.fn<NonNullable<AdminApi['reviewCaseRevision']>>(()=>new Promise(resolve=>{finish=resolve;}));
    const first=api(items,{reviewCaseRevision:review}),{user,rerender}=await open(first);
    await user.type(screen.getByLabelText('Motivo de la decisión (visible para el rescatista)'),'Datos privados anteriores');
    await user.click(screen.getByRole('button',{name:'No aprobar edición'}));
    const second=api();rerender(<Rescues api={second}/>);
    await user.click(await screen.findByRole('button',{name:'Revisar edición de Luna'}));
    await screen.findByRole('region',{name:'Necesidades de la edición'});
    await act(async()=>finish(decisionResult(items,review.mock.calls[0][1])));
    expect(within(screen.getByRole('dialog')).getByLabelText('Motivo de la decisión (visible para el rescatista)')).toHaveValue('');
    expect(second.reviewCaseRevision).not.toHaveBeenCalled();
  });
});
