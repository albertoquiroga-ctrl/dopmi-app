begin;
-- Additive contracts for the approved Irlanda 889c096 update. Existing builds
-- retain their RPCs and legacy data; authored edits retain draft/review rules.
alter table public.dopmi_adoptions add column age_band text check(age_band in ('puppy','adult','senior'));
alter table public.dopmi_adoptions add column coexistence text[] not null default '{}'
  check(cardinality(coexistence)<=6 and coexistence <@ array['children','pets','apartment','yard','first_time','experienced']::text[]);
alter table public.dopmi_adoptions drop constraint dopmi_adoptions_photos_check;
alter table public.dopmi_adoptions add constraint dopmi_adoptions_photos_check check(cardinality(photos)<=6);
alter table public.dopmi_adoptions drop constraint dopmi_adoptions_personality;
alter table public.dopmi_adoptions add constraint dopmi_adoptions_personality check(cardinality(personality)<=22 and personality <@ array['affectionate','playful','calm','active','sociable','independent','alegre','feliz','esperanzado','emocionado','triste','enojado','ansioso','tranquilo','contento','satisfecho','solo','nervioso','dormilon','protector','obediente','timido']::text[]);
create or replace function public.dopmi_save_adoption(payload jsonb,target_id uuid default null,expected_version integer default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); a public.dopmi_adoptions; photo text; linked_case uuid; requested_traits text[];
begin
  if jsonb_typeof(payload) is distinct from 'object' or char_length(payload::text)>16000 then
    raise exception 'Publicación inválida' using errcode='22023'; end if;
  if payload ? 'personality' then
    if jsonb_typeof(payload->'personality') is distinct from 'array' then
      raise exception 'Personalidad inválida' using errcode='22023';
    end if;
    select coalesce(array_agg(value), '{}') into requested_traits
      from jsonb_array_elements_text(payload->'personality') value;
    if cardinality(requested_traits)>22 or not requested_traits <@ array['affectionate','playful','calm','active','sociable','independent','alegre','feliz','esperanzado','emocionado','triste','enojado','ansioso','tranquilo','contento','satisfecho','solo','nervioso','dormilon','protector','obediente','timido']::text[] then
      raise exception 'Personalidad inválida' using errcode='22023';
    end if;
  end if;
  if payload ? 'coexistence' and (jsonb_typeof(payload->'coexistence') is distinct from 'array' or not array(select jsonb_array_elements_text(payload->'coexistence')) <@ array['children','pets','apartment','yard','first_time','experienced']::text[] or jsonb_array_length(payload->'coexistence')>6) then
    raise exception 'Convivencia inválida' using errcode='22023'; end if;
  if payload ? 'age_band' and nullif(payload->>'age_band','') is not null and payload->>'age_band' not in ('puppy','adult','senior') then
    raise exception 'Edad inválida' using errcode='22023'; end if;
  if payload ? 'rescue_case_id' and nullif(payload->>'rescue_case_id','') is not null then
    begin linked_case:=(payload->>'rescue_case_id')::uuid;
    exception when invalid_text_representation then
      raise exception 'Caso vinculado inválido' using errcode='22023';
    end;
    if not exists(select 1 from public.dopmi_rescue_records r
      where r.id=linked_case and r.owner_id=actor and r.kind='case' and r.status='approved') then
      raise exception 'El caso aprobado no está disponible para vincular' using errcode='42501';
    end if;
  end if;
  if target_id is null then
    insert into public.dopmi_adoptions(owner_id,rescue_case_id) values(actor,linked_case) returning * into a;
  else
    select * into a from public.dopmi_adoptions where id=target_id for update;
    if not found or a.owner_id<>actor then raise exception 'Publicación no disponible' using errcode='42501'; end if;
    if expected_version is distinct from a.version then raise exception 'La publicación cambió. Vuelve a cargarla.' using errcode='40001'; end if;
    if a.status='submitted' then raise exception 'Retira la solicitud de revisión antes de editar.' using errcode='22023'; end if;
    linked_case:=case when payload ? 'rescue_case_id' then linked_case else a.rescue_case_id end;
  end if;
  update public.dopmi_adoptions set
    rescue_case_id=linked_case,
    age_band=case when payload ? 'age_band' then nullif(payload->>'age_band','') else a.age_band end,
    coexistence=case when payload ? 'coexistence' then array(select distinct jsonb_array_elements_text(payload->'coexistence')) else a.coexistence end,
    personality=case when payload ? 'personality' then requested_traits else a.personality end,
    pet_name=btrim(coalesce(payload->>'pet_name','')), species=coalesce(payload->>'species','dog'),
    sex=coalesce(payload->>'sex','female'), age_months=coalesce((payload->>'age_months')::integer,0),
    size=coalesce(payload->>'size','medium'), breed=btrim(coalesce(payload->>'breed','')),
    city=btrim(coalesce(payload->>'city','')),region=btrim(coalesce(payload->>'region','')),
    story=btrim(coalesce(payload->>'story','')), special_care=btrim(coalesce(payload->>'special_care','')),
    publisher_name=btrim(coalesce(payload->>'publisher_name','')),publisher_bio=btrim(coalesce(payload->>'publisher_bio','')),
    vaccinated=(payload->>'vaccinated')::boolean,sterilized=(payload->>'sterilized')::boolean,
    social_dogs=(payload->>'social_dogs')::boolean,social_cats=(payload->>'social_cats')::boolean,social_children=(payload->>'social_children')::boolean,
    photos=coalesce(array(select jsonb_array_elements_text(payload->'photos')),'{}'::text[]),
    status='draft',submitted_at=null,version=case when target_id is null then 1 else a.version+1 end,updated_at=now()
  where id=a.id returning * into a;
  foreach photo in array a.photos loop
    if photo is null or photo not like actor::text||'/'||a.id::text||'/%' then
      raise exception 'La foto no pertenece a esta publicación' using errcode='22023'; end if;
  end loop;
  return to_jsonb(a);
