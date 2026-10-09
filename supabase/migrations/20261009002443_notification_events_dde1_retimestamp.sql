begin;
alter table public.dopmi_notifications drop constraint dopmi_notifications_kind_check;
alter table public.dopmi_notifications add constraint dopmi_notifications_kind_check check(kind in ('review','message','rescue','contribution','guardian'));
alter table public.dopmi_notifications add column body text not null default '',
 add column tone text check(tone in ('positive','negative','pending')),
 add column target_kind text check(target_kind in ('thread','post','rescue','profile','history','received_history')),
 add column target_id uuid, add column photo_path text,
 add column photo_record_id uuid references public.dopmi_rescue_records(id) on delete set null,
 add column photo_purpose text check(photo_purpose in ('rescue','adoption'));

-- Play 301 routes unknown notifications through post_id and would open /null.
-- New financial producers are default-off, enabled only for explicit QA accounts
-- whose installed candidate supports target_kind. No client-controlled enrollment.
create table private.dopmi_notification_candidate_cohort (
 user_id uuid primary key references auth.users(id) on delete cascade,
 enabled boolean not null default false,
 enabled_at timestamptz,
 check (not enabled or enabled_at is not null)
);
alter table private.dopmi_notification_candidate_cohort enable row level security;
revoke all on private.dopmi_notification_candidate_cohort from public,anon,authenticated,service_role;
-- Consumption records transitions even outside QA, preventing enrollment or
-- later unrelated processor updates from replaying an already consumed event.
create table private.dopmi_notification_event_consumption (
 user_id uuid not null references auth.users(id) on delete cascade,
 kind text not null check(kind in ('contribution','guardian')),
 source_id uuid not null,
 consumed_at timestamptz not null default now(),
 primary key(user_id,kind,source_id)
);
alter table private.dopmi_notification_event_consumption enable row level security;
revoke all on private.dopmi_notification_event_consumption from public,anon,authenticated,service_role;
create function private.dopmi_notification_candidate_gate() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.kind in ('contribution','guardian') then
  insert into private.dopmi_notification_event_consumption(user_id,kind,source_id) values(new.user_id,new.kind,new.source_id) on conflict do nothing;
  if not found then return null; end if;
 end if;
 if new.kind in ('contribution','guardian') and not exists (
  select 1 from private.dopmi_notification_candidate_cohort c
  where c.user_id=new.user_id and c.enabled
 ) then return null; end if;
 return new;
end;
$$;
revoke all on function private.dopmi_notification_candidate_gate() from public,anon,authenticated,service_role;
create trigger dopmi_notification_candidate_gate before insert on public.dopmi_notifications
 for each row execute function private.dopmi_notification_candidate_gate();
-- Operator activation is separate from deployment: confirm the new installed
-- build for each QA account, then insert enabled=true/enabled_at=now().
-- Disabling stops future events; no replay/backfill or ledger mutation occurs.

