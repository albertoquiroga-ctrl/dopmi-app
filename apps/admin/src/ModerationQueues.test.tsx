import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { expect, test, vi } from 'vitest';
import ModerationQueues from './ModerationQueues';
import type { AdminApi, CaseUpdate, ContentReport, RescuerPublicProfile } from './api';

const update: CaseUpdate = {
  id: 'update-one', case_id: 'case-one', owner_id: 'owner-one',
  body: 'Luna respondió bien al tratamiento.', photos: [], status: 'submitted',
  version: 4, review_feedback: '', submitted_at: '2026-09-26T20:00:00Z', created_at: '2026-09-26T19:00:00Z',
};

function api(): AdminApi {
  const report: ContentReport = {id:'report-one',target_type:'case',target_id:'case-one',reason:'unsafe',details:'Revisar',status:'open',resolution:'',created_at:'2026-09-26',updated_at:'2026-09-26'};
  const profile: RescuerPublicProfile = {id:'profile-one',owner_id:'owner-one',display_name:'Refugio Luna',bio:'Rescate responsable.',city:'Monterrey',region:'Nuevo León',instagram_url:'https://instagram.com/refugioluna',facebook_url:'',avatar_path:'owner/avatar.jpg',status:'submitted',version:3,review_feedback:'',submitted_at:'2026-09-26',updated_at:'2026-09-26'};
  return {
    session: async()=>true, watch:()=>()=>{}, login:async()=>{}, logout:async()=>{}, isAdmin:async()=>true,
    listUsers:async()=>({total:0,users:[]}), listAdoptions:async()=>({total:0,items:[]}), reviews:async()=>[], reviewAdoption:async p=>p, photoUrl:async()=>'',
    listRescue:async()=>({total:0,items:[]}), rescueDetail:async()=>{throw new Error('unused')}, reviewRescue:async r=>r, rescueFileUrl:async()=>'', listContributions:async()=>({total:0,items:[]}),
    listCaseUpdates:vi.fn(async()=>({total:1,items:[update]})), reviewCaseUpdate:vi.fn(async(item,decision)=>({...item,status:decision})), caseUpdatePhotoUrl:async()=>'',
    listReports:vi.fn(async()=>({total:1,items:[report]})), resolveReport:vi.fn(async()=>{}),
    listRescuerProfiles:vi.fn(async()=>({total:1,items:[profile]})), reviewRescuerProfile:vi.fn(async(item,decision)=>({...item,status:decision})), profileAvatarUrl:async()=>'https://example.test/avatar.jpg',
  };
}

test('publishes a reviewed update and resolves a persisted report', async()=>{
  const client=api(); const user=userEvent.setup(); render(<ModerationQueues api={client}/>);
  expect(await screen.findByText('Luna respondió bien al tratamiento.')).toBeInTheDocument();
  await user.click(screen.getByRole('button',{name:'Publicar'}));
  expect(client.reviewCaseUpdate).toHaveBeenCalledWith(update,'published','');
  await user.click(screen.getByRole('button',{name:'Perfiles'}));
  expect(await screen.findByText('Refugio Luna')).toBeInTheDocument();
  await user.click(screen.getByRole('button',{name:'Publicar perfil'}));
  expect(client.reviewRescuerProfile).toHaveBeenCalledWith(expect.objectContaining({id:'profile-one'}),'published','');
  await user.click(screen.getByRole('button',{name:'Reportes'}));
  expect(await screen.findByText('Revisar')).toBeInTheDocument();
  await user.click(screen.getByRole('button',{name:'Resolver'}));
  expect(client.resolveReport).toHaveBeenCalledWith('report-one','resolved','Contenido revisado y atendido.');
});
