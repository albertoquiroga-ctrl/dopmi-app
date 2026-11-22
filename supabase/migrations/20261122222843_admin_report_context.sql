begin;

-- Existing reports have a real creation timestamp, but no reliable historical
-- resubmission timestamp. Never backfill their cutoff with migration time.
alter table public.dopmi_content_reports add column version integer not null default 1 check(version>0);
alter table public.dopmi_content_reports add column reported_at timestamptz;
alter table public.dopmi_content_reports add column cutoff_basis text not null default 'legacy_created_at'
  check(cutoff_basis in ('reported_at','legacy_created_at'));
update public.dopmi_content_reports set reported_at=created_at;
alter table public.dopmi_content_reports alter column reported_at set not null;
alter table public.dopmi_content_reports alter column reported_at set default clock_timestamp();
alter table public.dopmi_content_reports alter column cutoff_basis set default 'reported_at';
create index dopmi_reports_target on public.dopmi_content_reports(target_type,target_id);

-- No FK to report/profile/Auth: deletion must not erase moderation evidence or
-- prevent the existing account-deletion flow. These are private RPC-only logs.
create table private.dopmi_report_actions (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null,target_type text not null,target_id uuid not null,
  subject_id uuid,actor_id uuid not null,action text not null,
  reason text not null check(char_length(reason)<=1000),
  previous_state jsonb not null,next_state jsonb not null,
  request_id uuid unique,request_payload jsonb,result jsonb,
  created_at timestamptz not null default clock_timestamp()
);
create index dopmi_report_actions_history on private.dopmi_report_actions(report_id,created_at desc,id desc);
create table private.dopmi_report_reads (
  id uuid primary key default gen_random_uuid(),report_id uuid not null,actor_id uuid not null,
  action text not null check(action in ('detail','conversation')),report_version integer not null,
  thread_id uuid,cutoff timestamptz not null,before_time timestamptz,before_id uuid,item_count integer,
  created_at timestamptz not null default clock_timestamp()
);
create index dopmi_report_reads_report on private.dopmi_report_reads(report_id,created_at desc,id desc);
create table private.dopmi_report_suspensions (
  subject_id uuid primary key,action_id uuid not null,report_id uuid not null,
  account_updated_at timestamptz not null,active boolean not null default true,
  created_at timestamptz not null default clock_timestamp()
);
alter table private.dopmi_report_actions enable row level security;
alter table private.dopmi_report_reads enable row level security;
alter table private.dopmi_report_suspensions enable row level security;
revoke all on private.dopmi_report_actions,private.dopmi_report_reads,private.dopmi_report_suspensions
  from public,anon,authenticated,service_role;

create function private.dopmi_report_version() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if new.version is distinct from old.version or
    (new.reason,new.details,new.status,new.resolution,new.reported_at,new.cutoff_basis) is distinct from
    (old.reason,old.details,old.status,old.resolution,old.reported_at,old.cutoff_basis) then
    new.version:=old.version+1;
  else new.version:=old.version;
  end if;
  return new;
end;
$$;
create trigger dopmi_report_version before update on public.dopmi_content_reports
  for each row execute function private.dopmi_report_version();

-- Any intervening profile write invalidates automatic restoration, even when an
-- external write shared PostgreSQL's transaction timestamp with the suspension.
create function private.dopmi_report_invalidate_suspension() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  update private.dopmi_report_suspensions set active=false where subject_id=new.id and active;
  return new;
end;
$$;
create trigger dopmi_report_invalidate_suspension after update on public.profiles
  for each row execute function private.dopmi_report_invalidate_suspension();

create function private.dopmi_report_subject(kind text,target uuid) returns uuid
language sql stable security definer set search_path='' as $$
  select case kind
    when 'adoption' then (select owner_id from public.dopmi_adoptions where id=target)
    when 'case' then (select owner_id from public.dopmi_rescue_records where id=target and kind='case')
    when 'rescuer' then (select id from public.profiles where id=target)
  end;
$$;