exception when unique_violation then
  raise exception 'Este caso ya tiene una publicación de adopción vinculada' using errcode='23505';
end;
$$;

revoke all on function public.dopmi_save_adoption(jsonb,uuid,integer) from public;
grant execute on function public.dopmi_save_adoption(jsonb,uuid,integer) to authenticated;


create or replace function private.dopmi_public_post(p public.dopmi_adoptions) returns jsonb
language sql immutable set search_path='' as $$
  select jsonb_build_object('id',p.id,'owner_id',p.owner_id,'pet_name',p.pet_name,'species',p.species,'sex',p.sex,
    'age_months',p.age_months,'age_band',p.age_band,'coexistence',p.coexistence,'personality',p.personality,'rescue_case_id',p.rescue_case_id,'size',p.size,'breed',p.breed,'city',p.city,'region',p.region,'story',p.story,
    'vaccinated',p.vaccinated,'sterilized',p.sterilized,'social_dogs',p.social_dogs,'social_cats',p.social_cats,
    'social_children',p.social_children,'special_care',p.special_care,'publisher_name',p.publisher_name,
    'publisher_bio',p.publisher_bio,'photos',p.photos,'status',p.status,'published_at',p.published_at);
$$;

create or replace function public.dopmi_discovery(
  filters jsonb default '{}',
  page_number integer default 1,
  page_size integer default 12
) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  result jsonb;
  actor uuid := auth.uid();
  requested_traits text[] := '{}';
  origin_lat numeric;
  origin_lon numeric;
  radius_km numeric;
