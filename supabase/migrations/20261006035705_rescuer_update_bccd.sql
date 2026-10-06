begin;

-- Additive owner-facing read models. Existing mobile/financial APIs stay intact.
create table private.dopmi_adoption_measurement (
  actor_id uuid primary key references auth.users(id) on delete cascade,
  consent boolean not null default false, updated_at timestamptz not null default now()
);
create table private.dopmi_adoption_views (
  post_id uuid references public.dopmi_adoptions(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete cascade,
  first_seen_at timestamptz not null default now(), primary key(post_id,actor_id)
);
create index dopmi_adoption_views_actor on private.dopmi_adoption_views(actor_id,post_id);
create table private.dopmi_adoption_measurement_start (
  singleton boolean primary key default true check(singleton), started_at timestamptz not null default now()
);
insert into private.dopmi_adoption_measurement_start(singleton) values(true);
create table private.dopmi_adoption_closures (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.dopmi_adoptions(id) on delete cascade,
  reason text not null check(reason in('adopted','other')),
  dopmi_support boolean, description text not null default '' check(char_length(description)<=1000),
  version integer not null, created_at timestamptz not null default now(),
  check((reason='adopted')=(dopmi_support is not null))
);
create index dopmi_adoption_closures_post on private.dopmi_adoption_closures(post_id,version desc);
create table private.dopmi_support_archives (
  record_id uuid primary key references public.dopmi_rescue_records(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade, created_at timestamptz not null default now()
);
create table private.dopmi_rescuer_activity_seen (
  owner_id uuid references auth.users(id) on delete cascade,
  event_id text not null, seen_at timestamptz not null default now(), primary key(owner_id,event_id)
);
create table private.dopmi_rescuer_activity_receipts (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade,
  event_ids text[] not null, created_at timestamptz not null default now()
);
create index dopmi_activity_receipts_owner on private.dopmi_rescuer_activity_receipts(owner_id,created_at);
alter table private.dopmi_adoption_measurement enable row level security;
alter table private.dopmi_adoption_views enable row level security;
alter table private.dopmi_adoption_measurement_start enable row level security;
alter table private.dopmi_adoption_closures enable row level security;
alter table private.dopmi_support_archives enable row level security;
alter table private.dopmi_rescuer_activity_seen enable row level security;
alter table private.dopmi_rescuer_activity_receipts enable row level security;
revoke all on private.dopmi_adoption_measurement,private.dopmi_adoption_views,
  private.dopmi_adoption_measurement_start,private.dopmi_adoption_closures,
  private.dopmi_support_archives,private.dopmi_rescuer_activity_seen,
  private.dopmi_rescuer_activity_receipts from public,anon,authenticated;

create function public.dopmi_set_adoption_measurement(consent boolean) returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor();
begin
  if consent is null then raise exception 'Consentimiento requerido' using errcode='22023'; end if;
  insert into private.dopmi_adoption_measurement(actor_id,consent) values(actor,consent)
    on conflict(actor_id) do update set consent=excluded.consent,updated_at=now();
end; $$;
create function public.dopmi_record_adoption_view(post_id uuid,consent boolean) returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor();
begin
  if consent is distinct from true or not exists(select 1 from private.dopmi_adoption_measurement m where m.actor_id=actor and m.consent) then return; end if;
  if not exists(select 1 from public.dopmi_adoptions a join public.profiles p on p.id=a.owner_id
    where a.id=post_id and a.status='published' and p.account_status='active' and a.owner_id<>actor) then return; end if;
  insert into private.dopmi_adoption_views(post_id,actor_id) values(post_id,actor) on conflict do nothing;
end; $$;

create function public.dopmi_rescuer_threads_page(page_number integer default 1,group_id uuid default null,
  unread_only boolean default false,history boolean default false,page_size integer default 20) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); result jsonb;
begin
  if page_number is null or page_number<1 or page_size is null or page_size not between 1 and 50
    or unread_only is null or history is null then raise exception 'Paginación inválida' using errcode='22023'; end if;
  if group_id is not null and not exists(select 1 from public.dopmi_adoptions a where a.owner_id=actor and coalesce(a.rescue_case_id,a.id)=group_id) then
    raise exception 'Caso no disponible' using errcode='42501'; end if;
  with entries as (
    select t.*,a.pet_name from private.dopmi_rescuer_threads(actor,history) t
    join public.dopmi_threads real_thread on real_thread.id=t.thread_id
    join public.dopmi_adoptions a on a.id=real_thread.post_id
    where ($2 is null or t.group_id=$2) and (not $3 or t.unread>0)
  ), page as (select * from entries order by unread desc,lower(participant_name),thread_id limit page_size offset (page_number::bigint-1)*page_size)
  select jsonb_build_object('total',(select count(*) from entries),'items',coalesce((select jsonb_agg(
    item||jsonb_build_object('group_id',p.group_id,'pet_name',p.pet_name)
    order by unread desc,lower(participant_name),thread_id) from page p),'[]'::jsonb)) into result;
  return result;
end; $$;

create function public.dopmi_close_adoption(post_id uuid,expected_version integer,reason text,
  dopmi_support boolean default null,description text default '') returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); a public.dopmi_adoptions; result jsonb;
