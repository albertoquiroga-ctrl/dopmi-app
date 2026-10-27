begin;

-- Only newly submitted support cases wait privately for verified Stripe readiness.
-- No historical row is rewritten; expenses, adoption, approval and money retain their gates.
alter table public.dopmi_rescue_records drop constraint dopmi_rescue_records_status_check;
alter table public.dopmi_rescue_records add constraint dopmi_rescue_records_status_check
  check(status in ('draft','pending_stripe','submitted','changes_requested','approved','rejected','closed'));
alter table public.dopmi_rescue_records add constraint dopmi_rescue_pending_stripe_case
  check(status<>'pending_stripe' or (kind='case' and submitted_at is null));

-- Keep human history attributable. A server promotion is explicitly a system event,
-- never a forged owner identity. The private table and all old ACLs remain private.
alter table private.dopmi_rescue_history alter column actor_id drop not null;
alter table private.dopmi_rescue_history add column actor_type text not null default 'user';
alter table private.dopmi_rescue_history add column source text not null default 'user';
alter table private.dopmi_rescue_history add column previous_status text;
alter table private.dopmi_rescue_history add constraint dopmi_rescue_history_actor_source check((
  (actor_type='user' and actor_id is not null and source='user' and previous_status is null)
  or (actor_type='system' and actor_id is null and source='stripe_connect_ready'
    and action='stripe_ready' and previous_status='pending_stripe'
    and snapshot->>'kind'='case' and snapshot->>'status'='submitted'
    and snapshot->>'id'=record_id::text and (snapshot->>'version')::integer=version)) is true);
revoke all on private.dopmi_rescue_history from public,anon,authenticated,service_role;