create function private.dopmi_notification_decorate() returns trigger language plpgsql security definer set search_path='' as $$
declare r public.dopmi_rescue_records; a public.dopmi_adoptions; p public.dopmi_rescuer_profiles;
begin
 if new.kind in ('contribution','guardian') and new.photo_record_id is not null then
  select * into r from public.dopmi_rescue_records where id=new.photo_record_id;
  if private.dopmi_rescue_public_visible(r) then new.photo_path:=r.approved_snapshot->'photos'->>0; new.photo_purpose:='rescue'; end if;
 end if;
 if new.kind='message' and new.thread_id is not null then
  new.target_kind:='thread'; new.target_id:=new.thread_id;
  select left(m.body,240) into new.body from public.dopmi_messages m join public.dopmi_threads t on t.id=m.thread_id where m.id=new.source_id and t.id=new.thread_id and new.user_id in(t.owner_id,t.adopter_id);
  new.body:=coalesce(new.body,'');
  select listing.photos[1] into new.photo_path from public.dopmi_threads t join public.dopmi_adoptions listing on listing.id=t.post_id where t.id=new.thread_id and new.user_id in(t.owner_id,t.adopter_id) and listing.status='published';
  if new.photo_path is not null then new.photo_purpose:='adoption'; end if;
 elsif new.rescue_id is not null then
  select * into r from public.dopmi_rescue_records where id=new.rescue_id and owner_id=new.user_id;
  if found then
   new.target_kind:='rescue'; new.target_id:=r.id;
   new.body:=r.feedback;
   new.tone:=case when r.status='approved' then 'positive' when r.status in ('changes_requested','rejected') then 'negative' else 'pending' end;
   if private.dopmi_rescue_public_visible(r) then new.photo_path:=r.approved_snapshot->'photos'->>0; new.photo_purpose:='rescue'; end if;
  end if;
 elsif new.post_id is not null then
  select * into a from public.dopmi_adoptions where id=new.post_id and owner_id=new.user_id;
  if found then
   new.target_kind:='post'; new.target_id:=a.id;
   new.body:=a.review_feedback;
   new.tone:=case when a.status='published' then 'positive' when a.status in ('changes_requested','rejected') then 'negative' else 'pending' end;
   if a.status='published' then new.photo_path:=a.photos[1]; new.photo_purpose:='adoption'; end if;
  end if;
 elsif new.kind='review' and new.source_id=new.user_id then
  new.target_kind:='profile'; new.target_id:=new.user_id;
  select * into p from public.dopmi_rescuer_profiles where owner_id=new.user_id;
  if found then new.body:=p.review_feedback; new.tone:=case when p.status='published' then 'positive' when p.status in ('changes_requested','rejected') then 'negative' else 'pending' end; end if;
 end if;
 return new;
end;
$$;
-- Read marking preserves event tone; review upserts change title and rederive metadata.
create trigger dopmi_notification_decorate before insert or update of title on public.dopmi_notifications for each row execute function private.dopmi_notification_decorate();
revoke all on function private.dopmi_notification_decorate() from public,anon,authenticated;

create function private.dopmi_notification_projection(n public.dopmi_notifications,actor uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare target text:=n.target_kind; target_id uuid:=n.target_id; available boolean:=false; photo text; purpose text;
 r public.dopmi_rescue_records; a public.dopmi_adoptions;
begin
 if n.user_id<>actor or actor is distinct from auth.uid() then raise exception 'Notificación no disponible' using errcode='42501'; end if;
 -- Resolve historical rows without rewriting them or restoring consumed events.
 if target is null then
  if n.thread_id is not null then target:='thread'; target_id:=n.thread_id;
  elsif n.rescue_id is not null then target:='rescue'; target_id:=n.rescue_id;
  elsif n.post_id is not null then target:='post'; target_id:=n.post_id;
  elsif n.kind='review' and n.source_id=actor then target:='profile'; target_id:=actor; end if;
 end if;
 if target='thread' then
  available:=exists(select 1 from public.dopmi_threads t where t.id=target_id and actor in(t.owner_id,t.adopter_id));
  if available then select listing.photos[1] into photo from public.dopmi_threads t join public.dopmi_adoptions listing on listing.id=t.post_id where t.id=target_id and listing.status='published'; purpose:='adoption'; end if;
 elsif target='post' then
  select * into a from public.dopmi_adoptions where id=target_id and owner_id=actor;
  available:=found;
  if available and a.status='published' then photo:=a.photos[1]; purpose:='adoption'; end if;
 elsif target='rescue' then
  select * into r from public.dopmi_rescue_records where id=target_id and owner_id=actor;
  available:=found;
  if available and private.dopmi_rescue_public_visible(r) then photo:=r.approved_snapshot->'photos'->>0; purpose:='rescue'; end if;
 elsif target='profile' then available:=target_id=actor;
 elsif target in ('history','received_history') then
  available:=true;
  if n.photo_record_id is not null then
   select * into r from public.dopmi_rescue_records where id=n.photo_record_id;
   if private.dopmi_rescue_public_visible(r) then photo:=r.approved_snapshot->'photos'->>0; purpose:='rescue'; end if;
  end if;
 end if;
 return (to_jsonb(n)-'user_id'-'source_id'-'photo_path'-'photo_purpose'-'photo_record_id')||jsonb_build_object(
  'target_kind',case when available then target end,'target_id',case when available then target_id end,
  'available',available,'photo_path',photo,'photo_purpose',purpose,
  'thumb_style',case when photo is not null then 'photo' when n.kind='guardian' or target='profile' then 'brand' else 'icon' end);
end;
$$;
revoke all on function private.dopmi_notification_projection(public.dopmi_notifications,uuid) from public,anon,authenticated;

create function public.dopmi_notification_activity(page_number integer default 1,page_size integer default 20) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); result jsonb;
begin
 if page_number is null or page_number<1 or page_size is null or page_size not between 1 and 50 then raise exception 'Página inválida' using errcode='22023'; end if;
 select jsonb_build_object('total',(select count(*) from public.dopmi_notifications where user_id=actor),
  'items',coalesce((select jsonb_agg(private.dopmi_notification_projection(n,actor) order by n.created_at desc,n.id desc)
    from (select * from public.dopmi_notifications where user_id=actor order by created_at desc,id desc limit page_size offset (page_number::bigint-1)*page_size)n),'[]'::jsonb)) into result;
 return result;