create function private.dopmi_report_person(person uuid) returns jsonb
language sql stable security definer set search_path='' as $$
  select jsonb_build_object('id',p.id,'name',p.display_name,'account_status',p.account_status,
    'created_at',p.created_at,'city',p.city,
    'published_adoptions_count',(select count(*) from public.dopmi_adoptions where owner_id=p.id and status='published'),
    'reports_received_count',(select count(*) from public.dopmi_content_reports r
      where private.dopmi_report_subject(r.target_type,r.target_id)=p.id))
  from public.profiles p where p.id=person and p.account_status<>'deleted';
$$;

create function private.dopmi_report_account(person uuid) returns jsonb
language sql stable security definer set search_path='' as $$
  select jsonb_build_object('id',p.id,'status',p.account_status,'updated_at',p.updated_at,
    'active_suspension_action_id',case when p.account_status='suspended' and s.active
      and s.account_updated_at=p.updated_at then s.action_id end)
  from public.profiles p left join private.dopmi_report_suspensions s on s.subject_id=p.id where p.id=person;
$$;

create function private.dopmi_report_target(kind text,target uuid) returns jsonb
language sql stable security definer set search_path='' as $$
  select case kind
    when 'adoption' then (select jsonb_build_object('id',id,'kind',kind,'status',status,'version',version)
      from public.dopmi_adoptions where id=target)
    when 'case' then (select jsonb_build_object('id',id,'kind',kind,'status',status,'version',version)
      from public.dopmi_rescue_records where id=target and kind='case')
    when 'rescuer' then (select jsonb_build_object('id',p.id,'kind',kind,'status',p.account_status,
      'version',coalesce(r.version,0)) from public.profiles p left join public.dopmi_rescuer_profiles r on r.owner_id=p.id where p.id=target)
  end;
$$;

create function private.dopmi_report_thread(r public.dopmi_content_reports) returns uuid
language sql stable security definer set search_path='' as $$
  select case when count(*)=1 then min(t.id::text)::uuid end
  from public.dopmi_threads t join public.dopmi_adoptions a on a.id=t.post_id
    join public.profiles subject on subject.id=a.owner_id and subject.account_status<>'deleted'
    join public.profiles reporter on reporter.id=r.reporter_id and reporter.account_status<>'deleted'
  where r.target_type='adoption' and t.post_id=r.target_id and t.owner_id=a.owner_id
    and t.adopter_id=r.reporter_id and t.owner_id<>t.adopter_id and t.created_at<=r.reported_at;
$$;

create or replace function public.dopmi_report_content(target_type text,target_id uuid,reason text,details text default '') returns uuid
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); report_id uuid; visible boolean:=false;
begin
  if not public.dopmi_actor_active() then raise exception 'Sesión activa requerida' using errcode='42501'; end if;
  if target_type is null or target_type not in ('adoption','case','rescuer') or reason is null
    or reason not in ('incorrect','unsafe','fraud','privacy','other') or char_length(coalesce(details,''))>1000 then
    raise exception 'Reporte inválido' using errcode='22023'; end if;
  if target_type='adoption' then
    visible:=exists(select 1 from public.dopmi_adoptions a join public.profiles p on p.id=a.owner_id
      where a.id=target_id and a.status='published' and p.account_status='active');
  elsif target_type='case' then
    visible:=exists(select 1 from public.dopmi_rescue_records r where r.id=target_id and r.kind='case' and private.dopmi_rescue_public_visible(r));
  else visible:=private.dopmi_public_rescuer(target_id);
  end if;
  if not visible then raise exception 'Contenido no disponible' using errcode='22023'; end if;
  insert into public.dopmi_content_reports as existing(reporter_id,target_type,target_id,reason,details)
    values(actor,target_type,target_id,reason,btrim(coalesce(details,'')))
    on conflict on constraint dopmi_content_reports_reporter_id_target_type_target_id_key do update set
      reason=excluded.reason,details=excluded.details,status='open',resolution='',
      reported_at=clock_timestamp(),cutoff_basis='reported_at',updated_at=clock_timestamp()
      where existing.reason is distinct from excluded.reason or existing.details is distinct from excluded.details or existing.status<>'open'
    returning id into report_id;
  if report_id is null then
    select r.id into report_id from public.dopmi_content_reports r
      where r.reporter_id=actor and r.target_type=$1 and r.target_id=$2;
  end if;
  return report_id;
