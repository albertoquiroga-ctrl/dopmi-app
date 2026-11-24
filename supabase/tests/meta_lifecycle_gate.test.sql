begin;
set local search_path=public,extensions;
create extension if not exists pgtap with schema extensions;
select no_plan();

select has_function('public','dopmi_meta_lifecycle_enabled',array[]::text[],
  'the public lifecycle preflight exists without actor or identifier input');
select function_returns('public','dopmi_meta_lifecycle_enabled',array[]::text[],'boolean',
  'the preflight exposes only an operational boolean');
select ok(has_function_privilege('anon','public.dopmi_meta_lifecycle_enabled()','execute'),
  'pre-login clients can read the operational gate');
select ok(has_function_privilege('authenticated','public.dopmi_meta_lifecycle_enabled()','execute'),
  'signed-in clients can read the same gate');
select ok(has_function_privilege('service_role','public.dopmi_meta_lifecycle_enabled()','execute'),
  'service verification can read the same gate');
select ok(not has_table_privilege('anon','private.dopmi_meta_ads_gate','select,insert,update,delete'),
  'the read RPC does not grant anonymous table access');
select ok(not has_table_privilege('authenticated','private.dopmi_meta_ads_gate','select,insert,update,delete'),
  'the read RPC does not grant account table access');
select ok(not has_function_privilege('anon','public.dopmi_set_meta_ads_gate(boolean)','execute'),
  'pre-login clients cannot open the gate');
select ok(not has_function_privilege('authenticated','public.dopmi_set_meta_ads_gate(boolean)','execute'),
  'accounts cannot open the gate');

update private.dopmi_meta_ads_gate set enabled=false where singleton;
set local role anon;
select is(public.dopmi_meta_lifecycle_enabled(),false,'anonymous client sees the closed gate');
reset role;
update private.dopmi_meta_ads_gate set enabled=true where singleton;
set local role anon;
select is(public.dopmi_meta_lifecycle_enabled(),true,'anonymous client sees the existing gate open');
set local role authenticated;
select is(public.dopmi_meta_lifecycle_enabled(),true,'account sees the same operational state');
reset role;
delete from private.dopmi_meta_ads_gate where singleton;
set local role anon;
select is(public.dopmi_meta_lifecycle_enabled(),false,'missing singleton fails closed');
reset role;

select * from finish();
rollback;