begin
  select * into a from public.dopmi_adoptions where id=post_id for update;
  if not found or a.owner_id<>actor then raise exception 'Publicación no disponible' using errcode='42501'; end if;
  if a.version is distinct from expected_version then raise exception 'La publicación cambió. Vuelve a cargarla.' using errcode='40001'; end if;
  if a.status<>'published' or reason is null or reason not in('adopted','other')
    or (reason='adopted') is distinct from (dopmi_support is not null)
    or description is null or char_length(description)>1000 then raise exception 'Cierre inválido' using errcode='22023'; end if;
  result:=public.dopmi_transition_adoption(post_id,expected_version,case when reason='adopted' then 'adopted' else 'archive' end);
  insert into private.dopmi_adoption_closures(post_id,reason,dopmi_support,description,version)
    values(post_id,reason,dopmi_support,btrim(description),(result->>'version')::integer);
  return result;
end; $$;

create function public.dopmi_archive_support_case(record_id uuid,expected_version integer) returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); r public.dopmi_rescue_records;
begin
  perform private.dopmi_rescue_lock(actor);
  select * into r from public.dopmi_rescue_records where id=record_id for update;
  if not found or r.owner_id<>actor or r.kind<>'case' then raise exception 'Caso no disponible' using errcode='42501'; end if;
  if r.version is distinct from expected_version then raise exception 'La solicitud cambió. Recarga antes de continuar' using errcode='40001'; end if;
  if r.status<>'closed' then
    if r.status not in('draft','changes_requested','rejected') or r.approved_snapshot is not null
      or exists(select 1 from public.dopmi_rescue_records e where e.parent_id=r.id and
        (e.status not in('draft','changes_requested','rejected') or e.approved_snapshot is not null or e.reimbursable_cents<>0)) then
      raise exception 'Resuelve las revisiones y dependencias antes de archivar' using errcode='22023'; end if;
  end if;
  insert into private.dopmi_support_archives(record_id,owner_id) values(record_id,actor) on conflict do nothing;
  update public.dopmi_rescue_records set version=version+1,updated_at=now() where id=record_id returning * into r;
  perform private.dopmi_rescue_audit(r,'archive','');
end; $$;

create function private.dopmi_owned_case_rows(actor uuid) returns table(id uuid,program text,status text,
  archived boolean,pet_name text,updated_at timestamptz,item jsonb)