end;
$$;
create function public.dopmi_notification_open(notification_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); item public.dopmi_notifications;
begin
 update public.dopmi_notifications set read_at=coalesce(read_at,now()) where id=notification_id and user_id=actor returning * into item;
 if not found then raise exception 'Notificación no disponible' using errcode='42501'; end if;
 return private.dopmi_notification_projection(item,actor);
end;
$$;
revoke all on function public.dopmi_notification_activity(integer,integer),public.dopmi_notification_open(uuid) from public,anon,authenticated,service_role;
grant execute on function public.dopmi_notification_activity(integer,integer),public.dopmi_notification_open(uuid) to authenticated;

create function private.dopmi_contribution_notification() returns trigger language plpgsql security definer set search_path='' as $$
declare event text; tone text; title text; case_id uuid; receiver_body text; historical_cents bigint;
begin
 if new.refund_status='refunded' then event:='refunded'; tone:='positive'; title:='Tu +Apoyo fue devuelto';
 elsif new.refund_status='attention' then event:='refund_attention'; tone:='negative'; title:='La devolución de tu +Apoyo requiere revisión';
 elsif new.refund_status='pending' then event:='refund_pending'; tone:='pending'; title:='La devolución de tu +Apoyo está en proceso';
 elsif new.payment_status='confirmed' then event:='confirmed'; tone:='positive'; title:='Tu +Apoyo fue confirmado';
 elsif new.payment_status='canceled' then event:='not_paid'; tone:='negative'; title:='Tu +Apoyo se cerró sin pago confirmado';
 else return new; end if;
 select parent_id into case_id from public.dopmi_rescue_records where id=new.expense_id;
 if tg_op='INSERT' or new.payment_status is distinct from old.payment_status or new.refund_status is distinct from old.refund_status then
 insert into public.dopmi_notifications(user_id,kind,source_id,title,body,tone,target_kind,photo_record_id)
 values(new.donor_id,'contribution',md5(new.id::text||':'||event||':donor')::uuid,title,'Consulta el estado y los importes reales en tu historial.',tone,'history',case_id) on conflict(user_id,kind,source_id) do nothing;
 end if;
 if tg_op='UPDATE' and new.transfer_status is not distinct from old.transfer_status and new.allocated_cents is not distinct from old.allocated_cents and new.stripe_reversal_id is not distinct from old.stripe_reversal_id then return new; end if;
 if (new.transfer_status='reversed' and new.stripe_reversal_id is not null)
 or (new.payment_status='confirmed' and new.allocated_cents>0) then
  receiver_body:='Consulta el neto y su estado en tu historial.';
  if new.transfer_status='reversed' and new.stripe_reversal_id is not null then
   select (adjustment.before_state->>'allocated_cents')::bigint into historical_cents
    from private.dopmi_refund_adjustments adjustment where adjustment.donation_id=new.id;
   if historical_cents is null and tg_op='UPDATE' then historical_cents:=old.allocated_cents; end if;
   if historical_cents>0 then receiver_body:=format('Se revirtió una transferencia de $%s MXN. Consulta su estado en tu historial.',round(historical_cents::numeric/100,2)); end if;
  end if;
  event:=case when new.transfer_status='reversed' then 'reversed' when new.transfer_status='transferred' then 'transferred' when new.transfer_status='attention' then 'attention' else 'assigned' end;
  tone:=case when event in ('attention','reversed') then 'negative' when event='transferred' then 'positive' else 'pending' end;
  title:=case event when 'transferred' then 'El neto de un +Apoyo fue transferido' when 'reversed' then 'Una transferencia de +Apoyo fue revertida' when 'attention' then 'Una transferencia de +Apoyo requiere revisión' else 'Recibiste una asignación de +Apoyo' end;
  insert into public.dopmi_notifications(user_id,kind,source_id,title,body,tone,target_kind,photo_record_id)
  values(new.rescuer_id,'contribution',md5(new.id::text||':'||event||':rescuer')::uuid,title,receiver_body,tone,'received_history',case_id) on conflict(user_id,kind,source_id) do nothing;
 end if;
 return new;
