begin;

alter table public.dopmi_adoptions
  add column personality text[] not null default '{}',
  add column approximate_latitude numeric(4,2),
  add column approximate_longitude numeric(5,2),
  add constraint dopmi_adoptions_personality check (
    cardinality(personality) <= 6
    and personality <@ array['affectionate','playful','calm','active','sociable','independent']::text[]
  ),
  add constraint dopmi_adoptions_approximate_location check (
    (approximate_latitude is null and approximate_longitude is null)
    or (
      approximate_latitude between -90 and 90
      and approximate_longitude between -180 and 180
    )
  );

-- Discovery exposes the traits approved with the publication and a distance
-- calculated from coordinates rounded to roughly one kilometre. It never
-- returns either coordinate.
create function public.dopmi_discovery(
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
    if cardinality(requested_traits) > 6
      or not requested_traits <@ array['affectionate','playful','calm','active','sociable','independent']::text[] then
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