end;
$$;

-- A moderation retirement must remain possible after suspending the responsible
-- account. Every publication/review/version/notification rule is preserved.
do $patch$
declare source text; anchor text:=$old$if not exists(select 1 from public.profiles where id=a.owner_id and account_status='active') then$old$;
begin
  source:=pg_get_functiondef('public.dopmi_review_adoption(uuid,integer,text,text)'::regprocedure);
  if (length(source)-length(replace(source,anchor,'')))/length(anchor)<>1 then
    raise exception 'Report moderation: unexpected adoption review guard'; end if;
  execute replace(source,anchor,$new$if decision<>'archived' and not exists(select 1 from public.profiles where id=a.owner_id and account_status='active') then$new$);
end;
$patch$;

create function public.dopmi_admin_report_detail(report_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r public.dopmi_content_reports; subject_id uuid; reporter jsonb; subject jsonb;
  account_state jsonb; target_state jsonb; content jsonb; a public.dopmi_adoptions;
  c public.dopmi_rescue_records; profile public.dopmi_rescuer_profiles; linked_thread uuid;
  conversation jsonb; withdraw_reason text; suspend_reason text; reactivate_reason text; history jsonb;
begin
  if not public.dopmi_is_admin() then raise exception 'Acceso administrativo requerido' using errcode='42501'; end if;
  select * into r from public.dopmi_content_reports where id=report_id;
  if not found then raise exception 'Reporte no disponible' using errcode='22023'; end if;
  subject_id:=private.dopmi_report_subject(r.target_type,r.target_id);
  reporter:=private.dopmi_report_person(r.reporter_id); subject:=private.dopmi_report_person(subject_id);
  account_state:=private.dopmi_report_account(subject_id); target_state:=private.dopmi_report_target(r.target_type,r.target_id);
  if subject is not null then subject:=subject||jsonb_build_object('account_updated_at',account_state->'updated_at',
    'active_suspension_action_id',account_state->'active_suspension_action_id'); end if;
  if r.target_type='adoption' then
    select * into a from public.dopmi_adoptions where id=r.target_id;
    -- Archived rows can later be edited as a private draft and rearchived.
    -- Without an immutable approved snapshot they are not public evidence.
    if found and a.status in ('published','adopted') then
      content:=jsonb_build_object('kind','adoption','id',a.id,'title',a.pet_name,'status',a.status,'version',a.version,
        'description',a.story,'city',a.city,'region',a.region,'public_photos',to_jsonb(a.photos),
        'public_url','https://www.dopmi.org/adoptions/'||a.id::text,'current_snapshot',true);
    end if;
  elsif r.target_type='case' then
    select * into c from public.dopmi_rescue_records where id=r.target_id and kind='case';
    if found and c.approved_snapshot is not null then
      content:=jsonb_build_object('kind','case','id',c.id,'title',coalesce(c.approved_snapshot->>'pet_name','Caso de apoyo'),
        'status',c.status,'version',c.version,'description',coalesce(c.approved_snapshot->>'story',''),
        'city',coalesce(c.approved_snapshot->>'city',''),'region',coalesce(c.approved_snapshot->>'region',c.approved_snapshot->>'state',''),
        'public_photos',case when jsonb_typeof(c.approved_snapshot->'photos')='array' then
          (select coalesce(jsonb_agg(photo),'[]'::jsonb) from jsonb_array_elements(c.approved_snapshot->'photos') photo
            where jsonb_typeof(photo)='string' and photo #>> '{}' ~ '\.(jpg|png|webp)$')
          else '[]'::jsonb end,'public_url',null,'current_snapshot',true);
    end if;
  else
    select * into profile from public.dopmi_rescuer_profiles where owner_id=r.target_id and approved_snapshot is not null;
    if found then
      content:=jsonb_build_object('kind','rescuer','id',profile.owner_id,
        'title',coalesce(profile.approved_snapshot->>'display_name','Perfil de rescatista'),
        'status',profile.status,'version',profile.version,'description',coalesce(profile.approved_snapshot->>'bio',''),
        'city',coalesce(profile.approved_snapshot->>'city',''),'region',coalesce(profile.approved_snapshot->>'region',''),
        'public_photos','[]'::jsonb,'public_url','https://www.dopmi.org/people/'||profile.owner_id::text,'current_snapshot',true);
    end if;
  end if;
  linked_thread:=private.dopmi_report_thread(r);
  conversation:=jsonb_build_object('available',linked_thread is not null,'cutoff',r.reported_at,
    'reason',case when linked_thread is null then 'No hay una conversación vinculada de forma inequívoca a esta adopción y estas personas.' end,
    'threads',case when linked_thread is null then '[]'::jsonb else
      (select jsonb_build_array(jsonb_build_object('id',t.id,'post_id',t.post_id,'pet_name',t.pet_name,
        'message_count_before_cutoff',(select count(*) from public.dopmi_messages m where m.thread_id=t.id and m.created_at<=r.reported_at)))
      from public.dopmi_threads t where t.id=linked_thread) end);
  withdraw_reason:=case when r.target_type='case' then 'El retiro individual de casos requiere revisar sus controles financieros. Puedes suspender la cuenta sin mover fondos.'
    when r.target_type='rescuer' then 'Este reporte corresponde a un perfil. Suspender la cuenta bloquea su presencia pública.'
    when subject is null or a.id is null then 'La publicación o su cuenta responsable ya no están disponibles.'
    when a.status not in ('published','adopted') then 'La publicación ya no está publicada o disponible para retirar.' end;
  suspend_reason:=case when subject is null then 'La cuenta responsable ya no está disponible.'
    when subject_id=auth.uid() then 'No puedes suspender tu propia cuenta.'
    when exists(select 1 from private.admin_memberships where user_id=subject_id and active) then 'No se puede suspender una cuenta administrativa desde reportes.'
    when subject->>'account_status'<>'active' then 'La cuenta debe estar activa para suspenderla desde este reporte.' end;
  reactivate_reason:=case when subject is null then 'La cuenta responsable ya no está disponible.'
    when subject_id=auth.uid() then 'No puedes reactivar tu propia cuenta.'
    when exists(select 1 from private.admin_memberships where user_id=subject_id and active) then 'No se puede modificar una cuenta administrativa desde reportes.'
    when account_state->>'active_suspension_action_id' is not null and exists(
      select 1 from private.dopmi_report_suspensions s where s.subject_id=private.dopmi_report_subject(r.target_type,r.target_id) and s.active and s.report_id<>r.id)
      then 'Revisa el reporte que originó la suspensión para decidir su reactivación.'
    when account_state->>'status'<>'suspended' or account_state->>'active_suspension_action_id' is null then
      'Sólo se puede revertir una suspensión vigente creada por este flujo, sin cambios posteriores en la cuenta.' end;
  select coalesce(jsonb_agg(x order by x.created_at desc,x.id desc),'[]'::jsonb) into history from (
    select h.id,coalesce(p.display_name,'Administración') as actor_name,h.action,h.reason,h.created_at,h.previous_state,h.next_state
    from private.dopmi_report_actions h left join public.profiles p on p.id=h.actor_id
    where h.report_id=r.id order by h.created_at desc,h.id desc limit 100) x;
  insert into private.dopmi_report_reads(report_id,actor_id,action,report_version,cutoff)
    values(r.id,auth.uid(),'detail',r.version,r.reported_at);
  return jsonb_build_object('report',jsonb_build_object('id',r.id,'target_type',r.target_type,'target_id',r.target_id,
      'reason',r.reason,'details',r.details,'status',r.status,'resolution',r.resolution,'created_at',r.created_at,
      'updated_at',r.updated_at,'version',r.version,'reported_at',r.reported_at,'cutoff_basis',r.cutoff_basis),
    'reporter',reporter,'subject',subject,'content',content,'conversation',conversation,'history',history,
    'capabilities',jsonb_build_object('withdraw_publication',jsonb_build_object('allowed',withdraw_reason is null,'reason',withdraw_reason),
      'suspend_account',jsonb_build_object('allowed',suspend_reason is null,'reason',suspend_reason),
      'reactivate_account',jsonb_build_object('allowed',reactivate_reason is null,'reason',reactivate_reason)));
end;
$$;

create function public.dopmi_admin_report_conversation(report_id uuid,expected_report_version integer,thread_id uuid,
  before_time timestamptz default null,before_id uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r public.dopmi_content_reports; linked_thread uuid; items jsonb; cursor jsonb; subject_id uuid;
begin
  if not public.dopmi_is_admin() then raise exception 'Acceso administrativo requerido' using errcode='42501'; end if;
  if (before_time is null)<>(before_id is null) then raise exception 'Cursor incompleto' using errcode='22023'; end if;
  select * into r from public.dopmi_content_reports where id=report_id;
  if not found then raise exception 'Reporte no disponible' using errcode='22023'; end if;
  if expected_report_version is distinct from r.version then raise exception 'El reporte cambió. Vuelve a cargarlo.' using errcode='40001'; end if;
  linked_thread:=private.dopmi_report_thread(r);
  if thread_id is null or linked_thread is null or linked_thread<>thread_id then
    raise exception 'Conversación no disponible para este reporte' using errcode='42501'; end if;
  subject_id:=private.dopmi_report_subject(r.target_type,r.target_id);
  select coalesce(jsonb_agg(jsonb_build_object('id',m.id,'sender_id',m.sender_id,
    'sender_role',case when m.sender_id=r.reporter_id then 'reporter' else 'subject' end,
    'body',m.body,'has_attachment',m.attachment_path is not null,'created_at',m.created_at)
    order by m.created_at desc,m.id desc),'[]'::jsonb) into items from (
      select id,sender_id,body,attachment_path,created_at from public.dopmi_messages m
      where m.thread_id=linked_thread and m.sender_id in (r.reporter_id,subject_id) and m.created_at<=r.reported_at
        and (before_time is null or (m.created_at,m.id)<(before_time,before_id))
      order by m.created_at desc,m.id desc limit 40) m;
  if jsonb_array_length(items)>0 and exists(select 1 from public.dopmi_messages m where m.thread_id=linked_thread
    and m.sender_id in (r.reporter_id,subject_id) and m.created_at<=r.reported_at
    and (m.created_at,m.id)<((items->-1->>'created_at')::timestamptz,(items->-1->>'id')::uuid)) then
    cursor:=jsonb_build_object('before_time',items->-1->>'created_at','before_id',items->-1->>'id');
  end if;
  insert into private.dopmi_report_reads(report_id,actor_id,action,report_version,thread_id,cutoff,before_time,before_id,item_count)
    values(r.id,auth.uid(),'conversation',r.version,linked_thread,r.reported_at,before_time,before_id,jsonb_array_length(items));
  return jsonb_build_object('report_id',r.id,'report_version',r.version,'thread_id',linked_thread,
    'cutoff',r.reported_at,'items',items,'next_cursor',cursor);
end;
$$;

create function public.dopmi_admin_report_action(report_id uuid,expected_version integer,action text,reason text,request_id uuid,
  expected_target_version integer default null,expected_account_updated_at timestamptz default null,
  expected_suspension_action_id uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r public.dopmi_content_reports; subject_id uuid; person public.profiles; prior jsonb; following jsonb;
  target_state jsonb; account_state jsonb; input jsonb; previous private.dopmi_report_actions;
  marker private.dopmi_report_suspensions; action_id uuid:=gen_random_uuid(); receipt jsonb; safe_reason text:=btrim(coalesce(reason,''));
begin
  if not public.dopmi_is_admin() then raise exception 'Acceso administrativo requerido' using errcode='42501'; end if;
  if request_id is null or expected_version is null or expected_version<1 or action is null
    or action not in ('reviewing','resolve','dismiss','withdraw_publication','suspend_account','reactivate_account')
    or char_length(safe_reason) not between 5 and 1000 then raise exception 'Acción o motivo inválidos' using errcode='22023'; end if;
  input:=jsonb_build_object('report_id',report_id,'expected_version',expected_version,'action',action,'reason',safe_reason,
    'expected_target_version',expected_target_version,'expected_account_updated_at',expected_account_updated_at,
    'expected_suspension_action_id',expected_suspension_action_id);
  perform pg_advisory_xact_lock(hashtextextended('dopmi-report-action:'||request_id::text,0));
  if not public.dopmi_is_admin() then raise exception 'Acceso administrativo requerido' using errcode='42501'; end if;
  select * into previous from private.dopmi_report_actions h where h.request_id=$5;
  if found then
    if previous.actor_id<>auth.uid() then raise exception 'Solicitud no disponible' using errcode='42501'; end if;
    if previous.request_payload is distinct from input then raise exception 'El identificador de la solicitud ya se utilizó' using errcode='22023'; end if;
    return previous.result||jsonb_build_object('replayed',true);
  end if;
  select * into r from public.dopmi_content_reports where id=report_id for update;
  if not found then raise exception 'Reporte no disponible' using errcode='22023'; end if;
  if expected_version is distinct from r.version then raise exception 'El reporte cambió. Vuelve a cargarlo.' using errcode='40001'; end if;
  subject_id:=private.dopmi_report_subject(r.target_type,r.target_id);
  target_state:=private.dopmi_report_target(r.target_type,r.target_id); account_state:=private.dopmi_report_account(subject_id);
  prior:=jsonb_build_object('report_status',r.status,'target',target_state,'account',account_state);
  if action='withdraw_publication' then
    if r.target_type<>'adoption' then raise exception 'El retiro individual no está disponible para este tipo de reporte' using errcode='22023'; end if;
    if subject_id is null or private.dopmi_report_person(subject_id) is null then raise exception 'Cuenta responsable no disponible' using errcode='42501'; end if;
    perform public.dopmi_review_adoption(r.target_id,expected_target_version,'archived',safe_reason);
  elsif action in ('suspend_account','reactivate_account') then
    select * into person from public.profiles where id=subject_id for update;
    if not found or person.id=auth.uid() or exists(select 1 from private.admin_memberships where user_id=person.id and active)
      or person.account_status in ('deleted','deletion_requested') then
      raise exception 'Esta cuenta no puede modificarse desde el reporte' using errcode='42501'; end if;
    if expected_account_updated_at is distinct from person.updated_at then raise exception 'La cuenta cambió. Vuelve a cargarla.' using errcode='40001'; end if;
    if action='suspend_account' then
      if person.account_status<>'active' then raise exception 'Sólo se puede suspender una cuenta activa' using errcode='42501'; end if;
      update public.profiles set account_status='suspended' where id=person.id returning * into person;
      insert into private.dopmi_report_suspensions(subject_id,action_id,report_id,account_updated_at)
        values(person.id,action_id,r.id,person.updated_at) on conflict on constraint dopmi_report_suspensions_pkey do update set
        action_id=excluded.action_id,report_id=excluded.report_id,account_updated_at=excluded.account_updated_at,active=true,created_at=clock_timestamp();
    else
      select * into marker from private.dopmi_report_suspensions s where s.subject_id=person.id for update;
      if not found or not marker.active or person.account_status<>'suspended' or marker.account_updated_at<>person.updated_at then
        raise exception 'La suspensión de este flujo ya no está vigente' using errcode='42501'; end if;
      if marker.report_id<>r.id then raise exception 'Revisa el reporte que originó la suspensión' using errcode='42501'; end if;
      if expected_suspension_action_id is distinct from marker.action_id then raise exception 'La suspensión cambió. Vuelve a cargarla.' using errcode='40001'; end if;
      update public.profiles set account_status='active' where id=person.id returning * into person;
    end if;
    insert into public.dopmi_notifications(user_id,kind,source_id,title)
      values(person.id,'review',action_id,case when action='suspend_account' then 'Tu cuenta fue suspendida por moderación' else 'Tu cuenta fue reactivada' end);
  end if;
  if not public.dopmi_is_admin() then raise exception 'Acceso administrativo requerido' using errcode='42501'; end if;
  update public.dopmi_content_reports set
    status=case action when 'reviewing' then 'reviewing' when 'resolve' then 'resolved' when 'dismiss' then 'dismissed' else status end,
    resolution=case when action in ('reviewing','resolve','dismiss') then safe_reason else resolution end,
    version=version+1,updated_at=clock_timestamp() where id=r.id returning * into r;
  target_state:=private.dopmi_report_target(r.target_type,r.target_id); account_state:=private.dopmi_report_account(subject_id);
  following:=jsonb_build_object('report_status',r.status,'target',target_state,'account',account_state);
  receipt:=jsonb_build_object('action_id',action_id,'replayed',false,'report_version',r.version,'target_state',target_state,'account_state',account_state);
  insert into private.dopmi_report_actions(id,report_id,target_type,target_id,subject_id,actor_id,action,reason,previous_state,next_state,request_id,request_payload,result)
    values(action_id,r.id,r.target_type,r.target_id,subject_id,auth.uid(),action,safe_reason,prior,following,request_id,input,receipt);
  return receipt;
end;
$$;

-- Keep the previous UI contract usable while its mutations also invalidate stale
-- context and appear in the same moderation history. Empty legacy notes remain valid.
create or replace function public.dopmi_admin_resolve_report(report_id uuid,next_status text,resolution_note text default '') returns void
language plpgsql security definer set search_path='' as $$
declare r public.dopmi_content_reports; before_state jsonb; subject_id uuid;
begin
  if not public.dopmi_is_admin() then raise exception 'Acceso administrativo requerido' using errcode='42501'; end if;
  if next_status is null or next_status not in ('reviewing','resolved','dismissed') or char_length(coalesce(resolution_note,''))>1000 then
    raise exception 'Resolución inválida' using errcode='22023'; end if;
  select * into r from public.dopmi_content_reports where id=report_id for update;
  if not found then raise exception 'Reporte no encontrado' using errcode='22023'; end if;
  before_state:=jsonb_build_object('report_status',r.status); subject_id:=private.dopmi_report_subject(r.target_type,r.target_id);
  update public.dopmi_content_reports set status=next_status,resolution=btrim(coalesce(resolution_note,'')),updated_at=clock_timestamp()
    where id=r.id returning * into r;
  insert into private.dopmi_report_actions(report_id,target_type,target_id,subject_id,actor_id,action,reason,previous_state,next_state)
    values(r.id,r.target_type,r.target_id,subject_id,auth.uid(),case next_status when 'resolved' then 'resolve' when 'dismissed' then 'dismiss' else 'reviewing' end,
      btrim(coalesce(resolution_note,'')),before_state,jsonb_build_object('report_status',r.status));
  insert into private.admin_access_log(actor_id,action) values(auth.uid(),'reports.resolve');
end;
$$;

revoke all on function private.dopmi_report_version(),private.dopmi_report_invalidate_suspension(),
  private.dopmi_report_subject(text,uuid),private.dopmi_report_person(uuid),private.dopmi_report_account(uuid),
  private.dopmi_report_target(text,uuid),private.dopmi_report_thread(public.dopmi_content_reports)
  from public,anon,authenticated,service_role;
revoke all on function public.dopmi_admin_report_detail(uuid),
  public.dopmi_admin_report_conversation(uuid,integer,uuid,timestamptz,uuid),
  public.dopmi_admin_report_action(uuid,integer,text,text,uuid,integer,timestamptz,uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.dopmi_admin_report_detail(uuid),
  public.dopmi_admin_report_conversation(uuid,integer,uuid,timestamptz,uuid),
  public.dopmi_admin_report_action(uuid,integer,text,text,uuid,integer,timestamptz,uuid) to authenticated;

commit;