end;
$$;
create trigger dopmi_contribution_notification after insert or update of payment_status,refund_status,transfer_status,allocated_cents,stripe_reversal_id on public.dopmi_donations for each row execute function private.dopmi_contribution_notification();
revoke all on function private.dopmi_contribution_notification() from public,anon,authenticated;

create function private.dopmi_guardian_allocation_notification() returns trigger language plpgsql security definer set search_path='' as $$
declare person uuid; event text; tone text; title text; case_id uuid;
begin
 if tg_op='UPDATE' and new.allocated_cents is not distinct from old.allocated_cents and new.reversed_cents is not distinct from old.reversed_cents and new.stripe_transfer_id is not distinct from old.stripe_transfer_id and new.transferred_at is not distinct from old.transferred_at then return new; end if;
 if new.allocated_cents<=0 then return new; end if;
 select owner_id,parent_id into person,case_id from public.dopmi_rescue_records where id=new.expense_id and kind='expense';
 event:=case when new.reversed_cents=new.allocated_cents then 'reversed' when new.reversed_cents>0 then 'partial_reversal' when new.stripe_transfer_id is not null and new.transferred_at is not null then 'transferred' else 'assigned' end;
 tone:=case when event in ('reversed','partial_reversal') then 'negative' when event='transferred' then 'positive' else 'pending' end;
 title:=case event when 'transferred' then 'Una asignación Guardián fue transferida' when 'reversed' then 'Una asignación Guardián fue revertida' when 'partial_reversal' then 'Una asignación Guardián tiene una reversión parcial' else 'Recibiste una asignación Guardián' end;
 insert into public.dopmi_notifications(user_id,kind,source_id,title,body,tone,target_kind,photo_record_id)
 values(person,'guardian',md5(new.cycle_id::text||':'||new.expense_id::text||':'||event)::uuid,title,'Consulta las asignaciones y los importes de tu manada en tu historial.',tone,'received_history',case_id) on conflict(user_id,kind,source_id) do nothing;
 return new;
end;
$$;
create trigger dopmi_guardian_allocation_notification after insert or update of allocated_cents,reversed_cents,stripe_transfer_id,transferred_at on private.dopmi_guardian_allocations for each row execute function private.dopmi_guardian_allocation_notification();
revoke all on function private.dopmi_guardian_allocation_notification() from public,anon,authenticated;

