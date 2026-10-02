begin;
create table private.dopmi_support_requests (
  owner_id uuid not null references public.profiles(id) on delete cascade,
  request_id uuid not null,
  topic text not null,
  case_name text not null default '',
  message text not null,
  created_at timestamptz not null default now(),
  primary key(owner_id,request_id),
  check(topic in ('support_rules','contribute','guardian','adopt','verification','publish_cases','funds_evidence','account','trust_safety')),
  check(char_length(case_name)<=120),
  check(char_length(btrim(message)) between 1 and 4000)
);
alter table private.dopmi_support_requests enable row level security;
revoke all on private.dopmi_support_requests from public,anon,authenticated,service_role;
create index dopmi_support_requests_rate on private.dopmi_support_requests(owner_id,created_at);

create function public.dopmi_submit_support_request(target_request uuid,payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); item private.dopmi_support_requests;
  topic_value text; case_value text; message_value text;
begin
  if target_request is null or target_request::text !~ '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
    or jsonb_typeof(payload) is distinct from 'object' or octet_length(payload::text)>18000
    or payload-array['topic','case_name','message']::text[] <> '{}'::jsonb
    or jsonb_typeof(payload->'topic') is distinct from 'string'
    or jsonb_typeof(payload->'message') is distinct from 'string'
    or (payload ? 'case_name' and jsonb_typeof(payload->'case_name') is distinct from 'string') then
    raise exception 'Solicitud inválida' using errcode='22023';
  end if;
  topic_value:=payload->>'topic'; case_value:=btrim(coalesce(payload->>'case_name',''));
  message_value:=btrim(payload->>'message');
  if topic_value not in ('support_rules','contribute','guardian','adopt','verification','publish_cases','funds_evidence','account','trust_safety')
    or char_length(case_value)>120 or char_length(message_value) not between 1 and 4000
    or message_value ~ '^[[:space:]]*$' then
    raise exception 'Solicitud inválida' using errcode='22023';
  end if;
  -- Serialize per account, including rate checks and response-loss retries.
  perform pg_advisory_xact_lock(hashtextextended('dopmi-support:'||actor::text,0));
  select * into item from private.dopmi_support_requests where owner_id=actor and request_id=target_request;
  if found then
    if item.topic<>topic_value or item.case_name<>case_value or item.message<>message_value then
      raise exception 'La solicitud cambió. Usa un identificador nuevo.' using errcode='40001';
    end if;
  else
    if (select count(*) from private.dopmi_support_requests where owner_id=actor and created_at>now()-interval '1 hour')>=5 then
      raise exception 'Espera antes de enviar otra solicitud.' using errcode='22023';
    end if;
    insert into private.dopmi_support_requests(owner_id,request_id,topic,case_name,message)
    values(actor,target_request,topic_value,case_value,message_value) returning * into item;
  end if;
  return jsonb_build_object('request_id',item.request_id,'status','received','created_at',item.created_at);
end;
$$;
create function public.dopmi_my_support_request(target_request uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); item private.dopmi_support_requests;
begin
  select * into item from private.dopmi_support_requests where owner_id=actor and request_id=target_request;
  if not found then return null; end if;
  return jsonb_build_object('request_id',item.request_id,'status','received','created_at',item.created_at);
end;
$$;
revoke all on function public.dopmi_submit_support_request(uuid,jsonb),public.dopmi_my_support_request(uuid) from public,anon,authenticated,service_role;
grant execute on function public.dopmi_submit_support_request(uuid,jsonb),public.dopmi_my_support_request(uuid) to authenticated;
commit;