create or replace function public.dopmi_transition_rescue(record_id uuid, expected_version integer, action text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid; r public.dopmi_rescue_records;
begin
  actor:=private.dopmi_require_actor(); perform private.dopmi_rescue_lock(actor);
  select * into r from public.dopmi_rescue_records where id=record_id for update;
  if not found or r.owner_id<>actor then raise exception 'Solicitud no disponible' using errcode='42501'; end if;
  if r.version is distinct from expected_version then raise exception 'La solicitud cambió. Recarga antes de continuar' using errcode='40001'; end if;
  if action='submit' and r.status in ('draft','changes_requested','rejected') then
    if r.kind<>'verification' and not private.dopmi_rescuer_verified(actor) then
      raise exception 'Primero completa la verificación de rescatista' using errcode='22023'; end if;
    if r.kind='expense' and not exists(select 1 from public.dopmi_rescue_records where id=r.parent_id and status='approved') then
      raise exception 'El caso debe estar aprobado y abierto' using errcode='22023'; end if;
    perform private.dopmi_rescue_validate(r);
    update public.dopmi_rescue_records set status=case when r.kind='case' and not exists(
      select 1 from private.dopmi_connect_accounts a where a.owner_id=actor and a.account_id is not null
        and a.transfers_enabled and a.payouts_enabled) then 'pending_stripe' else 'submitted' end,
      submitted_at=case when r.kind='case' and not exists(
        select 1 from private.dopmi_connect_accounts a where a.owner_id=actor and a.account_id is not null
          and a.transfers_enabled and a.payouts_enabled) then null else now() end where id=r.id;
  elsif action='withdraw' and r.status in ('submitted','pending_stripe') then
    update public.dopmi_rescue_records set status='draft' where id=r.id;
  elsif action='close' and r.kind='case' and r.status='approved' then
    if exists(select 1 from public.dopmi_rescue_records where parent_id=r.id and status='submitted') then
      raise exception 'Resuelve o retira los gastos en revisión antes de cerrar el caso' using errcode='22023'; end if;
    update public.dopmi_rescue_records set status='closed' where id=r.id;
  else raise exception 'Acción no disponible para este estado' using errcode='22023'; end if;
  update public.dopmi_rescue_records set version=version+1,updated_at=now() where id=r.id returning * into r;
  perform private.dopmi_rescue_audit(r,action,'');
  return to_jsonb(r);
end;
$$;

create or replace function public.dopmi_rescue_detail(record_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r public.dopmi_rescue_records; a boolean:=public.dopmi_is_admin();
begin
  select * into r from public.dopmi_rescue_records where id=record_id;
  if not found or not ((public.dopmi_actor_active() and r.owner_id=auth.uid()) or (a and r.status not in ('draft','pending_stripe'))) then
    raise exception 'Solicitud no disponible' using errcode='42501'; end if;
  if a and r.owner_id<>auth.uid() then perform private.dopmi_rescue_audit(r,'read','Consulta de expediente'); end if;
  return jsonb_build_object('record',to_jsonb(r),
    'verified',private.dopmi_rescuer_verified(r.owner_id),
    'case_status',(select status from public.dopmi_rescue_records where id=r.parent_id),
    'history',coalesce((select jsonb_agg(x) from (select id,action,feedback,version,created_at,actor_type,source,
        snapshot->'reimbursable_cents' as reimbursable_cents,snapshot->'urgent' as urgent
      from private.dopmi_rescue_history h where h.record_id=r.id and action<>'read' order by created_at desc,id limit 100)x),'[]'));
end;
$$;

create or replace function public.dopmi_rescue_file_access(object_name text, writing boolean default false) returns boolean
language plpgsql security definer set search_path='' as $$
declare r public.dopmi_rescue_records; person uuid;
begin
  if object_name is null or object_name !~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|png|webp|pdf)$' then return false; end if;
  select owner_id into person from public.dopmi_rescue_records where id::text=split_part(object_name,'/',2);
  if writing then perform private.dopmi_rescue_lock(person); end if;
  select * into r from public.dopmi_rescue_records where id::text=split_part(object_name,'/',2);
  if not found or r.owner_id::text<>split_part(object_name,'/',1) then return false; end if;
  if writing then return public.dopmi_actor_active() and r.owner_id=auth.uid() and r.status in ('draft','changes_requested','rejected')
    and not exists(select 1 from public.dopmi_rescue_records where id=r.parent_id and status='closed'); end if;
  return (public.dopmi_actor_active() and r.owner_id=auth.uid()) or (public.dopmi_is_admin() and r.status not in ('draft','pending_stripe'))
    or (private.dopmi_rescue_public_visible(r) and coalesce(r.approved_snapshot->'photos','[]') ? object_name);
end;
$$;

create or replace function public.dopmi_video_action(data jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare a private.dopmi_video_assets; r public.dopmi_rescue_records; op text:=data->>'action'; actor uuid:=auth.uid(); staff boolean; active boolean:=coalesce(public.dopmi_actor_active(),false);
begin
 if not active and op not in ('public_list','playback') then raise exception 'Authentication required' using errcode='42501'; end if;
 staff:=case when active then public.dopmi_is_admin() else false end;
 if op='public_list' then
  return jsonb_build_object('items',coalesce((select jsonb_agg(to_jsonb(x)) from
   (select media_row.id,media_row.parent_id,media_row.purpose,media_row.duration,media_row.created_at from private.dopmi_video_assets media_row join public.dopmi_rescue_records parent_row on parent_row.id=media_row.parent_id
    where media_row.parent_id=(data->>'parent_id')::uuid and private.dopmi_video_public(media_row,parent_row) order by media_row.created_at,media_row.id limit 100) x),'[]'::jsonb));
 end if;
 if op='list' then
  if not staff then raise exception 'Reviewer required' using errcode='42501'; end if;
  return jsonb_build_object('items',coalesce((select jsonb_agg(to_jsonb(x)) from
   (select media_row.id,media_row.parent_id,media_row.parent_version,parent_row.version as current_parent_version,media_row.purpose,media_row.technical_state,media_row.moderation_state,media_row.duration,media_row.created_at from private.dopmi_video_assets media_row join public.dopmi_rescue_records parent_row on parent_row.id=media_row.parent_id where media_row.technical_state not in ('canceled','deleted') and parent_row.status not in ('draft','pending_stripe') order by media_row.created_at,media_row.id limit 100) x),'[]'::jsonb));
 end if;
 if op='begin' then
  if not (select enabled from private.dopmi_video_settings where singleton) then raise exception 'Video unavailable' using errcode='55000'; end if;
  select * into r from public.dopmi_rescue_records where id=(data->>'parent_id')::uuid for update;
  if not found or r.owner_id<>actor or r.kind not in ('case','expense') then raise exception 'Invalid owner or parent' using errcode='42501'; end if;
  if data->>'purpose'='urgency' and (not private.dopmi_video_urgency_allowed(r) or coalesce(r.public_data->>'urgency_photo_path','')<>'') then raise exception 'El complemento de urgencia requiere un caso urgente y admite una foto o un video' using errcode='22023';end if;
  select * into a from private.dopmi_video_assets where owner_id=actor and request_key=(data->>'request_key')::uuid for update;
  if found then
   if a.parent_id<>r.id or a.parent_version<>(data->>'parent_version')::integer or a.purpose<>data->>'purpose' or a.bytes<>(data->>'bytes')::bigint or a.content_snapshot<>private.dopmi_video_content(r) or a.file_fingerprint is distinct from (data->>'file_fingerprint') or a.technical_state in ('canceled','deleted') then raise exception 'Idempotency conflict' using errcode='40001';end if;
   return jsonb_build_object('id',a.id,'parent_id',a.parent_id,'parent_version',a.parent_version,'purpose',a.purpose,'technical_state',a.technical_state,'moderation_state',a.moderation_state,'duration',a.duration,'upload_url',case when a.technical_state='uploading' then a.upload_url else null end);
  end if;
  if r.version is distinct from (data->>'parent_version')::integer then raise exception 'Stale parent' using errcode='40001'; end if;
  if data->>'purpose' not in ('thanks','urgency','expense_evidence','public_update','farewell')
   or (data->>'purpose'='expense_evidence' and r.kind<>'expense')
   or (data->>'purpose' in ('thanks','public_update','farewell') and r.kind<>'case')
   or (r.status='closed' and data->>'purpose'<>'farewell') then raise exception 'Invalid purpose' using errcode='22023'; end if;
  if r.status not in ('draft','changes_requested','rejected','approved','closed') then raise exception 'Parent not editable' using errcode='55000'; end if;
  insert into private.dopmi_video_assets(owner_id,parent_id,parent_version,purpose,request_key,bytes,content_snapshot,file_fingerprint)
   values(actor,r.id,r.version,data->>'purpose',(data->>'request_key')::uuid,(data->>'bytes')::bigint,private.dopmi_video_content(r),data->>'file_fingerprint')
   on conflict(owner_id,request_key) do nothing;
  select * into a from private.dopmi_video_assets where owner_id=actor and request_key=(data->>'request_key')::uuid for update;
  if a.parent_id<>r.id or a.parent_version<>r.version or a.purpose<>data->>'purpose' or a.bytes<>(data->>'bytes')::bigint
   or a.content_snapshot<>private.dopmi_video_content(r) or a.file_fingerprint is distinct from (data->>'file_fingerprint') or a.technical_state in ('canceled','deleted') then raise exception 'Idempotency conflict' using errcode='40001'; end if;
 else
  select * into a from private.dopmi_video_assets where id=(data->>'id')::uuid for update;
  if not found then raise exception 'Unavailable' using errcode='42501'; end if;
  select * into r from public.dopmi_rescue_records where id=a.parent_id;
  if op='playback' then
   if not ((active and a.owner_id=actor) or (staff and r.status not in ('draft','pending_stripe')) or private.dopmi_video_public(a,r)) then raise exception 'Unavailable' using errcode='42501'; end if;
  elsif op='review' then
   if not staff or r.status in ('draft','pending_stripe') then raise exception 'Reviewer required' using errcode='42501'; end if;
   if r.version is distinct from (data->>'parent_version')::integer or a.content_snapshot<>private.dopmi_video_content(r) then raise exception 'Stale parent' using errcode='40001'; end if;
   if data->>'decision' not in ('approved','rejected') or a.technical_state<>'ready' then raise exception 'Invalid review' using errcode='22023'; end if;
   insert into private.dopmi_video_reviews(asset_id,reviewer_id,parent_version,decision,note,snapshot) values(a.id,actor,r.version,data->>'decision',left(coalesce(data->>'note',''),1000),jsonb_build_object('content',a.content_snapshot,'purpose',a.purpose,'duration',a.duration));
   update private.dopmi_video_assets set moderation_state=data->>'decision',reviewer_id=actor,review_note=left(coalesce(data->>'note',''),1000),
    approved_parent_snapshot=case when data->>'decision'='approved' and private.dopmi_rescue_public_visible(r) then r.approved_snapshot else null end,updated_at=now() where id=a.id returning * into a;
  elsif op in ('status','cancel') then
   if a.owner_id<>actor and not (staff and op='status' and r.status not in ('draft','pending_stripe')) then raise exception 'Owner required' using errcode='42501'; end if;
   if op='cancel' and a.purpose='expense_evidence' and (exists(select 1 from public.dopmi_donations d where d.expense_id=a.parent_id) or exists(select 1 from private.dopmi_case_allocations c where c.expense_id=a.parent_id) or exists(select 1 from private.dopmi_guardian_allocations g where g.expense_id=a.parent_id)) then raise exception 'Financial evidence retained' using errcode='42501';end if;
   if op='cancel' and a.provider_id is not null then insert into private.dopmi_video_deletion_queue(provider_id) values(a.provider_id) on conflict do nothing;end if;
   if op='cancel' then update private.dopmi_video_assets set technical_state='canceled',upload_url=null,approved_parent_snapshot=null,updated_at=now() where id=a.id returning * into a; end if;
  else raise exception 'Invalid operation' using errcode='22023'; end if;
 end if;
 return jsonb_build_object('id',a.id,'parent_id',a.parent_id,'parent_version',a.parent_version,'purpose',a.purpose,'technical_state',a.technical_state,'moderation_state',a.moderation_state,'duration',a.duration,
  'provider_id',case when op in ('status','playback','cancel') then a.provider_id else null end,
  'upload_url',case when a.owner_id=actor and op in ('begin','status') and a.technical_state='uploading' then a.upload_url else null end);
end;
$$;

create or replace function private.dopmi_video_submission_guard() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if not (select enabled from private.dopmi_video_settings where singleton) and new.kind='case' and new.status in ('pending_stripe','submitted','approved') then new.video_thanks_required:=false;end if;
 if (select enabled from private.dopmi_video_settings where singleton) and new.kind='case' and new.video_thanks_required and new.status in ('pending_stripe','submitted','approved') and old.status is distinct from new.status then
  if not exists(select 1 from private.dopmi_video_assets a where a.parent_id=new.id and a.purpose='thanks' and a.technical_state='ready'
   and a.content_snapshot=private.dopmi_video_content(new) and a.moderation_state in ('pending','approved')
   and (new.status<>'approved' or a.moderation_state='approved')) then
   raise exception 'Agradecimiento requerido: carga un video listo y aprobado antes de publicar'
     using errcode='23514',constraint='dopmi_video_submission_ready';
  end if;
 end if;
 return new;
end;
$$;

-- Acquire the rescuer lock BEFORE the delegated Connect UPDATE, matching submit,
-- withdraw and identity review. An AFTER Connect trigger would invert these locks.
-- Preserve the complete historical payment-method and expense wrapper chain.
alter function public.dopmi_payment_server(text,jsonb) rename to dopmi_payment_server_before_pending_stripe;
revoke all on function public.dopmi_payment_server_before_pending_stripe(text,jsonb) from public,anon,authenticated,service_role;
create function public.dopmi_payment_server(operation text,data jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb; person uuid; waiting public.dopmi_rescue_records; promoted public.dopmi_rescue_records;
  promoted_count integer:=0; deferred_count integer:=0; deferred jsonb:='[]'; phase text; failure_state text; failure_constraint text;
begin
  if operation='connect_save' then
    person:=(data->>'actor')::uuid;
    perform private.dopmi_rescue_lock(person);
  end if;
  result:=public.dopmi_payment_server_before_pending_stripe(operation,data);
  if operation='connect_save' and private.dopmi_rescuer_verified(person) and exists(
    select 1 from private.dopmi_connect_accounts a where a.owner_id=person and a.account_id is not null
      and a.transfers_enabled and a.payouts_enabled) then
    for waiting in select * from public.dopmi_rescue_records where owner_id=person
      and kind='case' and status='pending_stripe' order by id for update loop
      -- The entry point is service-only by ACL; require the service request role
      -- again for nullable-actor system promotions. Never set JWT claims.
      if current_setting('role',true)<>'service_role' and coalesce(
        nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'role',
        current_setting('request.jwt.claim.role',true),'')<>'service_role' then
        raise exception 'Service required' using errcode='42501';
      end if;
      -- Each case has its own subtransaction. A stale/canceled file or a video
      -- guard failure at UPDATE must not roll back Stripe readiness or another
      -- valid case. The actual video trigger, rather than a racy precheck,
      -- remains the final gate for the current flag/content/readiness.
      begin
        phase:='validation';
        perform private.dopmi_rescue_validate(waiting);
        phase:='transition';
        update public.dopmi_rescue_records set status='submitted',submitted_at=now(),updated_at=now(),version=version+1
          where id=waiting.id and status='pending_stripe' and version=waiting.version returning * into promoted;
        if found then
          phase:='audit';
          insert into private.dopmi_rescue_history(record_id,actor_id,actor_type,source,previous_status,action,feedback,version,snapshot)
            values(promoted.id,null,'system','stripe_connect_ready','pending_stripe','stripe_ready','',promoted.version,to_jsonb(promoted));
          promoted_count:=promoted_count+1;
        end if;
      exception when invalid_parameter_value or check_violation then
        get stacked diagnostics failure_state=returned_sqlstate,failure_constraint=constraint_name;
        -- Catch only the established rescue validation error or the identified
        -- submission video guard. Unexpected constraints/audit failures abort
        -- normally and are never reported as a successful synchronization.
        if not ((failure_state='22023' and phase='validation') or
          (failure_state='23514' and phase='transition' and failure_constraint='dopmi_video_submission_ready')) then raise; end if;
        deferred_count:=deferred_count+1;
        if jsonb_array_length(deferred)<20 then
          deferred:=deferred||jsonb_build_array(jsonb_build_object('record_id',waiting.id,'phase',phase,'sqlstate',failure_state,
            'reason',case when phase='validation' then 'case_validation_failed' else 'thanks_not_ready' end));
        end if;
        raise log 'dopmi_pending_stripe_deferred source=stripe_connect_ready record_id=% phase=% sqlstate=%',waiting.id,phase,failure_state;
      end;
    end loop;
  end if;
  if operation='connect_save' then
    -- Service-only, bounded identifiers/codes; no provider payload, private
    -- content or raw error message. Owners may withdraw a deferred case to fix
    -- it; a later readiness refresh retries only records still pending.
    result:=result||jsonb_build_object('pending_stripe_sync',jsonb_build_object(
      'source','stripe_connect_ready','promoted_count',promoted_count,'deferred_count',deferred_count,'deferred',deferred));
  end if;
  return result;
end; $$;
revoke all on function public.dopmi_payment_server(text,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.dopmi_payment_server(text,jsonb) to service_role;


create or replace function public.dopmi_owned_cases(program text default 'adoption',statuses text[] default '{}',
  archived boolean default false,page_number integer default 1,page_size integer default 20) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); result jsonb;
begin
  if program is null or program not in('adoption','support') or statuses is null or
    not statuses<@array['active','review','draft','corrections','pending_stripe']::text[] or archived is null
    or page_number is null or page_number<1 or page_size is null or page_size not between 1 and 50 then
    raise exception 'Filtros inválidos' using errcode='22023'; end if;
  with owned as(select *,case when status in('published','approved')then 'active' when status='submitted'then 'review'
    when status='draft'then 'draft' when status='pending_stripe'then 'pending_stripe' else 'corrections' end category from private.dopmi_owned_case_rows(actor)),
  filtered as(select * from owned o where o.program=$1 and o.archived=$3 and
    ($3 or cardinality($2)=0 or category=any($2))),
  page as(select * from filtered order by case category when 'draft'then 0 when 'pending_stripe'then 1 when 'review'then 2 when 'corrections'then 3 else 4 end,lower(pet_name),id
    limit page_size offset(page_number::bigint-1)*page_size)
  select jsonb_build_object('total',(select count(*)from filtered),'total_owned',(select count(*)from owned),
    'items',coalesce((select jsonb_agg(item||jsonb_build_object('phase',category) order by case category when 'draft'then 0 when 'pending_stripe'then 1 when 'review'then 2 when 'corrections'then 3 else 4 end,lower(pet_name),id)from page),'[]'::jsonb))into result;
  return result;
end; $$;

create or replace function public.dopmi_rescuer_dashboard() returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor();
  guardian_assigned bigint;
  guardian_transferred bigint;
begin
  -- Count settled net once per owned expense, including recorded reversals.
  -- Reservation amounts never enter dopmi_guardian_funded.
  select coalesce(sum(private.dopmi_guardian_funded(e.id)),0),
    coalesce(sum(private.dopmi_guardian_funded(e.id,true)),0)
  into guardian_assigned,guardian_transferred
  from public.dopmi_rescue_records e
  where e.owner_id=actor and e.kind='expense';
  return jsonb_build_object(
    'verification_status',coalesce((select status from public.dopmi_rescue_records
      where owner_id=actor and kind='verification'),'not_started'),
    'case_counts',jsonb_build_object(
      'active',(select count(*) from public.dopmi_rescue_records where owner_id=actor and kind='case' and status='approved'),
      'pendingStripe',(select count(*) from public.dopmi_rescue_records where owner_id=actor and kind='case' and status='pending_stripe'),
      'draft',(select count(*) from public.dopmi_rescue_records where owner_id=actor and kind='case' and status='draft'),
      'review',(select count(*) from public.dopmi_rescue_records where owner_id=actor and kind='case' and status='submitted'),
      'corrections',(select count(*) from public.dopmi_rescue_records where owner_id=actor and kind='case' and status in ('changes_requested','rejected'))
    ),
    'unread_messages',(select count(*) from public.dopmi_notifications where user_id=actor and kind='message' and read_at is null),
    'financial',jsonb_build_object(
      'assigned_cents',(select coalesce(sum(allocated_cents),0) from public.dopmi_donations where rescuer_id=actor and payment_status='confirmed')+guardian_assigned,
      'transferred_cents',(select coalesce(sum(allocated_cents),0) from public.dopmi_donations where rescuer_id=actor and transfer_status='transferred' and stripe_transfer_id is not null)+guardian_transferred,
      'in_review_cents',(select coalesce(sum(allocated_cents),0) from public.dopmi_donations where rescuer_id=actor and payment_status='confirmed' and transfer_status in ('not_started','pending','attention'))+greatest(0,guardian_assigned-guardian_transferred)
    ),
    'pending',coalesce((select jsonb_agg(to_jsonb(x)) from (
      select r.id,r.kind,r.parent_id,r.status,r.feedback,
        coalesce(r.public_data->>'pet_name',r.public_data->>'title',r.public_data->>'public_name','Borrador') as title,
        r.updated_at
      from public.dopmi_rescue_records r
      where r.owner_id=actor and r.status in ('draft','changes_requested','rejected')
      order by r.updated_at desc,r.id limit 6
    ) x),'[]'::jsonb),
    'recent_activity',coalesce((select jsonb_agg(to_jsonb(x)) from (
      select q.expense_id,q.expense_title,q.allocated_cents,q.transfer_status,q.created_at,q.source
      from (
        select d.expense_id,d.expense_title,d.allocated_cents,d.transfer_status,d.created_at,
          'individual'::text as source,d.id::text as sort_key
        from public.dopmi_donations d
        where d.rescuer_id=actor and d.payment_status='confirmed' and d.allocated_cents>0
        union all
        select a.expense_id,coalesce(e.approved_snapshot->>'title','Gasto'),
          a.allocated_cents-a.reversed_cents,
          case when a.stripe_transfer_id is not null then 'transferred'
            when exists(select 1 from private.dopmi_guardian_jobs j where j.cycle_id=a.cycle_id
              and j.expense_id=a.expense_id and j.kind='transfer' and j.status='attention') then 'attention'
            else 'pending' end,
          settlement.created_at,'guardian'::text,a.cycle_id::text||':'||a.expense_id::text
        from private.dopmi_guardian_allocations a
        join private.dopmi_guardian_settlements settlement on settlement.cycle_id=a.cycle_id
        join public.dopmi_rescue_records e on e.id=a.expense_id
        where e.owner_id=actor and e.kind='expense' and a.allocated_cents>a.reversed_cents
      ) q order by q.created_at desc,q.source,q.sort_key limit 6
    ) x),'[]'::jsonb)
  );
end;
$$;

create or replace function public.dopmi_rescuer_dashboard_v2()returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); old jsonb; activity jsonb; counts jsonb; metrics jsonb; evidence jsonb; unanswered bigint;
begin
  old:=public.dopmi_rescuer_dashboard(); activity:=public.dopmi_rescuer_activity(1,6);
  select jsonb_object_agg(program,summary)into counts from(
    select program,jsonb_build_object('active',count(*)filter(where status in('published','approved')),
      'review',count(*)filter(where status='submitted'),'draft',count(*)filter(where status='draft'),
      'corrections',count(*)filter(where status in('changes_requested','rejected')))summary
    from private.dopmi_owned_case_rows(actor)where not archived group by program
  )x;
  select jsonb_build_object('unique_viewers',(select count(distinct v.actor_id)from private.dopmi_adoption_views v join public.dopmi_adoptions a on a.id=v.post_id where a.owner_id=actor),
    'pets_saved',(select count(*)from public.dopmi_adoptions a where a.owner_id=actor and a.status='published'and exists(select 1 from public.dopmi_favorites f where f.post_id=a.id and f.user_id<>actor)),
    'tracking_started_at',(select started_at from private.dopmi_adoption_measurement_start))into metrics;
  select count(*)into unanswered from public.dopmi_threads t
    join public.dopmi_adoptions a on a.id=t.post_id left join public.dopmi_rescue_records c on c.id=a.rescue_case_id
    join lateral(select m.sender_id from public.dopmi_messages m where m.thread_id=t.id order by m.created_at desc,m.id desc limit 1)last_msg on true
    where t.owner_id=actor and t.status='active' and a.status not in('archived','adopted','rejected')and coalesce(c.status<>'closed',true)and last_msg.sender_id=t.adopter_id;
  select coalesce(jsonb_agg(item order by changed desc,id),'[]'::jsonb)into evidence from(
    select e.id,e.updated_at changed,jsonb_build_object('expense_id',e.id,'case_id',c.id,
      'pet_name',coalesce(c.public_data->>'pet_name','Mascota'),'expense_title',coalesce(e.public_data->>'title','Gasto'),
      'status',e.status,'urgent',e.urgent,'editable',true,'progress_percent',
      private.dopmi_expense_completion(e))item
    from public.dopmi_rescue_records e join public.dopmi_rescue_records c on c.id=e.parent_id
    where e.owner_id=actor and c.owner_id=actor and e.kind='expense'and e.status in('draft','changes_requested','rejected')
      and c.status<>'closed'and not exists(select 1 from private.dopmi_support_archives ar where ar.record_id=c.id)
  )x;
  return old||jsonb_build_object('adoption_counts',coalesce(counts->'adoption','{"active":0,"review":0,"draft":0,"corrections":0}'::jsonb),
    'support_counts',coalesce(counts->'support','{"active":0,"review":0,"draft":0,"corrections":0}'::jsonb)||
      jsonb_build_object('pendingStripe',(select count(*) from private.dopmi_owned_case_rows(actor)
        where program='support' and not archived and status='pending_stripe')),
    'adoption_metrics',metrics,'unanswered_conversations',unanswered,'pending_evidence',evidence,
    'recent_activity',activity->'items','payments_cursor',activity->'presented_cursor',
    'payments_unseen_count',(select count(*)from private.dopmi_rescuer_activity_rows(actor)a where not exists(
      select 1 from private.dopmi_rescuer_activity_seen seen where seen.owner_id=actor and seen.event_id=a.id)));
end; $$;

-- Existing RPC privileges survive CREATE OR REPLACE; explicitly retain the
-- private guard closure and do not expose either internal payment wrapper.
revoke all on function private.dopmi_video_submission_guard() from public,anon,authenticated,service_role;
commit;
