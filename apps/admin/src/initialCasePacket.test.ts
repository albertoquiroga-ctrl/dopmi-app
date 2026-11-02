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
  it('uses the full paid snapshot, requires all evidence and only assigns explicitly justified urgency',()=>{
    const packet=detail.initial_packet!,records={expense:{...child,urgent:true,priority_reason:'Author urgency'}};
    expect(packetExpenseReviews(packet,records,{},()=>true)).toEqual([{expense_id:'expense',expense_version:8,amount_cents:20000,is_urgent:false,urgency_note:'',publish_content:true}]);
    expect(packetExpenseReviews(packet,{}, {},()=>true)).toBeNull();
    expect(packetExpenseReviews(packet,records,{},()=>false)).toBeNull();
    expect(packetExpenseReviews(packet,records,{expense:{urgent:true,urgency:'bad'}},()=>true)).toBeNull();
    expect(packetExpenseReviews(packet,records,{expense:{urgent:true,urgency:'  Atención inmediata  '}},()=>true)).toEqual([{expense_id:'expense',expense_version:8,amount_cents:20000,is_urgent:true,urgency_note:'Atención inmediata',publish_content:true}]);
    for(const amount_cents of ['0','-1','1.2','NaN','100000001','9007199254740992'])expect(packetExpenseReviews(packet,{expense:{...child,private_data:{amount_cents}}},{},()=>true)).toBeNull();
  });
});
