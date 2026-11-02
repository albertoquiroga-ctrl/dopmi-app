begin;

-- Coordinates remain private. Widening the types preserves historical coarse
-- values; it cannot reconstruct a more accurate position for existing records.
-- location_precision_version: 1 is a wire contract, not a claim of GPS accuracy.
alter table public.dopmi_adoptions
  alter column approximate_latitude type numeric using approximate_latitude::numeric,
  alter column approximate_longitude type numeric using approximate_longitude::numeric;
alter table public.dopmi_rescue_records
  alter column approximate_latitude type numeric using approximate_latitude::numeric,
  alter column approximate_longitude type numeric using approximate_longitude::numeric;

-- Retain the established helper signature and ACL. Unversioned clients still
-- round new selections; version 1 preserves the original numeric coordinates.
create or replace function private.dopmi_coarse_pet_location(data jsonb) returns numeric[]
language plpgsql immutable set search_path='' as $$
declare latitude numeric; longitude numeric;
begin
  if jsonb_typeof(data) is distinct from 'object' then
    raise exception 'Ubicación aproximada inválida' using errcode='22023';
  end if;
  if data ? 'location_precision_version' and
      data->'location_precision_version' is distinct from '1'::jsonb then
    raise exception 'Versión de ubicación inválida. Actualiza Dopmi.' using errcode='22023';
  end if;
  if not data ?| array['approximate_latitude','approximate_longitude'] then return null; end if;
  if not data ?& array['approximate_latitude','approximate_longitude'] then
    raise exception 'Selecciona una ubicación completa' using errcode='22023';
  end if;
  if jsonb_typeof(data->'approximate_latitude')='null' and jsonb_typeof(data->'approximate_longitude')='null' then
    return array[null::numeric,null::numeric];
  end if;
  if jsonb_typeof(data->'approximate_latitude') is distinct from 'number' or
     jsonb_typeof(data->'approximate_longitude') is distinct from 'number' then
    raise exception 'Selecciona coordenadas numéricas válidas' using errcode='22023';
  end if;
  latitude:=(data->>'approximate_latitude')::numeric;
  longitude:=(data->>'approximate_longitude')::numeric;
  if latitude not between -90 and 90 or longitude not between -180 and 180 then
    raise exception 'Ubicación fuera de rango' using errcode='22023';
  end if;
  if data->'location_precision_version'='1'::jsonb then
    return array[latitude,longitude];
  end if;
  return array[round(latitude,2),round(longitude,2)];
end;
$$;
revoke all on function private.dopmi_coarse_pet_location(jsonb) from public,anon,authenticated,service_role;

create function private.dopmi_preserve_fine_pet_location(
  incoming numeric[], stored_lat numeric, stored_lon numeric, precise_contract boolean
) returns numeric[] language plpgsql immutable set search_path='' as $$
begin
  if incoming is null or precise_contract is true then return incoming; end if;
  if stored_lat is null or stored_lon is null or
      (stored_lat=round(stored_lat,2) and stored_lon=round(stored_lon,2)) then
    return incoming;
  end if;
  -- Older clients round an existing point when reopening the editor. Saving
  -- other fields with that same coarse pair must preserve the stored fine pair.
  if incoming[1]=round(stored_lat,2) and incoming[2]=round(stored_lon,2) then
    return array[stored_lat,stored_lon];
  end if;
  raise exception 'Actualiza Dopmi para cambiar esta ubicación sin perder precisión.' using errcode='22023';
end;
$$;
revoke all on function private.dopmi_preserve_fine_pet_location(numeric[],numeric,numeric,boolean)
  from public,anon,authenticated,service_role;