language sql stable set search_path='' as $$
  select a.id,'adoption',a.status,a.status in('adopted','archived'),a.pet_name,a.updated_at,
    to_jsonb(a)||jsonb_build_object('program','adoption','record',to_jsonb(a),'cover_path',a.photos[1],
      'archived',a.status in('adopted','archived'),'unique_view_count',(select count(*) from private.dopmi_adoption_views v where v.post_id=a.id),
      'tracking_started_at',(select started_at from private.dopmi_adoption_measurement_start),
      'thread_count',(select count(*) from public.dopmi_threads t where t.post_id=a.id),
      'close_reason',c.reason,'adopted_with_dopmi_support',c.dopmi_support,'close_reason_description',c.description)
    from public.dopmi_adoptions a left join lateral(select * from private.dopmi_adoption_closures x where x.post_id=a.id order by x.version desc limit 1)c on true
    where a.owner_id=actor and actor=auth.uid()
  union all
  select r.id,'support',r.status,r.status='closed' or exists(select 1 from private.dopmi_support_archives ar where ar.record_id=r.id),
    coalesce(r.public_data->>'pet_name',r.public_data->>'title','Sin nombre'),r.updated_at,
    to_jsonb(r)||jsonb_build_object('program','support','record',to_jsonb(r),'pet_name',coalesce(r.public_data->>'pet_name',r.public_data->>'title','Sin nombre'),
      'cover_path',(select f->>'path' from jsonb_array_elements(r.files)f where f->>'role'='public' limit 1),
      'archived',r.status='closed' or exists(select 1 from private.dopmi_support_archives ar where ar.record_id=r.id),
      'target_cents',coalesce(f.target_cents,0),'funded_cents',coalesce(f.funded_cents,0),'transferred_cents',coalesce(f.transferred_cents,0),
      'need_types',coalesce(f.need_types,'[]'::jsonb))
    from public.dopmi_rescue_records r left join lateral(
      select sum(e.reimbursable_cents)filter(where e.status in('approved','closed') and e.approved_snapshot is not null)target_cents,
        sum((funding.value->>'funded_cents')::bigint)funded_cents,sum((funding.value->>'transferred_cents')::bigint)transferred_cents,
        jsonb_agg(distinct coalesce(e.public_data->>'category','other'))filter(where e.status in('approved','closed') and e.approved_snapshot is not null)need_types
      from public.dopmi_rescue_records e cross join lateral public.dopmi_expense_funding(e.id)funding(value)
      where e.owner_id=actor and e.parent_id=r.id and e.kind='expense'
    )f on true where r.owner_id=actor and r.kind='case' and actor=auth.uid();
$$;
revoke all on function private.dopmi_owned_case_rows(uuid) from public,anon,authenticated;
create function public.dopmi_owned_cases(program text default 'adoption',statuses text[] default '{}',
  archived boolean default false,page_number integer default 1,page_size integer default 20) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); result jsonb;
begin
  if program is null or program not in('adoption','support') or statuses is null or
    not statuses<@array['active','review','draft','corrections']::text[] or archived is null
    or page_number is null or page_number<1 or page_size is null or page_size not between 1 and 50 then
    raise exception 'Filtros inválidos' using errcode='22023'; end if;
  with owned as(select *,case when status in('published','approved')then 'active' when status='submitted'then 'review'
    when status='draft'then 'draft' else 'corrections' end category from private.dopmi_owned_case_rows(actor)),
  filtered as(select * from owned o where o.program=$1 and o.archived=$3 and
    ($3 or cardinality($2)=0 or category=any($2))),
  page as(select * from filtered order by case category when 'draft'then 0 when 'review'then 1 when 'corrections'then 2 else 3 end,lower(pet_name),id
    limit page_size offset(page_number::bigint-1)*page_size)
  select jsonb_build_object('total',(select count(*)from filtered),'total_owned',(select count(*)from owned),
    'items',coalesce((select jsonb_agg(item order by case category when 'draft'then 0 when 'review'then 1 when 'corrections'then 2 else 3 end,lower(pet_name),id)from page),'[]'::jsonb))into result;
  return result;
