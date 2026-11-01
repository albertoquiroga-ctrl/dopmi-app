import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import Rescues, { amount } from './Rescues';
import type { AdminApi, RescueRecord } from './api';
const record: RescueRecord={id:'expense',owner_id:'owner',kind:'expense',parent_id:'case',public_data:{title:'Comida de Luna',category:'food',round_label:'Primera ronda'},private_data:{amount_cents:'25050',vendor:'Veterinaria'},files:[{path:'private/receipt.jpg',role:'receipt'}],status:'submitted',version:9,feedback:'',reimbursable_cents:0,urgent:false,priority_reason:'',submitted_at:'2026-09-13T12:00:00Z',updated_at:'2026-09-13T12:00:00Z'};
function api(overrides:Partial<AdminApi>={}):AdminApi { return {session:async()=>true,watch:()=>()=>{},login:async()=>{},logout:async()=>{},isAdmin:async()=>true,listUsers:async()=>({total:0,users:[]}),listAdoptions:async()=>({total:0,items:[]}),reviews:async()=>[],reviewAdoption:async p=>p,photoUrl:async()=>'',listContributions:async()=>({total:0,items:[]}),listRescue:vi.fn(async()=>({total:1,items:[record]})),rescueDetail:vi.fn(async()=>({record,verified:true,case_status:'approved',history:[]})),rescueFileUrl:vi.fn(async()=> 'https://example.test/signed'),reviewRescue:vi.fn(async r=>({...r,status:'approved'})),...overrides}; }
async function open(client:AdminApi) { render(<Rescues api={client}/>);const user=userEvent.setup();await user.click(await screen.findByRole('button',{name:'Revisar Comida de Luna'}));await screen.findByText('Solo para revisión privada');return user; }
describe('rescue review',()=>{
  for(const kind of ['case','expense'] as const) it(`reviews an ordinary account ${kind} without a Dopmi badge while retaining evidence and public approval`,async()=>{
    const ordinary={...record,kind,parent_id:kind==='case'?null:'case'};
    const client=api({rescueDetail:vi.fn(async()=>({record:ordinary,verified:false,case_status:kind==='expense'?'approved':null,history:[]}))});
    const user=await open(client), button=screen.getByRole('button',{name:'Aprobar solicitud'});
    expect(button).toBeDisabled();
    fireEvent.load(screen.getByAltText('Comprobante · privado 1'));
    await user.click(screen.getByLabelText('Revisé el archivo 1'));expect(button).toBeDisabled();
    await user.click(screen.getByLabelText('Autorizo los textos y las fotos marcadas para publicación'));
    await user.type(screen.getByLabelText('Motivo de la decisión (visible para el rescatista)'),'Expediente revisado');
    expect(button).toBeEnabled();await user.click(button);
    await waitFor(()=>expect(client.reviewRescue).toHaveBeenCalledWith(ordinary,expect.objectContaining({decision:'approved',publish_content:true})));
  });
  it('still refuses an ordinary account expense whose parent case is closed',async()=>{
    const client=api({rescueDetail:vi.fn(async()=>({record,verified:false,case_status:'closed',history:[]}))}),user=await open(client);
    fireEvent.load(screen.getByAltText('Comprobante · privado 1'));
    await user.click(screen.getByLabelText('Revisé el archivo 1'));
    await user.click(screen.getByLabelText('Autorizo los textos y las fotos marcadas para publicación'));
    expect(screen.getByRole('button',{name:'Aprobar solicitud'})).toBeDisabled();expect(client.reviewRescue).not.toHaveBeenCalled();
  });
  it('converts pesos exactly and rejects malformed money',()=>{expect(amount('250.50')).toBe(25050);expect(amount('0.01')).toBe(1);for(const v of ['-1','1.001','1e3','NaN','0','1000000.01'])expect(amount(v)).toBeNull();});
  it('requires loaded evidence and explicit public approval, then sends the exact version',async()=>{
    const client=api(),user=await open(client);
    const button=screen.getByRole('button',{name:'Aprobar solicitud'});
    expect(button).toBeDisabled();expect(screen.getByLabelText('Revisé el archivo 1')).toBeDisabled();
    fireEvent.load(screen.getByAltText('Comprobante · privado 1'));
    await user.click(screen.getByLabelText('Revisé el archivo 1'));
    expect(button).toBeDisabled();
    await user.click(screen.getByLabelText('Autorizo los textos y las fotos marcadas para publicación'));
    await user.type(screen.getByLabelText('Motivo de la decisión (visible para el rescatista)'),'Comprobante validado');
    await user.click(button);
    await waitFor(()=>expect(client.reviewRescue).toHaveBeenCalledWith(record,expect.objectContaining({amount_cents:25050,publish_content:true,decision:'approved'})));
  });
  it('does not approve over the paid expense and preserves the review form',async()=>{
    const client=api(),user=await open(client);fireEvent.load(screen.getByAltText('Comprobante · privado 1'));
    await user.click(screen.getByLabelText('Revisé el archivo 1'));await user.click(screen.getByLabelText('Autorizo los textos y las fotos marcadas para publicación'));
    await user.type(screen.getByLabelText('Motivo de la decisión (visible para el rescatista)'),'Comprobante validado');
    const input=screen.getByLabelText('Monto reembolsable en pesos MXN');await user.clear(input);await user.type(input,'251');
    await user.click(screen.getByRole('button',{name:'Aprobar solicitud'}));expect(await screen.findByRole('alert')).toHaveTextContent('no exceder');expect(client.reviewRescue).not.toHaveBeenCalled();expect(input).toHaveValue('251');
  });
  it('clears private details when a review conflicts and requires a fresh load',async()=>{
    const client=api({reviewRescue:vi.fn(async()=>{throw {code:'40001',message:'La solicitud cambió'};})}),user=await open(client);
    await user.type(screen.getByLabelText('Motivo de la decisión (visible para el rescatista)'),'Adjunta una foto legible');await user.click(screen.getByRole('button',{name:'Pedir correcciones'}));
    await screen.findByText('La solicitud cambió');expect(screen.queryByText('Solo para revisión privada')).not.toBeInTheDocument();expect(screen.queryByRole('button',{name:'Aprobar solicitud'})).not.toBeInTheDocument();
  });
  it('discards the private record when the server denies access',async()=>{
    const client=api({rescueDetail:vi.fn(async()=>{throw {code:'42501'};})});render(<Rescues api={client}/>);const user=userEvent.setup();await user.click(await screen.findByRole('button',{name:'Revisar Comida de Luna'}));await screen.findByText('El acceso cambió. Actualiza la lista para volver a comprobarlo.');expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
  });
});
