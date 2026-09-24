begin;

alter table private.dopmi_guardian_subscriptions
 add column management_revision bigint not null default 0 check(management_revision>=0),
 add column cancellation_requested_at timestamptz;

-- Intent is distinct from a verified Stripe change. Only the owner can submit
-- an intent; no client can mark it applied, mutate price IDs or cancel history.
create table private.dopmi_guardian_requests (
 id uuid primary key default gen_random_uuid(),
 donor_id uuid not null references public.profiles(id),
 subscription_id text not null references private.dopmi_guardian_subscriptions(stripe_subscription_id),
 request_key uuid not null,
 kind text not null check(kind in ('amount','cancel')),
 expected_revision bigint not null check(expected_revision>=0),
 revision bigint not null check(revision=expected_revision+1),
 previous_gross_cents bigint not null check(previous_gross_cents between 1000 and 1000000),
 new_gross_cents bigint,
 consent_version text,
 status text not null default 'pending' check(status in ('pending','applied','superseded')),
 created_at timestamptz not null default now(),
 applied_at timestamptz,
 unique(donor_id,request_key), unique(subscription_id,revision),
 check((kind='amount' and new_gross_cents between 1000 and 1000000 and new_gross_cents<>previous_gross_cents
   and new_gross_cents is not null and consent_version is not null and consent_version='guardian-2026-09-24')
   or (kind='cancel' and new_gross_cents is null and consent_version is null)),
 check((status='applied')=(applied_at is not null))
);
create unique index dopmi_guardian_one_request on private.dopmi_guardian_requests(subscription_id) where status='pending';
create index dopmi_guardian_request_history on private.dopmi_guardian_requests(donor_id,revision desc);
alter table private.dopmi_guardian_requests enable row level security;
revoke all on private.dopmi_guardian_requests from public,anon,authenticated;

create function private.dopmi_guardian_request_view(target uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',r.id,'kind',r.kind,'revision',r.revision,'status',r.status,
 'previous_gross_cents',r.previous_gross_cents,'new_gross_cents',r.new_gross_cents,
 'created_at',r.created_at,'applied_at',r.applied_at)
 from private.dopmi_guardian_requests r where r.id=target;
$$;
revoke all on function private.dopmi_guardian_request_view(uuid) from public,anon,authenticated;

create function private.dopmi_guardian_plan_view(owner_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('gross_cents',p.gross_cents,'currency','mxn','revision',p.management_revision,
 'status',case when p.status='canceled' then 'canceled' when p.cancellation_requested_at is not null then 'cancel_requested' else 'active' end,
 'cancellation_requested_at',p.cancellation_requested_at,
 'pending_request',(select private.dopmi_guardian_request_view(r.id) from private.dopmi_guardian_requests r
 where r.subscription_id=p.stripe_subscription_id and r.status='pending'),
 'payment_in_flight',exists(select 1 from private.dopmi_guardian_collection_jobs j where j.subscription_id=p.stripe_subscription_id
 and j.pay_requested_at is not null and j.status not in ('paid','skipped')),
 'requests',coalesce((select jsonb_agg(x.value order by x.revision desc) from
 (select r.revision,private.dopmi_guardian_request_view(r.id) as value from private.dopmi_guardian_requests r
 where r.donor_id=owner_id order by r.revision desc limit 10)x),'[]'::jsonb))
 from private.dopmi_guardian_subscriptions p where p.donor_id=owner_id;
$$;
revoke all on function private.dopmi_guardian_plan_view(uuid) from public,anon,authenticated;

create function public.dopmi_guardian_plan() returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=auth.uid();
begin
 if actor is null then raise exception 'Inicia sesión para consultar tu Guardián' using errcode='42501'; end if;
 return private.dopmi_guardian_plan_view(actor);
end; $$;
revoke all on function public.dopmi_guardian_plan() from public,anon,authenticated,service_role;
grant execute on function public.dopmi_guardian_plan() to authenticated;

create function public.dopmi_guardian_request(
 request_kind text, request_key uuid, expected_revision bigint,
 new_gross_cents bigint default null, consent_version text default null
) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); p private.dopmi_guardian_subscriptions; r private.dopmi_guardian_requests;
begin
 if actor is null then raise exception 'Inicia sesión para administrar tu Guardián' using errcode='42501'; end if;
 if request_kind is null or request_kind not in ('amount','cancel') or request_key is null
 or expected_revision is null or expected_revision<0
 or (request_kind='amount' and (new_gross_cents is null or new_gross_cents not between 1000 and 1000000
   or consent_version is distinct from 'guardian-2026-09-24'))
 or (request_kind='cancel' and (new_gross_cents is not null or consent_version is not null)) then
 raise exception 'Solicitud Guardián inválida' using errcode='22023'; end if;
 -- A suspended owner may still stop future payments. Increasing or changing
 -- the authorization requires the same active/confirmed identity as signup.
 if request_kind='amount' then perform private.dopmi_require_actor(); end if;
 select * into p from private.dopmi_guardian_subscriptions where donor_id=actor for update;
 if not found then raise exception 'No tienes un plan Guardián registrado' using errcode='42501'; end if;
 select * into r from private.dopmi_guardian_requests q where q.donor_id=actor and q.request_key=dopmi_guardian_request.request_key;
 if found then
 if r.kind is distinct from request_kind or r.expected_revision is distinct from expected_revision
 or r.new_gross_cents is distinct from new_gross_cents or r.consent_version is distinct from consent_version then
 raise exception 'La clave de solicitud ya se usó con otros datos' using errcode='22023'; end if;
 return jsonb_build_object('request',private.dopmi_guardian_request_view(r.id),'plan',private.dopmi_guardian_plan_view(actor));
 end if;
 if p.management_revision<>expected_revision then raise exception 'Tu plan cambió; actualiza antes de confirmar' using errcode='40001'; end if;
 if p.status<>'active' or p.cancellation_requested_at is not null then
 raise exception 'Guardián ya está cancelado o tiene una cancelación pendiente' using errcode='22023'; end if;
 if request_kind='amount' then
 if p.gross_cents=new_gross_cents then raise exception 'El nuevo monto debe ser diferente' using errcode='22023'; end if;
 if exists(select 1 from private.dopmi_guardian_requests q where q.subscription_id=p.stripe_subscription_id and q.status='pending') then
 raise exception 'Ya tienes una solicitud pendiente' using errcode='55000'; end if;
 else
 -- Only an unprocessed amount intent can be superseded; its audit row stays.
 update private.dopmi_guardian_requests q set status='superseded'
 where q.subscription_id=p.stripe_subscription_id and q.kind='amount' and q.status='pending';
 end if;
 insert into private.dopmi_guardian_requests(donor_id,subscription_id,request_key,kind,expected_revision,revision,
 previous_gross_cents,new_gross_cents,consent_version)
 values(actor,p.stripe_subscription_id,request_key,request_kind,expected_revision,expected_revision+1,
 p.gross_cents,new_gross_cents,consent_version) returning * into r;
 update private.dopmi_guardian_subscriptions set management_revision=r.revision,
 cancellation_requested_at=case when request_kind='cancel' then now() else cancellation_requested_at end where donor_id=actor;
 return jsonb_build_object('request',private.dopmi_guardian_request_view(r.id),'plan',private.dopmi_guardian_plan_view(actor));