end; $$;

create function private.dopmi_rescuer_activity_rows(actor uuid) returns table(id text,case_id uuid,
  expense_id uuid,pet_name text,photo text,net_cents bigint,occurred_at timestamptz,source text,transfer_status text,expense_title text)
language sql stable set search_path='' as $$
  select 'individual:'||d.id,c.id,e.id,coalesce(c.public_data->>'pet_name','Mascota'),
    (select f->>'path' from jsonb_array_elements(c.files)f where f->>'role'='public' limit 1),
    d.allocated_cents,d.created_at,'individual',d.transfer_status,coalesce(e.public_data->>'title','Apoyo recibido')
  from public.dopmi_donations d join public.dopmi_rescue_records e on e.id=d.expense_id
    join public.dopmi_rescue_records c on c.id=e.parent_id
  where d.rescuer_id=actor and actor=auth.uid() and d.payment_status='confirmed' and d.allocated_cents>0
  union all
  select 'guardian:'||a.cycle_id||':'||a.expense_id,c.id,e.id,coalesce(c.public_data->>'pet_name','Mascota'),
    (select f->>'path'from jsonb_array_elements(c.files)f where f->>'role'='public'limit 1),
    a.allocated_cents-a.reversed_cents,s.created_at,'guardian',case when a.stripe_transfer_id is not null then 'transferred'
      when exists(select 1 from private.dopmi_guardian_jobs j where j.cycle_id=a.cycle_id and j.expense_id=a.expense_id and j.kind='transfer' and j.status='attention')then 'attention'
      else 'pending'end,coalesce(e.approved_snapshot->>'title',e.public_data->>'title','Apoyo recibido')
  from private.dopmi_guardian_allocations a join private.dopmi_guardian_settlements s on s.cycle_id=a.cycle_id
    join public.dopmi_rescue_records e on e.id=a.expense_id join public.dopmi_rescue_records c on c.id=e.parent_id
  where e.owner_id=actor and actor=auth.uid() and a.allocated_cents>a.reversed_cents;
$$;
revoke all on function private.dopmi_rescuer_activity_rows(uuid) from public,anon,authenticated;
create function public.dopmi_rescuer_activity(page_number integer default 1,page_size integer default 20) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); result jsonb; ids text[]; cursor_id uuid;
begin
  if page_number is null or page_number<1 or page_size is null or page_size not between 1 and 50 then raise exception 'Paginación inválida' using errcode='22023';end if;
  with entries as(select *from private.dopmi_rescuer_activity_rows(actor)),page as(select *from entries order by occurred_at desc,id limit page_size offset(page_number::bigint-1)*page_size)
  select jsonb_build_object('total',(select count(*)from entries),'items',coalesce((select jsonb_agg(to_jsonb(p)order by occurred_at desc,id)from page p),'[]'::jsonb)),
    coalesce((select array_agg(id)from page),'{}'::text[])into result,ids;
  -- Repeated refreshes reuse the same exact snapshot; no growing receipt per read.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('activity:'||actor::text,0));
  select id into cursor_id from private.dopmi_rescuer_activity_receipts where owner_id=actor and event_ids=ids limit 1;
  if cursor_id is null then
    insert into private.dopmi_rescuer_activity_receipts(owner_id,event_ids)values(actor,ids)returning id into cursor_id;
  end if;
  return result||jsonb_build_object('presented_cursor',cursor_id);
end; $$;
create function public.dopmi_acknowledge_rescuer_payments(presented_cursor uuid)returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); ids text[];
begin
  select event_ids into ids from private.dopmi_rescuer_activity_receipts where id=presented_cursor and owner_id=actor;
  if not found then raise exception 'Actividad no disponible' using errcode='42501';end if;
  insert into private.dopmi_rescuer_activity_seen(owner_id,event_id)select actor,unnest(ids)on conflict do nothing;