create or replace function public.dopmi_save_adoption(payload jsonb,target_id uuid default null,expected_version integer default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); a public.dopmi_adoptions; photo text; linked_case uuid; requested_traits text[]; coarse numeric[];
begin
  if jsonb_typeof(payload) is distinct from 'object' or char_length(payload::text)>16000 then
    raise exception 'Publicación inválida' using errcode='22023'; end if;
  coarse:=private.dopmi_coarse_pet_location(payload);
  if (payload ? 'species' and jsonb_typeof(payload->'species')<>'null' and
        (jsonb_typeof(payload->'species')<>'string' or payload->>'species' not in ('dog','cat')))
    or (payload ? 'sex' and jsonb_typeof(payload->'sex')<>'null' and
        (jsonb_typeof(payload->'sex')<>'string' or payload->>'sex' not in ('female','male')))
    or (payload ? 'size' and jsonb_typeof(payload->'size')<>'null' and
        (jsonb_typeof(payload->'size')<>'string' or payload->>'size' not in ('small','medium','large'))) then
    raise exception 'Selecciona especie, sexo y tamaño válidos' using errcode='22023';
  end if;
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
  coarse:=private.dopmi_preserve_fine_pet_location(coarse,a.approximate_latitude,a.approximate_longitude,
    payload->'location_precision_version'='1'::jsonb);
  update public.dopmi_adoptions set
    rescue_case_id=linked_case,
    age_band=case when payload ? 'age_band' then nullif(payload->>'age_band','') else a.age_band end,
    coexistence=case when payload ? 'coexistence' then array(select distinct jsonb_array_elements_text(payload->'coexistence')) else a.coexistence end,
    personality=case when payload ? 'personality' then requested_traits else a.personality end,
    pet_name=btrim(coalesce(payload->>'pet_name','')), species=case when payload ? 'species' then payload->>'species' else a.species end,
    sex=case when payload ? 'sex' then payload->>'sex' else a.sex end, age_months=coalesce((payload->>'age_months')::integer,0),
    size=case when payload ? 'size' then payload->>'size' else a.size end, breed=btrim(coalesce(payload->>'breed','')),
    city=btrim(coalesce(payload->>'city','')),region=btrim(coalesce(payload->>'region','')),
    story=btrim(coalesce(payload->>'story','')), special_care=btrim(coalesce(payload->>'special_care','')),
    publisher_name=btrim(coalesce(payload->>'publisher_name','')),publisher_bio=btrim(coalesce(payload->>'publisher_bio','')),
    vaccinated=(payload->>'vaccinated')::boolean,sterilized=(payload->>'sterilized')::boolean,
    social_dogs=(payload->>'social_dogs')::boolean,social_cats=(payload->>'social_cats')::boolean,social_children=(payload->>'social_children')::boolean,
    photos=coalesce(array(select jsonb_array_elements_text(payload->'photos')),'{}'::text[]),
    approximate_latitude=case when coarse is null then a.approximate_latitude else coarse[1] end,
    approximate_longitude=case when coarse is null then a.approximate_longitude else coarse[2] end,
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

