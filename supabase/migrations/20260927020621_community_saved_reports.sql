begin;

create table public.dopmi_saved_cases (
  user_id uuid not null references public.profiles(id) on delete cascade,
  case_id uuid not null references public.dopmi_rescue_records(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, case_id)
);

create table public.dopmi_saved_rescuers (
  user_id uuid not null references public.profiles(id) on delete cascade,
  rescuer_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, rescuer_id),
  check (user_id <> rescuer_id)
);

create table public.dopmi_content_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  target_type text not null check (target_type in ('adoption','case','rescuer')),
  target_id uuid not null,
  reason text not null check (reason in ('incorrect','unsafe','fraud','privacy','other')),
  details text not null default '' check (char_length(details) <= 1000),
  status text not null default 'open' check (status in ('open','reviewing','resolved','dismissed')),
  resolution text not null default '' check (char_length(resolution) <= 1000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (reporter_id, target_type, target_id)
);

alter table public.dopmi_saved_cases enable row level security;
alter table public.dopmi_saved_rescuers enable row level security;
alter table public.dopmi_content_reports enable row level security;

revoke all on public.dopmi_saved_cases, public.dopmi_saved_rescuers, public.dopmi_content_reports from public, anon, authenticated;

create function private.dopmi_public_rescuer(person uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(
    select 1
    from public.profiles p
    where p.id=person and p.account_status='active'
      and (
        exists(select 1 from public.dopmi_adoptions a where a.owner_id=person and a.status in ('published','adopted'))
        or private.dopmi_rescuer_verified(person)
      )
  );
$$;

create or replace function public.dopmi_public_profile(person_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$
  select jsonb_build_object(
    'id',a.owner_id,'name',a.publisher_name,'bio',a.publisher_bio,'city',a.city,'region',a.region,
    'adopted_count',(select count(*) from public.dopmi_adoptions x where x.owner_id=person_id and x.status='adopted'),
    'saved',exists(select 1 from public.dopmi_saved_rescuers s where s.user_id=auth.uid() and s.rescuer_id=person_id and public.dopmi_actor_active())
  )
  from public.dopmi_adoptions a join public.profiles p on p.id=a.owner_id
  where a.owner_id=person_id and a.status in ('published','adopted') and p.account_status='active'
  order by a.published_at desc,a.id limit 1;
$$;

create function public.dopmi_saved_adoptions(page_number integer default 1, page_size integer default 20) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid := auth.uid();
begin
  if not public.dopmi_actor_active() then raise exception 'Sesión activa requerida' using errcode='42501'; end if;
  if page_number is null or page_number<1 or page_size is null or page_size<1 or page_size>50 then
    raise exception 'Página inválida' using errcode='22023';
  end if;
  return jsonb_build_object(
    'total',(select count(*) from public.dopmi_favorites f where f.user_id=actor),
    'items',coalesce((select jsonb_agg(x.item order by x.created_at desc,x.id) from (
      select f.created_at,f.post_id id,
        case when a.status='published' and p.account_status='active'
          then private.dopmi_public_post(a)||jsonb_build_object('saved',true,'available',true)
          else jsonb_build_object('id',f.post_id,'saved',true,'available',false)
        end item
      from public.dopmi_favorites f
      left join public.dopmi_adoptions a on a.id=f.post_id
      left join public.profiles p on p.id=a.owner_id
      where f.user_id=actor
      order by f.created_at desc,f.post_id
      limit page_size offset (page_number::bigint-1)*page_size
    ) x),'[]'::jsonb)
  );
end;
$$;

create function public.dopmi_match_threads(search_text text default '',page_number integer default 1,page_size integer default 20) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid := auth.uid(); query text := btrim(coalesce(search_text,''));
begin
  if not public.dopmi_actor_active() then raise exception 'Sesión activa requerida' using errcode='42501'; end if;
  if char_length(query)>100 or page_number<1 or page_size<1 or page_size>50 then raise exception 'Búsqueda inválida' using errcode='22023'; end if;
  return jsonb_build_object(
    'total',(select count(*) from public.dopmi_threads t join public.profiles p on p.id=case when t.owner_id=actor then t.adopter_id else t.owner_id end
      where actor in(t.owner_id,t.adopter_id) and (query='' or t.pet_name ilike '%'||query||'%' or p.display_name ilike '%'||query||'%')),
    'items',coalesce((select jsonb_agg(to_jsonb(rows)) from (
      select t.*,p.display_name as participant_name,
        (select m.body from public.dopmi_messages m where m.thread_id=t.id order by m.created_at desc,m.id desc limit 1) as last_message,
        (select count(*) from public.dopmi_notifications n where n.thread_id=t.id and n.user_id=actor and n.read_at is null) as unread_count
      from public.dopmi_threads t join public.profiles p on p.id=case when t.owner_id=actor then t.adopter_id else t.owner_id end
      where actor in(t.owner_id,t.adopter_id) and (query='' or t.pet_name ilike '%'||query||'%' or p.display_name ilike '%'||query||'%')
      order by t.updated_at desc,t.id limit page_size offset (page_number::bigint-1)*page_size
    ) rows),'[]'::jsonb)
  );
end;
$$;

create function public.dopmi_set_case_favorite(target_case uuid, saved boolean) returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid := auth.uid(); record public.dopmi_rescue_records;
begin
  if not public.dopmi_actor_active() then raise exception 'Sesión activa requerida' using errcode='42501'; end if;
  if saved then
    select * into record from public.dopmi_rescue_records r where r.id=target_case and r.kind='case' and private.dopmi_rescue_public_visible(r);
    if not found then raise exception 'Caso no disponible' using errcode='22023'; end if;
    insert into public.dopmi_saved_cases(user_id,case_id) values(actor,target_case) on conflict do nothing;
  else
    delete from public.dopmi_saved_cases where user_id=actor and case_id=target_case;
  end if;
end;
$$;

create function public.dopmi_saved_case_list(page_number integer default 1, page_size integer default 20) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid := auth.uid();
begin
  if not public.dopmi_actor_active() then raise exception 'Sesión activa requerida' using errcode='42501'; end if;
  if page_number is null or page_number<1 or page_size is null or page_size<1 or page_size>50 then raise exception 'Página inválida' using errcode='22023'; end if;
  return jsonb_build_object(
    'total',(select count(*) from public.dopmi_saved_cases s where s.user_id=actor),
    'items',coalesce((select jsonb_agg(x.item order by x.created_at desc,x.id) from (
      select s.created_at,s.case_id id,
        case when r.id is not null and private.dopmi_rescue_public_visible(r)
          then jsonb_build_object('id',r.id,'owner_id',r.owner_id,'status',r.status,'public_data',r.approved_snapshot,'saved',true,'available',true)
          else jsonb_build_object('id',s.case_id,'saved',true,'available',false)
        end item
      from public.dopmi_saved_cases s left join public.dopmi_rescue_records r on r.id=s.case_id
      where s.user_id=actor
      order by s.created_at desc,s.case_id
      limit page_size offset (page_number::bigint-1)*page_size
    ) x),'[]'::jsonb)
  );
end;
$$;

create function public.dopmi_set_rescuer_favorite(target_rescuer uuid, saved boolean) returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid := auth.uid();
begin
  if not public.dopmi_actor_active() then raise exception 'Sesión activa requerida' using errcode='42501'; end if;
  if actor=target_rescuer then raise exception 'No puedes guardar tu propio perfil' using errcode='22023'; end if;
  if saved then
    if not private.dopmi_public_rescuer(target_rescuer) then raise exception 'Perfil no disponible' using errcode='22023'; end if;
    insert into public.dopmi_saved_rescuers(user_id,rescuer_id) values(actor,target_rescuer) on conflict do nothing;
  else
    delete from public.dopmi_saved_rescuers where user_id=actor and rescuer_id=target_rescuer;
  end if;
end;
$$;

create function public.dopmi_saved_rescuer_list(page_number integer default 1, page_size integer default 20) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid := auth.uid();
begin
  if not public.dopmi_actor_active() then raise exception 'Sesión activa requerida' using errcode='42501'; end if;
  if page_number is null or page_number<1 or page_size is null or page_size<1 or page_size>50 then raise exception 'Página inválida' using errcode='22023'; end if;
  return jsonb_build_object(
    'total',(select count(*) from public.dopmi_saved_rescuers s where s.user_id=actor),
    'items',coalesce((select jsonb_agg(x.item order by x.created_at desc,x.id) from (
      select s.created_at,s.rescuer_id id,
        case when private.dopmi_public_rescuer(s.rescuer_id)
          then coalesce(public.dopmi_public_profile(s.rescuer_id),jsonb_build_object('id',s.rescuer_id))||jsonb_build_object('id',s.rescuer_id,'saved',true,'available',true)
          else jsonb_build_object('id',s.rescuer_id,'saved',true,'available',false)
        end item
      from public.dopmi_saved_rescuers s where s.user_id=actor
      order by s.created_at desc,s.rescuer_id
      limit page_size offset (page_number::bigint-1)*page_size
    ) x),'[]'::jsonb)
  );
end;
$$;

create function public.dopmi_report_content(target_type text,target_id uuid,reason text,details text default '') returns uuid
language plpgsql security definer set search_path='' as $$
declare actor uuid := auth.uid(); report_id uuid; visible boolean := false;
begin
  if not public.dopmi_actor_active() then raise exception 'Sesión activa requerida' using errcode='42501'; end if;
  if target_type not in ('adoption','case','rescuer') or reason not in ('incorrect','unsafe','fraud','privacy','other') or char_length(coalesce(details,''))>1000 then
    raise exception 'Reporte inválido' using errcode='22023';
  end if;
  if target_type='adoption' then
    visible := exists(select 1 from public.dopmi_adoptions a join public.profiles p on p.id=a.owner_id where a.id=target_id and a.status='published' and p.account_status='active');
  elsif target_type='case' then
    visible := exists(select 1 from public.dopmi_rescue_records r where r.id=target_id and r.kind='case' and private.dopmi_rescue_public_visible(r));
  else
    visible := private.dopmi_public_rescuer(target_id);
  end if;
  if not visible then raise exception 'Contenido no disponible' using errcode='22023'; end if;
  insert into public.dopmi_content_reports(reporter_id,target_type,target_id,reason,details)
  values(actor,target_type,target_id,reason,btrim(coalesce(details,'')))
  on conflict on constraint dopmi_content_reports_reporter_id_target_type_target_id_key do update set
    reason=excluded.reason,details=excluded.details,status='open',resolution='',updated_at=now()
  returning id into report_id;
  return report_id;
end;
$$;

create function public.dopmi_admin_reports(status_filter text default 'open',page_number integer default 1,page_size integer default 20) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
  if not public.dopmi_is_admin() then raise exception 'Acceso administrativo requerido' using errcode='42501'; end if;
  if status_filter not in ('open','reviewing','resolved','dismissed','all') or page_number<1 or page_size<1 or page_size>50 then raise exception 'Filtros inválidos' using errcode='22023'; end if;
  insert into private.admin_access_log(actor_id,action) values(auth.uid(),'reports.list');
  return jsonb_build_object(
    'total',(select count(*) from public.dopmi_content_reports r where status_filter='all' or r.status=status_filter),
    'items',coalesce((select jsonb_agg(x) from (
      select id,target_type,target_id,reason,details,status,resolution,created_at,updated_at
      from public.dopmi_content_reports r where status_filter='all' or r.status=status_filter
      order by created_at,id limit page_size offset (page_number::bigint-1)*page_size
    ) x),'[]'::jsonb)
  );
end;
$$;

create function public.dopmi_admin_resolve_report(report_id uuid,next_status text,resolution_note text default '') returns void
language plpgsql security definer set search_path='' as $$
begin
  if not public.dopmi_is_admin() then raise exception 'Acceso administrativo requerido' using errcode='42501'; end if;
  if next_status not in ('reviewing','resolved','dismissed') or char_length(coalesce(resolution_note,''))>1000 then raise exception 'Resolución inválida' using errcode='22023'; end if;
  update public.dopmi_content_reports set status=next_status,resolution=btrim(coalesce(resolution_note,'')),updated_at=now() where id=report_id;
  if not found then raise exception 'Reporte no encontrado' using errcode='22023'; end if;
  insert into private.admin_access_log(actor_id,action) values(auth.uid(),'reports.resolve');
end;
$$;

revoke all on function private.dopmi_public_rescuer(uuid) from public,anon,authenticated;
revoke all on function public.dopmi_saved_adoptions(integer,integer),public.dopmi_match_threads(text,integer,integer),public.dopmi_set_case_favorite(uuid,boolean),public.dopmi_saved_case_list(integer,integer),public.dopmi_set_rescuer_favorite(uuid,boolean),public.dopmi_saved_rescuer_list(integer,integer),public.dopmi_report_content(text,uuid,text,text),public.dopmi_admin_reports(text,integer,integer),public.dopmi_admin_resolve_report(uuid,text,text) from public,anon,authenticated;
grant execute on function public.dopmi_saved_adoptions(integer,integer),public.dopmi_match_threads(text,integer,integer),public.dopmi_set_case_favorite(uuid,boolean),public.dopmi_saved_case_list(integer,integer),public.dopmi_set_rescuer_favorite(uuid,boolean),public.dopmi_saved_rescuer_list(integer,integer),public.dopmi_report_content(text,uuid,text,text),public.dopmi_admin_reports(text,integer,integer),public.dopmi_admin_resolve_report(uuid,text,text) to authenticated;

commit;
