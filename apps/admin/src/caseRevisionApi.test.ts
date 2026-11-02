import { describe, expect, it, vi } from 'vitest';
import { createAdminApi, type CaseRevisionDecision } from './api';

const revision={id:'revision',version:2};
const decision:CaseRevisionDecision={request_id:'decision-request',decision:'approved',note:'Edición completa revisada',publish_content:true,expense_reviews:[{expense_id:'expense',expense_version:8,amount_cents:8000,is_urgent:false,urgency_note:'',publish_content:true}]};
const comments=[{target_kind:'expense' as const,target_id:'expense',target_version:8,body:'Confirma el folio'}];
const session=(id='reviewer',access_token='synthetic-token')=>({data:{session:{user:{id},access_token}},error:null});

describe('private case revision API',()=>{
  it('reads proposed pages and sends one revision decision with the exact financial cap and identity',async()=>{
    const rpc=vi.fn().mockResolvedValue({data:{request_id:'decision-request'},error:null}),getSession=vi.fn(async()=>session());
    const api=createAdminApi({rpc,auth:{getSession}} as unknown as Parameters<typeof createAdminApi>[0]);
    await api.caseRevisionDetail!('revision',2);
    expect(rpc).toHaveBeenLastCalledWith('dopmi_admin_case_revision_packet',{revision_id:'revision',expense_page:2});
    await api.reviewCaseRevision!(revision,decision);
    expect(rpc).toHaveBeenLastCalledWith('dopmi_review_case_revision',{revision_id:'revision',expected_version:2,...decision});
    await api.saveCaseRevisionComments!(revision,comments,'comment-request');
    expect(rpc).toHaveBeenLastCalledWith('dopmi_comment_case_revision_needs',{revision_id:'revision',expected_version:2,comments,request_id:'comment-request'});
  });
  it.each(['PGRST202','42501','40001'])('never falls back to published case or individual expense RPCs on revision read failure %s',async code=>{
    const rpc=vi.fn().mockResolvedValue({data:null,error:{code}});
    const api=createAdminApi({rpc} as unknown as Parameters<typeof createAdminApi>[0]);
    await expect(api.caseRevisionDetail!('revision')).rejects.toEqual({code});
    expect(rpc).toHaveBeenCalledExactlyOnceWith('dopmi_admin_case_revision_packet',{revision_id:'revision',expense_page:1});
  });
  it.each(['decision','comments'] as const)('binds an uncertain %s request to its original authenticated actor',async kind=>{
    const rpc=vi.fn().mockResolvedValue({data:null,error:{code:'network'}}),getSession=vi.fn().mockResolvedValueOnce(session()).mockResolvedValueOnce(session('another-reviewer'));
    const api=createAdminApi({rpc,auth:{getSession}} as unknown as Parameters<typeof createAdminApi>[0]);
    const send=()=>kind==='decision'?api.reviewCaseRevision!(revision,decision):api.saveCaseRevisionComments!(revision,comments,'comment-request');
    await expect(send()).rejects.toEqual({code:'network'});
    await expect(send()).rejects.toEqual({code:'42501'});
    expect(rpc).toHaveBeenCalledTimes(1);
  });
  it('allows the same actor to reconcile the identical revision decision after token refresh',async()=>{
    const rpc=vi.fn().mockResolvedValueOnce({data:null,error:{code:'network'}}).mockResolvedValueOnce({data:{request_id:'decision-request'},error:null});
    const getSession=vi.fn().mockResolvedValueOnce(session('reviewer','old-token')).mockResolvedValueOnce(session('reviewer','new-token'));
    const api=createAdminApi({rpc,auth:{getSession}} as unknown as Parameters<typeof createAdminApi>[0]);
    await expect(api.reviewCaseRevision!(revision,decision)).rejects.toEqual({code:'network'});
    await expect(api.reviewCaseRevision!(revision,decision)).resolves.toEqual({request_id:'decision-request'});
    expect(rpc.mock.calls[1]).toEqual(rpc.mock.calls[0]);
  });
});