begin
  if page_number is null or page_number < 1
    or page_size is null or page_size not between 1 and 30
    or jsonb_typeof(filters) is distinct from 'object'
    or char_length(filters::text) > 1500 then
    raise exception 'Filtros o paginación inválidos' using errcode = '22023';
  end if;

  if filters ? 'personality' then
    if jsonb_typeof(filters->'personality') is distinct from 'array' then
      raise exception 'Personalidad inválida' using errcode = '22023';
    end if;
    select coalesce(array_agg(value), '{}') into requested_traits
      from jsonb_array_elements_text(filters->'personality') value;
    if cardinality(requested_traits) > 22
      or not requested_traits <@ array['affectionate','playful','calm','active','sociable','independent','alegre','feliz','esperanzado','emocionado','triste','enojado','ansioso','tranquilo','contento','satisfecho','solo','nervioso','dormilon','protector','obediente','timido']::text[] then
      raise exception 'Personalidad inválida' using errcode = '22023';
    end if;
  end if;

  if requested_traits && array['tranquilo','calm']::text[] then
    requested_traits:=requested_traits || array['tranquilo','calm']::text[];
  end if;
  if filters ?| array['latitude','longitude','radius_km'] then
    if not (filters ?& array['latitude','longitude','radius_km'])
      or coalesce(filters->>'latitude','') !~ '^-?[0-9]+([.][0-9]+)?$'
      or coalesce(filters->>'longitude','') !~ '^-?[0-9]+([.][0-9]+)?$'
      or coalesce(filters->>'radius_km','') !~ '^[0-9]+([.][0-9]+)?$' then
      raise exception 'Ubicación aproximada inválida' using errcode = '22023';
    end if;
    origin_lat := (filters->>'latitude')::numeric;
    origin_lon := (filters->>'longitude')::numeric;
    radius_km := (filters->>'radius_km')::numeric;
    if origin_lat not between -90 and 90 or origin_lon not between -180 and 180
      or radius_km not between 1 and 100 then
      raise exception 'Ubicación aproximada inválida' using errcode = '22023';
    end if;
  end if;

  with candidates as (
    select a as post, a.id, a.published_at, a.personality,
      case when origin_lat is not null and a.approximate_latitude is not null then
        round((6371 * acos(least(1, greatest(-1,
          cos(radians(origin_lat::double precision))
          * cos(radians(a.approximate_latitude::double precision))
          * cos(radians(a.approximate_longitude::double precision) - radians(origin_lon::double precision))
          + sin(radians(origin_lat::double precision))
          * sin(radians(a.approximate_latitude::double precision))
        ))))::numeric, 1)
      end as distance_km
    from public.dopmi_adoptions a
    join public.profiles p on p.id = a.owner_id
    where a.status = 'published' and p.account_status = 'active'
      and (coalesce(filters->>'species','') = '' or a.species = filters->>'species')
      and (coalesce(filters->>'sex','') = '' or a.sex = filters->>'sex')
      and (coalesce(filters->>'size','') = '' or a.size = filters->>'size')
      and (coalesce(filters->>'city','') = '' or strpos(lower(a.city), lower(filters->>'city')) > 0)
      and (coalesce(filters->>'region','') = '' or strpos(lower(a.region), lower(filters->>'region')) > 0)
      and (cardinality(requested_traits) = 0 or a.personality && requested_traits)
      and (coalesce((filters->>'saved')::boolean,false) = false or (
        public.dopmi_actor_active() and exists(
          select 1 from public.dopmi_favorites f where f.post_id = a.id and f.user_id = actor
        )
      ))
  ), matches as (
    select * from candidates
    where radius_km is null or (distance_km is not null and distance_km <= radius_km)
  ), page as (
    select * from matches
    order by published_at desc, id
    limit page_size offset (page_number::bigint - 1) * page_size
  )
  select jsonb_build_object(
    'total', (select count(*) from matches),
    'items', coalesce((select jsonb_agg(
      private.dopmi_public_post(page.post)
      || jsonb_build_object(
        'personality', page.personality,
        'distance_km', page.distance_km,
        'saved', exists(
          select 1 from public.dopmi_favorites f
          where f.post_id = page.id and f.user_id = actor and public.dopmi_actor_active()
        )
      ) order by page.published_at desc, page.id
    ) from page), '[]'::jsonb)
  ) into result;
  return result;
end;
$$;

revoke all on function public.dopmi_discovery(jsonb,integer,integer) from public, anon, authenticated;
grant execute on function public.dopmi_discovery(jsonb,integer,integer) to anon, authenticated;