end; $$;

-- Same mandatory fields and uploaded-file requirements as submission validation.
create function private.dopmi_expense_completion(e public.dopmi_rescue_records)returns integer
language plpgsql stable set search_path='' as $$
declare completed integer:=0; required integer:=9; field text; date_ok boolean:=false;
begin
  foreach field in array array['title','description']loop
    if coalesce(char_length(btrim(e.public_data->>field)),0)>=2 then completed:=completed+1;end if;
  end loop;
  if e.public_data->>'category' in('food','veterinary','medicine','other')then completed:=completed+1;end if;
  if e.public_data->>'category'='food'then
    required:=required+1;
    if coalesce(char_length(btrim(e.public_data->>'round_label')),0)>=2 then completed:=completed+1;end if;
  end if;
  foreach field in array array['vendor','receipt_reference']loop
    if coalesce(char_length(btrim(e.private_data->>field)),0)>=1 then completed:=completed+1;end if;
  end loop;
  if coalesce(e.private_data->>'amount_cents','')~'^[0-9]{1,9}$'then
    if (e.private_data->>'amount_cents')::bigint between 1 and 100000000 then completed:=completed+1;end if;
  end if;
  begin
    date_ok:=coalesce(e.private_data->>'paid_on','')~'^\d{4}-\d{2}-\d{2}$'and
      (e.private_data->>'paid_on')::date<=(now()at time zone 'America/Mexico_City')::date;
  exception when others then date_ok:=false;end;
  if date_ok then completed:=completed+1;end if;
  foreach field in array array['receipt','proof']loop
    if exists(select 1 from jsonb_array_elements(e.files)f join storage.objects o
      on o.bucket_id='dopmi-rescue-evidence'and o.name=f->>'path'where f->>'role'=field)then completed:=completed+1;end if;
  end loop;
  return completed*100/required;
end; $$;
revoke all on function private.dopmi_expense_completion(public.dopmi_rescue_records)from public,anon,authenticated;

create function public.dopmi_rescuer_dashboard_v2()returns jsonb
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
    'support_counts',coalesce(counts->'support','{"active":0,"review":0,"draft":0,"corrections":0}'::jsonb),
    'adoption_metrics',metrics,'unanswered_conversations',unanswered,'pending_evidence',evidence,
    'recent_activity',activity->'items','payments_cursor',activity->'presented_cursor',
    'payments_unseen_count',(select count(*)from private.dopmi_rescuer_activity_rows(actor)a where not exists(
      select 1 from private.dopmi_rescuer_activity_seen seen where seen.owner_id=actor and seen.event_id=a.id)));
end; $$;

revoke all on function public.dopmi_set_adoption_measurement(boolean),public.dopmi_record_adoption_view(uuid,boolean),
  public.dopmi_rescuer_threads_page(integer,uuid,boolean,boolean,integer),public.dopmi_close_adoption(uuid,integer,text,boolean,text),
  public.dopmi_archive_support_case(uuid,integer),public.dopmi_owned_cases(text,text[],boolean,integer,integer),
  public.dopmi_rescuer_activity(integer,integer),public.dopmi_acknowledge_rescuer_payments(uuid),
  public.dopmi_rescuer_dashboard_v2() from public,anon,authenticated;
grant execute on function public.dopmi_set_adoption_measurement(boolean),public.dopmi_record_adoption_view(uuid,boolean),
  public.dopmi_rescuer_threads_page(integer,uuid,boolean,boolean,integer),public.dopmi_close_adoption(uuid,integer,text,boolean,text),
  public.dopmi_archive_support_case(uuid,integer),public.dopmi_owned_cases(text,text[],boolean,integer,integer),
  public.dopmi_rescuer_activity(integer,integer),public.dopmi_acknowledge_rescuer_payments(uuid),
  public.dopmi_rescuer_dashboard_v2() to authenticated;
commit;