end; $$;
revoke all on function public.dopmi_guardian_request(text,uuid,bigint,bigint,text) from public,anon,authenticated,service_role;
grant execute on function public.dopmi_guardian_request(text,uuid,bigint,bigint,text) to authenticated;

create function private.dopmi_guardian_collection_allowed(target_subscription text) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from private.dopmi_guardian_subscriptions p where p.stripe_subscription_id=target_subscription
 and p.status='active' and p.cancellation_requested_at is null
 and not exists(select 1 from private.dopmi_guardian_requests r where r.subscription_id=target_subscription and r.status='pending'));
$$;
revoke all on function private.dopmi_guardian_collection_allowed(text) from public,anon,authenticated;

-- Serialize cancellation with the one-shot pay marker, and new amount intents
-- with invoice preparation. Already prepared current cycles keep their amount;
-- an authorized payment must still reconcile, even after cancellation.
do $patch$
declare definition text:=pg_get_functiondef('public.dopmi_guardian_collection_server(text,jsonb)'::regprocedure);
 old_text text; new_text text;
begin
 old_text:='where p1.status=''active'' and s.status=''ready'' order by';
 new_text:='where p1.status=''active'' and s.status=''ready'' and private.dopmi_guardian_collection_allowed(p1.stripe_subscription_id) order by';
 if position(old_text in definition)=0 then raise exception 'Review collection sources before migration'; end if;
 definition:=replace(definition,old_text,new_text);
 old_text:='where p1.stripe_subscription_id=data->>''subscription_id'' and p1.status=''active'' and s.status=''ready'');';
 new_text:='where p1.stripe_subscription_id=data->>''subscription_id'' and p1.status=''active'' and s.status=''ready'' and private.dopmi_guardian_collection_allowed(p1.stripe_subscription_id));';
 if position(old_text in definition)=0 then raise exception 'Review collection source before migration'; end if;
 definition:=replace(definition,old_text,new_text);
 old_text:='hold:=public.dopmi_guardian_reserve(p.donor_id,(data->>''cycle_key'')::uuid,p.gross_cents);';
 new_text:='if not private.dopmi_guardian_collection_allowed(p.stripe_subscription_id) then raise exception ''Solicitud Guardián pendiente'' using errcode=''55000''; end if; '||old_text;
 if position(old_text in definition)=0 then raise exception 'Review collection preparation before migration'; end if;
 definition:=replace(definition,old_text,new_text);
 old_text:='select * into j from private.dopmi_guardian_collection_jobs where invoice_id=target for update;';
 new_text:='if operation=''authorize_pay'' then perform 1 from private.dopmi_guardian_subscriptions where stripe_subscription_id=(select subscription_id from private.dopmi_guardian_collection_jobs where invoice_id=target) for update; end if; '||old_text;
 if position(old_text in definition)=0 then raise exception 'Review collection locks before migration'; end if;
 definition:=replace(definition,old_text,new_text);
 old_text:='and exists(select 1 from private.dopmi_guardian_subscriptions where stripe_subscription_id=j.subscription_id and status=''active'')';
 new_text:='and exists(select 1 from private.dopmi_guardian_subscriptions where stripe_subscription_id=j.subscription_id and status=''active'' and cancellation_requested_at is null)';
 if position(old_text in definition)=0 then raise exception 'Review collection pay guard before migration'; end if;
 definition:=replace(definition,old_text,new_text);
 execute definition;
end $patch$;
commit;
