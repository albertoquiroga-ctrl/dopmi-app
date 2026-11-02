import { describe, expect, it } from 'vitest';
import type { CaseRevisionExpense, CaseRevisionPacket, RescueRecord } from './api';
import { mergeRevisionPacketPage, revisionExpenseReviews } from './caseRevisionPacket';

const record:RescueRecord={id:'case',owner_id:'owner',kind:'case',parent_id:null,public_data:{story:'Propuesta'},private_data:{},files:[],status:'approved',version:4,feedback:'',reimbursable_cents:0,urgent:false,priority_reason:'',submitted_at:null,updated_at:''};
const expense:CaseRevisionExpense={...record,id:'expense',kind:'expense',parent_id:'case',version:8,private_data:{amount_cents:'10000'},reimbursable_cents:8000,financial_locked:false,financial_inactive:false,locked_fields:[],review_amount_cents:8000,files:[{path:'private/proof.jpg',role:'proof'}]};
const packet:CaseRevisionPacket={revision:{id:'revision',case_id:'case',owner_id:'owner',base_case_version:4,version:2,status:'submitted',reason:'Corrección de historia',submitted_at:null,updated_at:''},record,public_version_visible:true,publication_blockers:[],base_record:{...record,public_data:{story:'Publicada'}},expenses:{total:1,page:1,items:[expense]},expense_ids:['expense'],expense_versions:{expense:8},need_comments:[],preserved_media:[]};

describe('case revision frozen packet',()=>{
  it('keeps a partial historical authorization on text edits and uses the server full amount for a changed paid amount',()=>{
    const records=mergeRevisionPacketPage(null,packet).records;
    expect(revisionExpenseReviews(packet,records,{},()=>true)).toEqual([{expense_id:'expense',expense_version:8,amount_cents:8000,is_urgent:false,urgency_note:'',publish_content:true}]);
    const changed={...expense,private_data:{amount_cents:'15000'},review_amount_cents:15000};
    expect(revisionExpenseReviews(packet,{expense:changed},{},()=>true)?.[0].amount_cents).toBe(15000);
    expect(revisionExpenseReviews(packet,{expense:{...expense,private_data:{amount_cents:'010000'}}},{},()=>true)?.[0].amount_cents).toBe(8000);
    expect(revisionExpenseReviews(packet,records,{},()=>false)).toBeNull();
    for(const review_amount_cents of [0,-1,10001,1.2,NaN])expect(revisionExpenseReviews(packet,{expense:{...expense,review_amount_cents}},{},()=>true)).toBeNull();
  });
  it('allows zero only for an explicitly inactive source and keeps its exact historical priority',()=>{
    const inactive={...expense,status:'changes_requested',financial_inactive:true,review_amount_cents:0,urgent:false,priority_reason:'Prioridad histórica conservada'};
    expect(mergeRevisionPacketPage(null,{...packet,expenses:{...packet.expenses,items:[inactive]}}).records.expense).toEqual(inactive);
    expect(revisionExpenseReviews(packet,{expense:inactive},{expense:{urgent:true,urgency:'Prioridad inventada'}},()=>true)).toEqual([{expense_id:'expense',expense_version:8,amount_cents:0,is_urgent:false,urgency_note:'Prioridad histórica conservada',publish_content:true}]);
    for(const invalid of [
      {...inactive,status:'approved'},
      {...inactive,financial_inactive:false},
      {...inactive,financial_inactive:undefined},
      {...inactive,review_amount_cents:8000},
      {...expense,review_amount_cents:0},
    ])expect(revisionExpenseReviews(packet,{expense:invalid as CaseRevisionExpense},{},()=>true)).toBeNull();
  });
  it('accepts a private correction to a withdrawn case while rejecting mixed or unsupported publication states',()=>{
    const hidden={...packet,public_version_visible:false,record:{...packet.record,status:'changes_requested'},base_record:{...packet.base_record,status:'changes_requested'}};
    expect(mergeRevisionPacketPage(null,hidden).records.expense).toEqual(expense);
    for(const invalid of [
      {...hidden,public_version_visible:true},
      {...hidden,record:{...hidden.record,status:'approved'}},
      {...hidden,record:{...hidden.record,status:'closed'},base_record:{...hidden.base_record,status:'closed'}},
      {...hidden,record:{...hidden.record,status:'draft'},base_record:{...hidden.base_record,status:'draft'}},
    ])expect(()=>mergeRevisionPacketPage(null,invalid)).toThrow(expect.objectContaining({code:'40001'}));
  });
  it('preserves locked financial priority and only accepts justified explicit changes on unlocked needs',()=>{
    const locked={...expense,financial_locked:true,urgent:true,priority_reason:'Prioridad ya aprobada'};
    expect(revisionExpenseReviews(packet,{expense:locked},{expense:{urgent:false,urgency:''}},()=>true)?.[0]).toMatchObject({amount_cents:8000,is_urgent:true,urgency_note:'Prioridad ya aprobada'});
    expect(revisionExpenseReviews(packet,{expense},{expense:{urgent:true,urgency:'bad'}},()=>true)).toBeNull();
    expect(revisionExpenseReviews(packet,{expense},{expense:{urgent:true,urgency:'  Atención inmediata  '}},()=>true)?.[0]).toMatchObject({is_urgent:true,urgency_note:'Atención inmediata'});
  });
  it('requires all 21 immutable needs and their evidence before enabling a complete decision',()=>{
    const items=Array.from({length:21},(_,index)=>({...expense,id:`expense-${index}`,files:[{path:`private/${index}.jpg`,role:'proof'}]}));
    const manifest={...packet,expense_ids:items.map(item=>item.id),expense_versions:Object.fromEntries(items.map(item=>[item.id,item.version])),expenses:{total:21,page:1,items:items.slice(0,20)}};
    const first=mergeRevisionPacketPage(null,manifest);
    expect(revisionExpenseReviews(manifest,first.records,{},()=>true)).toBeNull();
    const complete=mergeRevisionPacketPage(first,{...manifest,expenses:{total:21,page:2,items:items.slice(20)}});
    expect(revisionExpenseReviews(manifest,complete.records,{},path=>path!=='private/20.jpg')).toBeNull();
    expect(revisionExpenseReviews(manifest,complete.records,{},()=>true)).toHaveLength(21);
  });
  it('rejects mixed versions, identities, ownership and changing caps instead of constructing new membership',()=>{
    const cache=mergeRevisionPacketPage(null,packet);
    for(const changed of [
      {...packet,revision:{...packet.revision,id:'different'}},
      {...packet,revision:{...packet.revision,version:3}},
      {...packet,revision:{...packet.revision,reason:'bad'}},
      {...packet,base_record:{...packet.base_record,version:5}},
      {...packet,expense_ids:['expense','expense']},
      {...packet,expense_versions:{expense:9}},
      {...packet,expenses:{...packet.expenses,total:2}},
      {...packet,expenses:{...packet.expenses,items:[{...expense,owner_id:'other'}]}},
      {...packet,expenses:{...packet.expenses,items:[{...expense,review_amount_cents:9000}]}},
    ])expect(()=>mergeRevisionPacketPage(cache,changed)).toThrow(expect.objectContaining({code:'40001'}));
  });
});