create or replace function public.dopmi_save_rescue(record_kind text, public_fields jsonb, private_fields jsonb, attachments jsonb,
  target_id uuid default null, expected_version integer default null, case_id uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid; r public.dopmi_rescue_records; c public.dopmi_rescue_records; pub text[]; priv text[]; roles text[]; coarse numeric[]; precise_contract boolean;
begin
  actor:=private.dopmi_require_actor(); perform private.dopmi_rescue_lock(actor);
  if record_kind is null or record_kind not in ('verification','case','expense') then raise exception 'Tipo inválido' using errcode='22023'; end if;
  coarse:=private.dopmi_coarse_pet_location(public_fields);
  precise_contract:=(public_fields->'location_precision_version'='1'::jsonb) is true;
  if (coarse is not null or public_fields ? 'location_precision_version') and record_kind<>'case' then
    raise exception 'La ubicación de mascota sólo corresponde a un caso' using errcode='22023';
  end if;
  public_fields:=public_fields-'approximate_latitude'-'approximate_longitude'-'location_precision_version';
  if target_id is null then
    if record_kind='verification' and exists(select 1 from public.dopmi_rescue_records where owner_id=actor and kind='verification') then
      raise exception 'Ya tienes una verificación. Abre la solicitud existente' using errcode='40001'; end if;
    insert into public.dopmi_rescue_records(owner_id,kind,parent_id) values(actor,record_kind,case_id) returning * into r;
  else
    select * into r from public.dopmi_rescue_records where id=target_id for update;
    if not found or r.owner_id<>actor then raise exception 'Solicitud no disponible' using errcode='42501'; end if;
    if r.version is distinct from expected_version then raise exception 'La solicitud cambió. Recarga antes de continuar' using errcode='40001'; end if;
    if r.kind<>record_kind or r.parent_id is distinct from case_id or r.status not in ('draft','changes_requested','rejected') then
      raise exception 'Esta solicitud no se puede editar en su estado actual' using errcode='22023'; end if;
  end if;
  if record_kind='case' then
    coarse:=private.dopmi_preserve_fine_pet_location(coarse,r.approximate_latitude,r.approximate_longitude,precise_contract);
  end if;
  if r.kind='expense' then
    select * into c from public.dopmi_rescue_records where id=r.parent_id;
    if not found or c.kind<>'case' or c.owner_id<>actor or c.status='closed' then
      raise exception 'Selecciona uno de tus casos abiertos' using errcode='22023'; end if;
  end if;
  if record_kind='verification' then
    pub:=array['public_name','bio','city','state']; priv:=array['legal_name','phone','experience','social_url','identity_type']; roles:=array['identity','address'];
  elsif record_kind='case' then
    pub:=array['pet_name','species','sex','age','story','city','state','need']; priv:='{}'; roles:=array['public'];
  else
    pub:=array['title','description','category','round_label']; priv:=array['paid_on','vendor','amount_cents','receipt_reference','urgency_reason']; roles:=array['receipt','proof','public'];
  end if;
  if record_kind='case' then
    if not public_fields ? 'size' and r.public_data ? 'size' then
      public_fields:=public_fields||jsonb_build_object('size',r.public_data->>'size');
    end if;
    public_fields:=private.dopmi_case_fields(public_fields);
  else
    public_fields:=private.dopmi_rescue_fields(public_fields,pub);
  end if;
  private_fields:=private.dopmi_rescue_fields(private_fields,priv);
  if jsonb_typeof(attachments) is distinct from 'array' or jsonb_array_length(attachments)>12
    or exists(select 1 from jsonb_array_elements(attachments) f where jsonb_typeof(f)<>'object'
      or (f-'path'-'role')<>'{}'::jsonb or not coalesce(f->>'role','')=any(roles)
      or coalesce(f->>'path','') !~ ('^'||actor::text||'/'||r.id::text||'/[0-9a-f-]{36}\.(jpg|png|webp|pdf)$')
      or (f->>'role'='public' and f->>'path' !~ '\.(jpg|png|webp)$'))
    or (select count(*) from jsonb_array_elements(attachments))<>(select count(distinct f->>'path') from jsonb_array_elements(attachments) f) then
    raise exception 'Archivos o permisos de publicación inválidos' using errcode='22023'; end if;
  update public.dopmi_rescue_records set public_data=public_fields,private_data=private_fields,files=attachments,
    approximate_latitude=case when coarse is null then r.approximate_latitude else coarse[1] end,
    approximate_longitude=case when coarse is null then r.approximate_longitude else coarse[2] end,
    version=version+1,updated_at=now(),status='draft' where id=r.id returning * into r;
  return to_jsonb(r);
end;
$$;

-- The same unrounded distance drives filtering, ordering and the total. Public
-- DTOs keep omitting coordinates; the existing distance label remains rounded.
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
        (6371 * acos(least(1, greatest(-1,
          cos(radians(origin_lat::double precision))
          * cos(radians(a.approximate_latitude::double precision))
          * cos(radians(a.approximate_longitude::double precision) - radians(origin_lon::double precision))
          + sin(radians(origin_lat::double precision))
          * sin(radians(a.approximate_latitude::double precision))
        ))))::numeric
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
    order by distance_km asc nulls last, published_at desc, id
    limit page_size offset (page_number::bigint - 1) * page_size
  )
  select jsonb_build_object(
    'total', (select count(*) from matches),
    'items', coalesce((select jsonb_agg(
      private.dopmi_public_post(page.post)
      || jsonb_build_object(
        'personality', page.personality,
        'distance_km', round(page.distance_km,1),
        'saved', exists(
          select 1 from public.dopmi_favorites f
          where f.post_id = page.id and f.user_id = actor and public.dopmi_actor_active()
        )
      ) order by page.distance_km asc nulls last, page.published_at desc, page.id
    ) from page), '[]'::jsonb)
  ) into result;
  return result;
end;
$$;

-- Accept the matching production disclosure without replacing historical
-- consent evidence or changing terms, TEST versions, ownership or service flags.
create or replace function private.dopmi_general_legal_pair_allowed(terms text,privacy text) returns boolean
language sql stable set search_path='' as $$
  select exists(select 1 from private.dopmi_payment_environment e where e.singleton and (
    (e.environment='production' and terms='terms-live-2026-11-01' and privacy in ('privacy-live-2026-11-01','privacy-live-2026-11-01-ubicacion','privacy-live-2026-11-01-ubicacion-precisa')) or
    (e.environment='test' and terms='terms-2026-11-01' and privacy in ('privacy-2026-11-01','privacy-2026-11-01-ubicacion'))));
