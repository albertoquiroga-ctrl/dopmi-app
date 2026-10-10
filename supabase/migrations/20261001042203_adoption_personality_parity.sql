begin;

-- Keep existing traits unchanged. Authored changes return the entire post to
-- draft through the existing owner/version checks and require staff approval.
alter table public.dopmi_adoptions drop constraint dopmi_adoptions_personality;
alter table public.dopmi_adoptions add constraint dopmi_adoptions_personality
  check (cardinality(personality)<=18 and personality <@ array['affectionate','playful','calm','active','sociable','independent','alegre','feliz','esperanzado','emocionado','triste','enojado','ansioso','tranquilo','contento','satisfecho','solo','nervioso']::text[]);

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
    if cardinality(requested_traits)>18 or not requested_traits <@ array['affectionate','playful','calm','active','sociable','independent','alegre','feliz','esperanzado','emocionado','triste','enojado','ansioso','tranquilo','contento','satisfecho','solo','nervioso']::text[] then
      raise exception 'Personalidad inválida' using errcode='22023';
    end if;
  end if;
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
    if cardinality(requested_traits) > 18
      or not requested_traits <@ array['affectionate','playful','calm','active','sociable','independent','alegre','feliz','esperanzado','emocionado','triste','enojado','ansioso','tranquilo','contento','satisfecho','solo','nervioso']::text[] then
      raise exception 'Personalidad inválida' using errcode = '22023';
    end if;
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


commit;