create function private.dopmi_guardian_settlement_notification() returns trigger language plpgsql security definer set search_path='' as $$
declare person uuid; event text; tone text; title text;
begin
 if tg_op='UPDATE' and new.refund_cents is not distinct from old.refund_cents and new.refunded_at is not distinct from old.refunded_at and new.stripe_refund_id is not distinct from old.stripe_refund_id then return new; end if;
 select donor_id into person from private.dopmi_guardian_cycles where id=new.cycle_id;
 event:=case when new.refunded_at is not null and new.stripe_refund_id is not null then 'refunded' when new.refund_cents>0 then 'refund_pending' else 'confirmed' end;
 tone:=case when event='refund_pending' then 'pending' else 'positive' end;
 title:=case event when 'refunded' then 'Tu pago Guardián fue devuelto' when 'refund_pending' then 'Tu devolución Guardián está en proceso' else 'Tu pago Guardián fue confirmado' end;
 insert into public.dopmi_notifications(user_id,kind,source_id,title,body,tone,target_kind)
 values(person,'guardian',md5(new.cycle_id::text||':'||event||':donor')::uuid,title,'Consulta el pago, las asignaciones y su conciliación en tu historial.',tone,'history') on conflict(user_id,kind,source_id) do nothing;
 return new;
end;
$$;
create trigger dopmi_guardian_settlement_notification after insert or update of refund_cents,refunded_at,stripe_refund_id on private.dopmi_guardian_settlements for each row execute function private.dopmi_guardian_settlement_notification();
revoke all on function private.dopmi_guardian_settlement_notification() from public,anon,authenticated;

create function private.dopmi_guardian_skip_notification() returns trigger language plpgsql security definer set search_path='' as $$
declare person uuid;
begin
 if tg_op='UPDATE' and new.status is not distinct from old.status then return new; end if;
 if new.status<>'skipped' then return new; end if;
 select donor_id into person from private.dopmi_guardian_cycles where id=new.cycle_id;
 insert into public.dopmi_notifications(user_id,kind,source_id,title,body,tone,target_kind)
 values(person,'guardian',md5(new.cycle_id::text||':skipped:donor')::uuid,'Este ciclo Guardián fue omitido','No hubo cargo ni deuda para este ciclo. Consulta el motivo en tu historial.','pending','history') on conflict(user_id,kind,source_id) do nothing;
 return new;
end;
$$;
create trigger dopmi_guardian_skip_notification after insert or update of status on private.dopmi_guardian_collection_jobs for each row execute function private.dopmi_guardian_skip_notification();
revoke all on function private.dopmi_guardian_skip_notification() from public,anon,authenticated;

create function private.dopmi_guardian_adjustment_notification() returns trigger language plpgsql security definer set search_path='' as $$
declare person uuid;
begin
 if tg_op='UPDATE' and new.status is not distinct from old.status then return new; end if;
 select donor_id into person from private.dopmi_guardian_cycles where id=new.cycle_id;
 insert into public.dopmi_notifications(user_id,kind,source_id,title,body,tone,target_kind)
 values(person,'guardian',md5(new.cycle_id::text||':adjustment:'||new.status||':donor')::uuid,
  case new.status when 'completed' then 'La devolución Guardián fue conciliada' when 'review' then 'La devolución Guardián requiere revisión' else 'La devolución Guardián está en conciliación' end,
  'Consulta la devolución y las reversiones de transferencia en tu historial.',case new.status when 'completed' then 'positive' when 'review' then 'negative' else 'pending' end,'history') on conflict(user_id,kind,source_id) do nothing;
 return new;
end;
$$;
create trigger dopmi_guardian_adjustment_notification after insert or update of status on private.dopmi_guardian_refund_adjustments for each row execute function private.dopmi_guardian_adjustment_notification();
revoke all on function private.dopmi_guardian_adjustment_notification() from public,anon,authenticated;
commit;