$$;
create or replace function public.dopmi_accept_legal(
  accepted_terms text,accepted_privacy text,confirms_adult boolean
) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
  actor uuid:=auth.uid();
  subject public.profiles;
  accepted timestamptz;
begin
  if actor is null or confirms_adult is distinct from true or
    not private.dopmi_legal_pair_allowed(accepted_terms,accepted_privacy) then
    raise exception 'Aceptación legal inválida' using errcode='22023';
  end if;
  -- Preserve the existing serialization and immutable per-pair evidence.
  select * into subject from public.profiles where id=actor for update;
  if not found or subject.account_status<>'active' then
    raise exception 'Cuenta no disponible' using errcode='42501';
  end if;
  -- Legacy clients remain supported until this actor explicitly accepts the
  -- Maps disclosure. Immutable evidence also protects a repaired projection.
  if subject.privacy_version in ('privacy-live-2026-11-01-ubicacion','privacy-2026-11-01-ubicacion','privacy-live-2026-11-01-ubicacion-precisa')
    or exists(select 1 from private.dopmi_consents c where c.owner_id=actor
      and c.privacy_version in ('privacy-live-2026-11-01-ubicacion','privacy-2026-11-01-ubicacion','privacy-live-2026-11-01-ubicacion-precisa')) then
    raise exception 'Actualiza Dopmi para conservar el aviso de privacidad vigente' using errcode='22023';
  end if;
  -- Even an owner changing configuration back to TEST cannot make a client
  -- overwrite LIVE acceptance. Existing LIVE evidence is never relabeled TEST.
  if (accepted_terms<>'terms-live-2026-10-28' and (
      subject.terms_version='terms-live-2026-10-28' or subject.privacy_version='privacy-live-2026-10-28' or
      exists(select 1 from private.dopmi_consents c where c.owner_id=actor and
        (c.terms_version='terms-live-2026-10-28' or c.privacy_version='privacy-live-2026-10-28')))) or
    (accepted_terms='terms-2026-09-28' and
      (subject.terms_version='terms-2026-10-17' or subject.privacy_version='privacy-2026-10-17')) then
    raise exception 'La cuenta ya aceptó una versión más reciente' using errcode='22023';
  end if;
  insert into private.dopmi_consents(owner_id,terms_version,privacy_version,adult_confirmed)
    values(actor,accepted_terms,accepted_privacy,true)
    on conflict(owner_id,terms_version,privacy_version) do nothing;
  select accepted_at into accepted from private.dopmi_consents
    where owner_id=actor and terms_version=accepted_terms and privacy_version=accepted_privacy;
  update public.profiles set terms_version=accepted_terms,terms_accepted_at=accepted,
    privacy_version=accepted_privacy,privacy_accepted_at=accepted,
    adult_confirmed_at=coalesce(subject.adult_confirmed_at,accepted)
    where id=actor and (terms_version is distinct from accepted_terms
      or privacy_version is distinct from accepted_privacy
      or terms_accepted_at is distinct from accepted
      or privacy_accepted_at is distinct from accepted or adult_confirmed_at is null);
  return jsonb_build_object('terms_version',accepted_terms,'privacy_version',accepted_privacy,
    'adult_confirmed',true,'accepted_at',accepted);
end $$;
revoke all on function public.dopmi_accept_legal(text,text,boolean) from public,anon,authenticated,service_role;
grant execute on function public.dopmi_accept_legal(text,text,boolean) to authenticated;