-- The post lock is shared with the older start-thread RPC. Only the transaction
-- that creates the thread sends the introduction; retries merely return its ID.
create function public.dopmi_start_adoption_contact(post_id uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); a public.dopmi_adoptions; result uuid;
begin
  select * into a from public.dopmi_adoptions where id=$1 for update;
  if not found or a.status<>'published' or a.owner_id=actor or not exists(
    select 1 from public.profiles where id=a.owner_id and account_status='active') then
    raise exception 'Esta publicación no está disponible para contacto' using errcode='22023'; end if;
  insert into public.dopmi_threads(post_id,owner_id,adopter_id,pet_name)
    values(a.id,a.owner_id,actor,a.pet_name)
    on conflict on constraint dopmi_threads_post_id_adopter_id_key do nothing returning id into result;
  if result is not null then
    perform public.dopmi_send_message(result,gen_random_uuid(),
      '¡Hola! 👋 Me encantó '||a.pet_name||', me gustaría saber un poquito más sobre '||
      case when a.sex='female' then 'ella' else 'él' end||' 🐾');
  else
    select id into result from public.dopmi_threads t where t.post_id=$1 and t.adopter_id=actor;
  end if;
  return result;
end;
$$;
revoke all on function public.dopmi_start_adoption_contact(uuid) from public,anon;
grant execute on function public.dopmi_start_adoption_contact(uuid) to authenticated;

create function public.dopmi_thread_detail(thread_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); result jsonb;
begin
  select to_jsonb(t)||jsonb_build_object('participant_name',p.display_name,
    'case_id',case when actor=t.owner_id then a.rescue_case_id end,
    'photo',case when actor=t.owner_id or a.status='published' then a.photos[1] end)
  into result from public.dopmi_threads t join public.dopmi_adoptions a on a.id=t.post_id
    join public.profiles p on p.id=case when actor=t.owner_id then t.adopter_id else t.owner_id end
  where t.id=$1 and actor in(t.owner_id,t.adopter_id);
  if result is null then raise exception 'Conversación no disponible' using errcode='42501'; end if;
  return result;
end;
$$;
revoke all on function public.dopmi_thread_detail(uuid) from public,anon;
grant execute on function public.dopmi_thread_detail(uuid) to authenticated;

-- Group-level totals are calculated before pagination. This helper is private;
-- callers must supply the authenticated owner, never an editable experience.
create function private.dopmi_rescuer_threads(actor uuid,history boolean)
returns table(group_id uuid,thread_id uuid,participant_name text,unread bigint,item jsonb)
language sql stable set search_path='' as $$
  select coalesce(a.rescue_case_id,a.id),t.id,p.display_name,
    (select count(*) from public.dopmi_notifications n where n.thread_id=t.id and n.user_id=$1 and n.read_at is null),
    to_jsonb(t)||jsonb_build_object('participant_name',p.display_name,'case_id',a.rescue_case_id,
      'photo',a.photos[1],
      'last_message',(select m.body from public.dopmi_messages m where m.thread_id=t.id order by m.created_at desc,m.id desc limit 1),
      'unread_count',(select count(*) from public.dopmi_notifications n where n.thread_id=t.id and n.user_id=$1 and n.read_at is null))
  from public.dopmi_threads t join public.dopmi_adoptions a on a.id=t.post_id
    join public.profiles p on p.id=t.adopter_id
    left join public.dopmi_rescue_records r on r.id=a.rescue_case_id
  where t.owner_id=$1 and $1=auth.uid()
    and $2=(t.status='closed' or a.status in('archived','adopted','rejected') or coalesce(r.status='closed',false));
$$;
revoke all on function private.dopmi_rescuer_threads(uuid,boolean) from public,anon,authenticated;

create function public.dopmi_rescuer_group_threads(group_id uuid,page_number integer default 1,page_size integer default 20,history boolean default false)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); result jsonb;
begin
  if $1 is null or page_number is null or page_number<1 or page_size is null or page_size not between 1 and 50 or history is null then
    raise exception 'Paginación inválida' using errcode='22023'; end if;
  if not exists(select 1 from public.dopmi_adoptions a where a.owner_id=actor and coalesce(a.rescue_case_id,a.id)=$1) then
    raise exception 'Caso no disponible' using errcode='42501'; end if;
  with entries as (select * from private.dopmi_rescuer_threads(actor,history) t where t.group_id=$1),
  page as (select * from entries order by unread desc,lower(participant_name),thread_id limit page_size offset (page_number::bigint-1)*page_size)
  select jsonb_build_object('total',(select count(*) from entries),
    'items',coalesce((select jsonb_agg(item order by unread desc,lower(participant_name),thread_id) from page),'[]'::jsonb)) into result;
  return result;
