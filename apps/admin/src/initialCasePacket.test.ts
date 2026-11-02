import { describe, expect, it } from 'vitest';
import type { RescueDetail, RescueRecord } from './api';
import { mergeInitialPacketPage, packetExpenseReviews } from './initialCasePacket';

const record:RescueRecord={id:'case',owner_id:'owner',kind:'case',parent_id:null,public_data:{},private_data:{},files:[],status:'submitted',version:4,feedback:'',reimbursable_cents:0,urgent:false,priority_reason:'',submitted_at:null,updated_at:''};
const child:RescueRecord={...record,id:'expense',kind:'expense',parent_id:'case',version:8,submission_id:'packet',private_data:{amount_cents:'20000'},files:[{path:'private/proof.jpg',role:'proof'}]};
const detail:RescueDetail={record,verified:false,case_status:null,history:[],initial_packet:{id:'packet',case_version:4,source_case_version:3,expense_ids:['expense']},expenses:{total:1,page:1,items:[child]}};

describe('initial packet membership',()=>{
  it('requires exact totals, page membership and ownership before retaining any frozen child',()=>{
    expect(mergeInitialPacketPage(null,detail).records).toEqual({expense:child});
    for(const value of [
      {...detail,expenses:{...detail.expenses!,total:2}},
      {...detail,expenses:{...detail.expenses!,items:[]}},
      {...detail,expenses:{...detail.expenses!,items:[{...child,submission_id:'another'}]}},
      {...detail,expenses:{...detail.expenses!,items:[{...child,owner_id:'another'}]}},
      {...detail,expenses:{...detail.expenses!,items:[{...child,parent_id:'another'}]}},
      {...detail,record:{...record,version:5}},
      {...detail,initial_packet:{...detail.initial_packet!,expense_ids:['expense','expense']}},
    ])expect(()=>mergeInitialPacketPage(null,value)).toThrow(expect.objectContaining({code:'40001'}));
  });
  it('rejects a changed manifest or frozen version between pages',()=>{
    const cache=mergeInitialPacketPage(null,detail);
    expect(()=>mergeInitialPacketPage(cache,{...detail,initial_packet:{...detail.initial_packet!,id:'another'}})).toThrow(expect.objectContaining({code:'40001'}));
    expect(()=>mergeInitialPacketPage(cache,{...detail,expenses:{...detail.expenses!,items:[{...child,version:9}]}})).toThrow(expect.objectContaining({code:'40001'}));
  });
  it('requires explicit money, all evidence and justified urgency; never inherits the author request',()=>{
    const packet=detail.initial_packet!,records={expense:child},parse=(value:string)=>value==='150'?15000:null;
    const draft={expense:{pesos:'150',urgent:false,urgency:'Unused author request'}};
    expect(packetExpenseReviews(packet,records,{},()=>true,parse)).toBeNull();
    expect(packetExpenseReviews(packet,{},draft,()=>true,parse)).toBeNull();
    expect(packetExpenseReviews(packet,records,draft,()=>false,parse)).toBeNull();
    expect(packetExpenseReviews(packet,records,{expense:{...draft.expense,urgent:true,urgency:'bad'}},()=>true,parse)).toBeNull();
    expect(packetExpenseReviews(packet,records,draft,()=>true,()=>20001)).toBeNull();
    expect(packetExpenseReviews(packet,records,draft,()=>true,parse)).toEqual([{expense_id:'expense',expense_version:8,amount_cents:15000,is_urgent:false,urgency_note:'',publish_content:true}]);
  });
});