create or replace function public.accept_current_legal(accepted_terms text,accepted_privacy text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
  actor uuid:=auth.uid();
  subject public.profiles;
  accepted timestamptz;
begin
  if actor is null or not private.dopmi_general_legal_pair_allowed(accepted_terms,accepted_privacy) then
    raise exception 'Aceptación legal inválida' using errcode='22023';
  end if;
  select * into subject from public.profiles where id=actor for update;
  if not found or subject.account_status<>'active' or not exists(
    select 1 from auth.users u where u.id=actor and u.email_confirmed_at is not null
  ) then
    raise exception 'Cuenta activa y confirmada requerida' using errcode='42501';
  end if;
  -- A precise-location acceptance supersedes previous notices for this actor.
  -- The immutable proof also protects a repaired or stale profile projection.
  if (subject.privacy_version='privacy-live-2026-11-01-ubicacion-precisa'
    or exists(select 1 from private.dopmi_consents c where c.owner_id=actor
      and c.privacy_version='privacy-live-2026-11-01-ubicacion-precisa'))
      and accepted_privacy is distinct from 'privacy-live-2026-11-01-ubicacion-precisa' then
    raise exception 'Actualiza Dopmi para conservar el aviso de privacidad vigente' using errcode='22023';
  end if;
  if (subject.privacy_version in ('privacy-live-2026-11-01-ubicacion','privacy-2026-11-01-ubicacion','privacy-live-2026-11-01-ubicacion-precisa')
    or exists(select 1 from private.dopmi_consents c where c.owner_id=actor
      and c.privacy_version in ('privacy-live-2026-11-01-ubicacion','privacy-2026-11-01-ubicacion','privacy-live-2026-11-01-ubicacion-precisa')))
     and accepted_privacy not in ('privacy-live-2026-11-01-ubicacion','privacy-2026-11-01-ubicacion','privacy-live-2026-11-01-ubicacion-precisa') then
    raise exception 'Actualiza Dopmi para conservar el aviso de privacidad vigente' using errcode='22023';
  end if;
  -- A configuration rollback must not relabel accepted production evidence TEST.
  if accepted_terms='terms-2026-11-01' and (
    subject.terms_version in ('terms-live-2026-10-28','terms-live-2026-11-01') or
    subject.privacy_version in ('privacy-live-2026-10-28','privacy-live-2026-11-01') or
    exists(select 1 from private.dopmi_consents c where c.owner_id=actor and (
      c.terms_version in ('terms-live-2026-10-28','terms-live-2026-11-01') or
      c.privacy_version in ('privacy-live-2026-10-28','privacy-live-2026-11-01')))
  ) then
    raise exception 'La cuenta ya aceptó una versión más reciente' using errcode='22023';
  end if;
  insert into private.dopmi_consents(owner_id,terms_version,privacy_version,adult_confirmed)
    values(actor,accepted_terms,accepted_privacy,false)
    on conflict(owner_id,terms_version,privacy_version) do nothing;
  select c.accepted_at into accepted from private.dopmi_consents c
    where c.owner_id=actor and c.terms_version=accepted_terms and c.privacy_version=accepted_privacy
      and not c.adult_confirmed;
  if accepted is null then
    raise exception 'Evidencia de aceptación legal inválida' using errcode='42501';
  end if;
  update public.profiles set terms_version=accepted_terms,terms_accepted_at=accepted,
    privacy_version=accepted_privacy,privacy_accepted_at=accepted
    where id=actor and (terms_version is distinct from accepted_terms
      or privacy_version is distinct from accepted_privacy
      or terms_accepted_at is distinct from accepted or privacy_accepted_at is distinct from accepted);
  return jsonb_build_object('terms_version',accepted_terms,'privacy_version',accepted_privacy,
    'terms_accepted',true,'privacy_accepted',true,'adult_confirmed',false,'accepted_at',accepted);
end $$;
create or replace function private.dopmi_require_current_legal(target_actor uuid) returns void
language plpgsql stable security definer set search_path='' as $$
declare environment text;
begin
  select e.environment into environment from private.dopmi_payment_environment e where e.singleton;
  if environment='test' then return; end if;
  if environment is distinct from 'production' or target_actor is null or not exists(
    select 1 from public.profiles p join auth.users u on u.id=p.id
    join private.dopmi_consents c on c.owner_id=p.id
    where p.id=target_actor and p.account_status='active' and u.email_confirmed_at is not null
      and p.terms_accepted_at is not null and p.privacy_accepted_at is not null
      and c.terms_version=p.terms_version and c.privacy_version=p.privacy_version
      and c.accepted_at=p.terms_accepted_at and c.accepted_at=p.privacy_accepted_at
      and (
        (p.terms_version='terms-live-2026-10-28' and p.privacy_version='privacy-live-2026-10-28'
          and p.adult_confirmed_at is not null and c.adult_confirmed) or
        (p.terms_version='terms-live-2026-11-01' and p.privacy_version in ('privacy-live-2026-11-01','privacy-live-2026-11-01-ubicacion','privacy-live-2026-11-01-ubicacion-precisa')
          and not c.adult_confirmed)
      )
  ) then
    raise exception 'Acepta los términos y el aviso de privacidad vigentes' using errcode='42501';
  end if;
end $$;

-- Ownership, moderation, RLS, public projections, history and services are unchanged.
commit;