end;
$$;
revoke all on function public.dopmi_rescuer_group_threads(uuid,integer,integer,boolean) from public,anon;
grant execute on function public.dopmi_rescuer_group_threads(uuid,integer,integer,boolean) to authenticated;

create function public.dopmi_rescuer_inbox(page_number integer default 1,page_size integer default 20,history boolean default false)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); result jsonb;
begin
  if page_number is null or page_number<1 or page_size is null or page_size not between 1 and 50 or history is null then
    raise exception 'Paginación inválida' using errcode='22023'; end if;
  with posts as (
    select distinct on(coalesce(a.rescue_case_id,a.id))
      coalesce(a.rescue_case_id,a.id) id,a.id post_id,a.rescue_case_id case_id,
      coalesce(nullif(r.public_data->>'pet_name',''),a.pet_name) pet_name,a.photos[1] photo
    from public.dopmi_adoptions a left join public.dopmi_rescue_records r on r.id=a.rescue_case_id
    where a.owner_id=actor and (
      (not history and a.status not in('archived','adopted','rejected') and coalesce(r.status<>'closed',true))
      or exists(select 1 from private.dopmi_rescuer_threads(actor,history) t where t.group_id=coalesce(a.rescue_case_id,a.id)))
    order by coalesce(a.rescue_case_id,a.id),a.updated_at desc,a.id
  ), entries as (select * from private.dopmi_rescuer_threads(actor,history)),
  groups as (
    select p.*,coalesce((select sum(t.unread) from entries t where t.group_id=p.id),0) unread_count,
      (select count(*) from entries t where t.group_id=p.id) thread_count
    from posts p
  ), page as (select * from groups order by unread_count desc,lower(pet_name),id limit page_size offset (page_number::bigint-1)*page_size)
  select jsonb_build_object('total',(select count(*) from groups),
    'items',coalesce((select jsonb_agg(to_jsonb(p)||jsonb_build_object('threads_total',p.thread_count,
      'threads',(public.dopmi_rescuer_group_threads(p.id,1,20,history)->'items')) order by p.unread_count desc,lower(p.pet_name),p.id) from page p),'[]'::jsonb)) into result;
  return result;
end;
$$;
revoke all on function public.dopmi_rescuer_inbox(integer,integer,boolean) from public,anon;
grant execute on function public.dopmi_rescuer_inbox(integer,integer,boolean) to authenticated;

-- Removal is limited to never-submitted draft expenses. Existing reviewed or
-- financially referenced records retain their established lifecycle and audit.
create function public.dopmi_remove_draft_expense(record_id uuid,expected_version integer) returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); r public.dopmi_rescue_records;
begin
  select * into r from public.dopmi_rescue_records where id=$1 for update;
  if not found or r.owner_id<>actor or r.kind<>'expense' then raise exception 'Gasto no disponible' using errcode='42501'; end if;
  if expected_version is distinct from r.version then raise exception 'El gasto cambió. Vuelve a cargarlo.' using errcode='40001'; end if;
  if r.status<>'draft' or r.submitted_at is not null or r.approved_at is not null or r.approved_snapshot is not null or r.reimbursable_cents<>0
    or exists(select 1 from private.dopmi_rescue_history h where h.record_id=r.id and h.action not in('create','save')) then
    raise exception 'Sólo puedes eliminar un gasto en borrador sin revisión' using errcode='22023'; end if;
  delete from public.dopmi_rescue_records where id=r.id;
end;
$$;
revoke all on function public.dopmi_remove_draft_expense(uuid,integer) from public,anon;
grant execute on function public.dopmi_remove_draft_expense(uuid,integer) to authenticated;

commit;
