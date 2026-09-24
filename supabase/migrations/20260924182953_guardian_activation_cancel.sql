begin;
alter table private.dopmi_guardian_activations
 add column cancellation_requested_at timestamptz;

-- The activation key is already private to its owner and is the cancellation
-- identity. Repeating this RPC never creates another intent or another payment.
create function public.dopmi_guardian_cancel_activation(activation_key uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); target uuid; a private.dopmi_guardian_activations;
 p private.dopmi_guardian_subscriptions;
begin
 if actor is null or activation_key is null then raise exception 'Inicia sesión para cancelar' using errcode='42501'; end if;
 select c.id into target from private.dopmi_guardian_cycles c join private.dopmi_guardian_activations x on x.cycle_id=c.id
 where c.donor_id=actor and c.cycle_key=activation_key;
 if target is null then raise exception 'Alta no disponible' using errcode='42501'; end if;
 -- Also held by schedule prepare/claim/ready, before taking any row lock.
 perform pg_advisory_xact_lock(hashtextextended('dopmi-guardian-stop:'||target,0));
 select * into a from private.dopmi_guardian_activations where cycle_id=target for update;
 select * into p from private.dopmi_guardian_subscriptions where donor_id=actor for update;
 if found then
   if p.status='active' and p.cancellation_requested_at is null then
     perform public.dopmi_guardian_request('cancel',gen_random_uuid(),p.management_revision);
   end if;
 else
   update private.dopmi_guardian_activations set cancellation_requested_at=coalesce(cancellation_requested_at,now()),
     status=case when status='pending' and attempts=0 then 'expired' else status end where cycle_id=target;
   -- Settlement takes the same activation row first. A payment that arrives
   -- afterwards follows the existing full-refund path; delivered funds stay.
   update private.dopmi_guardian_cycles set status='expired',reserved_cents=0 where id=target and status='reserved';
   update private.dopmi_guardian_schedule_jobs set status='canceled',lease_until=null
     where cycle_id=target and attempts=0 and subscription_id is null;
 end if;
 return public.dopmi_guardian_state();
end; $$;
revoke all on function public.dopmi_guardian_cancel_activation(uuid) from public,anon,authenticated,service_role;
grant execute on function public.dopmi_guardian_cancel_activation(uuid) to authenticated;

-- Keep recovering a possibly-created calendar with its original request keys.
-- A canceled activation with no claimed schedule can never start one.
create or replace function private.dopmi_guardian_schedule_eligible(target_cycle uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from private.dopmi_guardian_activations a
 join private.dopmi_guardian_settlements s on s.cycle_id=a.cycle_id
 join public.profiles p on p.id=a.donor_id join auth.users u on u.id=p.id
 where a.cycle_id=target_cycle and a.status='settled' and s.allocated_cents>0 and s.refund_cents=0
 and ((a.cancellation_requested_at is null and p.account_status='active' and u.email_confirmed_at is not null)
 or (a.cancellation_requested_at is not null and exists(select 1 from private.dopmi_guardian_schedule_jobs j
 where j.cycle_id=a.cycle_id and j.attempts>0 and j.status<>'canceled')))
 and exists(select 1 from private.dopmi_guardian_jobs j where j.cycle_id=a.cycle_id and j.kind='transfer')
 and not exists(select 1 from private.dopmi_guardian_jobs j where j.cycle_id=a.cycle_id and (j.kind<>'transfer' or j.status<>'done')));
$$;

do $patch$
declare definition text; old_text text; new_text text;
begin
 definition:=pg_get_functiondef('public.dopmi_guardian_schedule_server(text,jsonb)'::regprocedure);
 old_text:='target:=(data->>''cycle_id'')::uuid;';
 new_text:=old_text||' perform pg_advisory_xact_lock(hashtextextended(''dopmi-guardian-stop:''||target,0));';
 if position(old_text in definition)=0 then raise exception 'Review schedule locks'; end if;
 definition:=replace(definition,old_text,new_text);
 old_text:='elsif operation=''ready'' then';
 new_text:=old_text||' if exists(select 1 from private.dopmi_guardian_activations where cycle_id=target and cancellation_requested_at is not null) then raise exception ''Cancelación de alta pendiente'' using errcode=''40001''; end if;';
 if position(old_text in definition)=0 then raise exception 'Review schedule registration'; end if;
 execute replace(definition,old_text,new_text);

 definition:=pg_get_functiondef('public.dopmi_guardian_activation_server(text,jsonb)'::regprocedure);
 old_text:='where donor_id=donor and status in (''pending'',''settled'',''attention''))';
 new_text:='where donor_id=donor and (status in (''pending'',''settled'',''attention'') or cancellation_requested_at is not null))';
 if position(old_text in definition)=0 then raise exception 'Review reactivation guard'; end if;
 execute replace(definition,old_text,new_text);

 definition:=pg_get_functiondef('public.dopmi_guardian_state()'::regprocedure);
 old_text:='''checkout_expires_at'',a.checkout_expires_at,';
 new_text:=old_text||' ''cancellation_requested_at'',a.cancellation_requested_at,
 ''cancellation_status'',case when a.cancellation_requested_at is null then null
 when a.status in (''refund_pending'',''refunded'',''expired'',''failed'',''no_capacity'') or s.status=''canceled''
 or (a.status=''settled'' and s.cycle_id is null) then ''stopped''
 when a.status=''attention'' or s.status=''attention'' then ''attention'' else ''pending'' end,';
 if position(old_text in definition)=0 then raise exception 'Review owner projection'; end if;
 execute replace(definition,old_text,new_text);
end $patch$;
commit;
