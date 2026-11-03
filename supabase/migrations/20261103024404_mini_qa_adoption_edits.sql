begin;

-- The public row remains the last approved adoption. Proposed fields, location
-- and photo paths stay in an unexposed typed mirror until the complete edit is
-- reviewed. No historical row, consent, media or financial state is backfilled.
create table private.dopmi_adoption_edits
  (like public.dopmi_adoptions including defaults including constraints);
alter table private.dopmi_adoption_edits
  add primary key(id),
  add foreign key(id) references public.dopmi_adoptions(id) on delete cascade,
  add foreign key(owner_id) references auth.users(id) on delete cascade,
  add foreign key(rescue_case_id) references public.dopmi_rescue_records(id) on delete set null,
  add constraint dopmi_adoption_edits_state
    check(status in ('draft','submitted','changes_requested','rejected'));
alter table private.dopmi_adoption_edits enable row level security;
revoke all on private.dopmi_adoption_edits from public,anon,authenticated,service_role;

-- Profiles and anonymized public posts deliberately survive Auth deletion.
-- Unsubmitted product drafts do not: finalize purges them when the durable
-- profile reaches deleted, and the Auth FK also covers direct Auth removal.
-- Existing payment/moderation evidence and finalization code stay untouched.
create function private.dopmi_cleanup_adoption_edits_on_account_delete() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  delete from private.dopmi_adoption_edits where owner_id=new.id;
  return new;
end;
$$;
revoke all on function private.dopmi_cleanup_adoption_edits_on_account_delete()
  from public,anon,authenticated,service_role;
create trigger dopmi_cleanup_adoption_edits_on_account_delete
  after update of account_status on public.profiles for each row
  when(new.account_status='deleted' and old.account_status is distinct from new.account_status)
  execute function private.dopmi_cleanup_adoption_edits_on_account_delete();

create function private.dopmi_adoption_owner_row(a public.dopmi_adoptions) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare e private.dopmi_adoption_edits;
begin
  select * into e from private.dopmi_adoption_edits where id=a.id;
  if not found then return to_jsonb(a)||jsonb_build_object('_has_private_draft',false); end if;
  return to_jsonb(e)||jsonb_build_object(
    'version',a.version,
    'status',case when e.status='draft' and a.status='published' then 'published' else e.status end,
    '_has_private_draft',true);
end;
$$;

create function public.dopmi_adoption_own(post_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); a public.dopmi_adoptions;
begin
  select * into a from public.dopmi_adoptions where id=post_id and owner_id=actor;
  if not found then return null; end if;
  return private.dopmi_adoption_owner_row(a);
end;
$$;

create function public.dopmi_adoption_mine(page_number integer default 1,page_size integer default 12) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); result jsonb;
begin
  if page_number is null or page_number<1 or page_size is null or page_size not between 1 and 100 then
    raise exception 'Paginación inválida' using errcode='22023'; end if;
  select jsonb_build_object('total',(select count(*) from public.dopmi_adoptions where owner_id=actor),
    'items',coalesce((select jsonb_agg(private.dopmi_adoption_owner_row(a::public.dopmi_adoptions) order by a.updated_at desc,a.id)
      from (select * from public.dopmi_adoptions where owner_id=actor order by updated_at desc,id
        limit page_size offset (page_number::bigint-1)*page_size) a),'[]'::jsonb)) into result;
  return result;
end;
$$;

create function private.dopmi_adoption_validate(a public.dopmi_adoptions) returns void
language plpgsql stable security definer set search_path='' as $$
declare photo text;
begin
  if a.species is null or a.sex is null or a.size is null then
    raise exception 'Selecciona especie, sexo y tamaño antes de enviar.' using errcode='22023'; end if;
  if char_length(a.pet_name)<1 or char_length(a.city)<1 or char_length(a.region)<1
    or a.story !~ '[^[:space:]]' or char_length(a.publisher_name)<1 or cardinality(a.photos)<1 then
    raise exception 'Completa nombre, ubicación, historia, nombre público y al menos una foto.' using errcode='22023'; end if;
  foreach photo in array a.photos loop
    if photo is null or photo not like a.owner_id::text||'/'||a.id::text||'/%' or not exists(
      select 1 from storage.objects o where o.bucket_id='dopmi-adoption-photos' and o.name=photo) then
      raise exception 'Una foto no terminó de subir. Vuelve a adjuntarla.' using errcode='22023'; end if;
  end loop;
end;
$$;

create or replace function public.dopmi_save_adoption(payload jsonb,target_id uuid default null,expected_version integer default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); a public.dopmi_adoptions; original public.dopmi_adoptions;
  e private.dopmi_adoption_edits; editing boolean:=false; photo text; linked_case uuid; requested_traits text[]; coarse numeric[];
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
    raise exception 'Selecciona especie, sexo y tamaño válidos' using errcode='22023'; end if;
  if payload ? 'personality' then
    if jsonb_typeof(payload->'personality') is distinct from 'array' then raise exception 'Personalidad inválida' using errcode='22023'; end if;
    select coalesce(array_agg(value),'{}') into requested_traits from jsonb_array_elements_text(payload->'personality') value;
    if cardinality(requested_traits)>22 or not requested_traits <@ array['affectionate','playful','calm','active','sociable','independent','alegre','feliz','esperanzado','emocionado','triste','enojado','ansioso','tranquilo','contento','satisfecho','solo','nervioso','dormilon','protector','obediente','timido']::text[] then
      raise exception 'Personalidad inválida' using errcode='22023'; end if;
  end if;
  if payload ? 'coexistence' and (jsonb_typeof(payload->'coexistence') is distinct from 'array' or not array(select jsonb_array_elements_text(payload->'coexistence')) <@ array['children','pets','apartment','yard','first_time','experienced']::text[] or jsonb_array_length(payload->'coexistence')>6) then
    raise exception 'Convivencia inválida' using errcode='22023'; end if;
  if payload ? 'age_band' and nullif(payload->>'age_band','') is not null and payload->>'age_band' not in ('puppy','adult','senior') then
    raise exception 'Edad inválida' using errcode='22023'; end if;
  if payload ? 'rescue_case_id' and nullif(payload->>'rescue_case_id','') is not null then
    begin linked_case:=(payload->>'rescue_case_id')::uuid;
    exception when invalid_text_representation then raise exception 'Caso vinculado inválido' using errcode='22023'; end;
    if not exists(select 1 from public.dopmi_rescue_records r where r.id=linked_case and r.owner_id=actor and r.kind='case' and r.status='approved') then
      raise exception 'El caso aprobado no está disponible para vincular' using errcode='42501'; end if;
  end if;
  if target_id is null then
    insert into public.dopmi_adoptions(owner_id,rescue_case_id) values(actor,linked_case) returning * into original;
    a:=original;
  else
    select * into original from public.dopmi_adoptions where id=target_id for update;
    if not found or original.owner_id<>actor then raise exception 'Publicación no disponible' using errcode='42501'; end if;
    if expected_version is distinct from original.version then raise exception 'La publicación cambió. Vuelve a cargarla.' using errcode='40001'; end if;
    select * into e from private.dopmi_adoption_edits where id=target_id for update;
    editing:=found or original.status='published';
    if e.id is not null then a:=jsonb_populate_record(null::public.dopmi_adoptions,to_jsonb(e)); else a:=original; end if;
    if a.status='submitted' then raise exception 'Retira la solicitud de revisión antes de editar.' using errcode='22023'; end if;
    linked_case:=case when payload ? 'rescue_case_id' then linked_case else a.rescue_case_id end;
  end if;
  coarse:=private.dopmi_preserve_fine_pet_location(coarse,a.approximate_latitude,a.approximate_longitude,
    payload->'location_precision_version'='1'::jsonb);
  a:=jsonb_populate_record(a,jsonb_build_object(
    'rescue_case_id',linked_case,
    'age_band',case when payload ? 'age_band' then nullif(payload->>'age_band','') else a.age_band end,
    'coexistence',case when payload ? 'coexistence' then array(select distinct jsonb_array_elements_text(payload->'coexistence')) else a.coexistence end,
    'personality',case when payload ? 'personality' then requested_traits else a.personality end,
    'pet_name',btrim(coalesce(payload->>'pet_name','')),
    'species',case when payload ? 'species' then payload->>'species' else a.species end,
    'sex',case when payload ? 'sex' then payload->>'sex' else a.sex end,
    'age_months',coalesce((payload->>'age_months')::integer,0),
    'size',case when payload ? 'size' then payload->>'size' else a.size end,
    'breed',btrim(coalesce(payload->>'breed','')),'city',btrim(coalesce(payload->>'city','')),
    'region',btrim(coalesce(payload->>'region','')),'story',btrim(coalesce(payload->>'story','')),
    'special_care',btrim(coalesce(payload->>'special_care','')),
    'publisher_name',btrim(coalesce(payload->>'publisher_name','')),'publisher_bio',btrim(coalesce(payload->>'publisher_bio','')),
    'vaccinated',(payload->>'vaccinated')::boolean,'sterilized',(payload->>'sterilized')::boolean,
    'social_dogs',(payload->>'social_dogs')::boolean,'social_cats',(payload->>'social_cats')::boolean,'social_children',(payload->>'social_children')::boolean,
    'photos',coalesce(array(select jsonb_array_elements_text(payload->'photos')),'{}'::text[]),
    'approximate_latitude',case when coarse is null then a.approximate_latitude else coarse[1] end,
    'approximate_longitude',case when coarse is null then a.approximate_longitude else coarse[2] end,
    'status','draft','submitted_at',null,'version',case when target_id is null then 1 else original.version+1 end,'updated_at',now()));
  foreach photo in array a.photos loop
    if photo is null or photo not like actor::text||'/'||a.id::text||'/%' then
      raise exception 'La foto no pertenece a esta publicación' using errcode='22023'; end if;
  end loop;
  if editing then
    insert into private.dopmi_adoption_edits select (a).* on conflict(id) do update set
      (pet_name,species,sex,age_months,size,breed,city,region,story,vaccinated,sterilized,social_dogs,social_cats,social_children,
       special_care,publisher_name,publisher_bio,photos,status,review_feedback,version,updated_at,submitted_at,published_at,
       personality,approximate_latitude,approximate_longitude,rescue_case_id,age_band,coexistence)=
      (excluded.pet_name,excluded.species,excluded.sex,excluded.age_months,excluded.size,excluded.breed,excluded.city,excluded.region,
       excluded.story,excluded.vaccinated,excluded.sterilized,excluded.social_dogs,excluded.social_cats,excluded.social_children,
       excluded.special_care,excluded.publisher_name,excluded.publisher_bio,excluded.photos,excluded.status,excluded.review_feedback,
       excluded.version,excluded.updated_at,excluded.submitted_at,excluded.published_at,excluded.personality,
       excluded.approximate_latitude,excluded.approximate_longitude,excluded.rescue_case_id,excluded.age_band,excluded.coexistence);
    update public.dopmi_adoptions set version=a.version,updated_at=a.updated_at where id=a.id returning * into original;
    return private.dopmi_adoption_owner_row(original);
  end if;
  update public.dopmi_adoptions set
    (pet_name,species,sex,age_months,size,breed,city,region,story,vaccinated,sterilized,social_dogs,social_cats,social_children,
     special_care,publisher_name,publisher_bio,photos,status,version,updated_at,submitted_at,personality,
     approximate_latitude,approximate_longitude,rescue_case_id,age_band,coexistence)=
    (a.pet_name,a.species,a.sex,a.age_months,a.size,a.breed,a.city,a.region,a.story,a.vaccinated,a.sterilized,a.social_dogs,
     a.social_cats,a.social_children,a.special_care,a.publisher_name,a.publisher_bio,a.photos,a.status,a.version,a.updated_at,
     a.submitted_at,a.personality,a.approximate_latitude,a.approximate_longitude,a.rescue_case_id,a.age_band,a.coexistence)
    where id=a.id returning * into original;
  return private.dopmi_adoption_owner_row(original);
exception when unique_violation then
  raise exception 'Este caso ya tiene una publicación de adopción vinculada' using errcode='23505';
end;
$$;

create or replace function public.dopmi_transition_adoption(post_id uuid,expected_version integer,action text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); a public.dopmi_adoptions; e private.dopmi_adoption_edits; proposal public.dopmi_adoptions; next_status text;
begin
  select * into a from public.dopmi_adoptions where id=post_id for update;
  if not found or a.owner_id<>actor then raise exception 'Publicación no disponible' using errcode='42501'; end if;
  if expected_version is distinct from a.version then raise exception 'La publicación cambió. Vuelve a cargarla.' using errcode='40001'; end if;
  select * into e from private.dopmi_adoption_edits where id=post_id for update;
  if found and action in ('submit','withdraw') then
    if action='submit' and e.status in ('draft','changes_requested','rejected') then
      proposal:=jsonb_populate_record(null::public.dopmi_adoptions,to_jsonb(e));
      perform private.dopmi_adoption_validate(proposal); next_status:='submitted';
    elsif action='withdraw' and e.status='submitted' then next_status:='draft';
    else raise exception 'Esta transición no está disponible' using errcode='22023'; end if;
    update private.dopmi_adoption_edits set status=next_status,version=a.version+1,updated_at=now(),
      submitted_at=case when next_status='submitted' then now() else null end where id=post_id;
    update public.dopmi_adoptions set version=version+1,updated_at=now() where id=post_id returning * into a;
    return private.dopmi_adoption_owner_row(a);
  end if;
  if action='submit' and a.status in ('draft','changes_requested') then
    perform private.dopmi_adoption_validate(a); next_status:='submitted';
  elsif action='withdraw' and a.status='submitted' then next_status:='draft';
  elsif action='adopted' and a.status='published' then next_status:='adopted';
  elsif action='archive' and a.status<>'archived' then next_status:='archived';
  else raise exception 'Esta transición no está disponible' using errcode='22023'; end if;
  if next_status in ('adopted','archived') then delete from private.dopmi_adoption_edits where id=post_id; end if;
  update public.dopmi_adoptions set status=next_status,version=version+1,updated_at=now(),
    submitted_at=case when next_status='submitted' then now() else submitted_at end where id=post_id returning * into a;
  return private.dopmi_adoption_owner_row(a);
end;
$$;

create or replace function public.dopmi_review_adoption(post_id uuid,expected_version integer,decision text,feedback text default '') returns jsonb
language plpgsql security definer set search_path='' as $$
declare a public.dopmi_adoptions; e private.dopmi_adoption_edits; proposal public.dopmi_adoptions; review_id uuid; next_status text;
begin
  if not public.dopmi_is_admin() then raise exception 'Acceso administrativo requerido' using errcode='42501'; end if;
  select * into a from public.dopmi_adoptions where id=post_id for update;
  if not found then raise exception 'Publicación no disponible' using errcode='22023'; end if;
  if expected_version is distinct from a.version then raise exception 'La publicación cambió. Vuelve a cargarla.' using errcode='40001'; end if;
  if feedback is null or char_length(feedback)>2000 or (decision<>'published' and char_length(btrim(feedback))<5) then
    raise exception 'Escribe el motivo de la decisión (5 a 2000 caracteres).' using errcode='22023'; end if;
  if not exists(select 1 from public.profiles where id=a.owner_id and account_status='active') then
    raise exception 'La cuenta responsable no está activa' using errcode='42501'; end if;
  select * into e from private.dopmi_adoption_edits where id=post_id for update;
  if decision='archived' and a.status in ('published','adopted') then
    next_status:='archived';
    update public.dopmi_adoptions set status='archived',review_feedback=btrim(feedback),version=version+1,updated_at=now()
      where id=post_id returning * into a;
    if e.id is not null then
      update private.dopmi_adoption_edits set version=a.version,updated_at=now(),review_feedback=btrim(feedback),
        status=case when status='draft' then 'draft' else 'changes_requested' end where id=post_id;
    end if;
  elsif e.id is not null and e.status='submitted' and decision in ('published','changes_requested','rejected')
    and a.status in ('published','archived') then
    if a.owner_id=auth.uid() then raise exception 'Otra persona debe revisar tu publicación' using errcode='42501'; end if;
    next_status:=decision;
    if decision='published' then
      proposal:=jsonb_populate_record(null::public.dopmi_adoptions,to_jsonb(e));
      perform private.dopmi_adoption_validate(proposal);
      update public.dopmi_adoptions set
        (pet_name,species,sex,age_months,size,breed,city,region,story,vaccinated,sterilized,social_dogs,social_cats,social_children,
         special_care,publisher_name,publisher_bio,photos,personality,approximate_latitude,approximate_longitude,rescue_case_id,age_band,coexistence)=
        (e.pet_name,e.species,e.sex,e.age_months,e.size,e.breed,e.city,e.region,e.story,e.vaccinated,e.sterilized,e.social_dogs,
         e.social_cats,e.social_children,e.special_care,e.publisher_name,e.publisher_bio,e.photos,e.personality,
         e.approximate_latitude,e.approximate_longitude,e.rescue_case_id,e.age_band,e.coexistence),
        status='published',review_feedback=btrim(feedback),version=version+1,updated_at=now()
        where id=post_id returning * into a;
      delete from private.dopmi_adoption_edits where id=post_id;
    else
      update public.dopmi_adoptions set version=version+1,updated_at=now() where id=post_id returning * into a;
      update private.dopmi_adoption_edits set status=decision,review_feedback=btrim(feedback),version=a.version,updated_at=now() where id=post_id;
    end if;
  elsif e.id is null and a.status='submitted' and decision in ('published','changes_requested','rejected') then
    next_status:=decision;
    if decision='published' then perform private.dopmi_adoption_validate(a); end if;
    update public.dopmi_adoptions set status=next_status,review_feedback=btrim(feedback),version=version+1,updated_at=now(),
      published_at=case when next_status='published' then now() else published_at end where id=post_id returning * into a;
  else raise exception 'Esta decisión no está disponible' using errcode='22023'; end if;
  insert into private.dopmi_adoption_reviews(post_id,actor_id,decision,feedback,version)
    values(post_id,auth.uid(),next_status,btrim(feedback),a.version) returning id into review_id;
  insert into private.admin_access_log(actor_id,action) values(auth.uid(),'adoptions.review');
  insert into public.dopmi_notifications(user_id,kind,post_id,source_id,title)
    values(a.owner_id,'review',a.id,review_id,case next_status when 'published' then 'Tu publicación fue aprobada'
      when 'changes_requested' then 'Hay correcciones para tu publicación' when 'rejected' then 'Tu publicación no fue aprobada'
      else 'Tu publicación fue retirada' end);
  return private.dopmi_adoption_owner_row(a);
end;
$$;

create or replace function public.dopmi_admin_adoptions(status_filter text default 'submitted',page_number integer default 1) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
  if not public.dopmi_is_admin() then raise exception 'Acceso administrativo requerido' using errcode='42501'; end if;
  if page_number is null or page_number<1 then raise exception 'Página inválida' using errcode='22023'; end if;
  with visible as (
    select case when e.status in ('submitted','changes_requested','rejected') then
      to_jsonb(e)||jsonb_build_object('version',a.version,'_has_private_draft',true)
      else to_jsonb(a)||jsonb_build_object('_has_private_draft',false) end item
    from public.dopmi_adoptions a left join private.dopmi_adoption_edits e on e.id=a.id
  ), selected as (select item from visible where status_filter='' or item->>'status'=status_filter)
  select jsonb_build_object('total',(select count(*) from selected),
    'items',coalesce((select jsonb_agg(item order by (item->>'submitted_at')::timestamptz nulls last,
      (item->>'created_at')::timestamptz,item->>'id') from (select item from selected
      order by (item->>'submitted_at')::timestamptz nulls last,(item->>'created_at')::timestamptz,item->>'id'
      limit 20 offset (page_number::bigint-1)*20) page),'[]'::jsonb)) into result;
  insert into private.admin_access_log(actor_id,action) values(auth.uid(),'adoptions.list');
  return result;
end;
$$;

create or replace function public.dopmi_can_read_photo(object_name text) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.dopmi_adoptions a join public.profiles p on p.id=a.owner_id
    left join private.dopmi_adoption_edits e on e.id=a.id
    where split_part(object_name,'/',1)=a.owner_id::text and split_part(object_name,'/',2)=a.id::text
      and ((public.dopmi_actor_active() and a.owner_id=auth.uid())
        or (public.dopmi_is_admin() and (object_name=any(a.photos)
          or (e.status in ('submitted','changes_requested','rejected') and object_name=any(e.photos))))
        or (a.status in ('published','adopted') and p.account_status='active' and object_name=any(a.photos))));
$$;

create or replace function public.dopmi_can_write_photo(object_name text) returns boolean
language plpgsql security definer set search_path='' as $$
declare a public.dopmi_adoptions; e private.dopmi_adoption_edits;
begin
  if not public.dopmi_actor_active() or object_name !~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|png|webp)$' then return false; end if;
  select * into a from public.dopmi_adoptions where id::text=split_part(object_name,'/',2) for update;
  if not found or a.owner_id<>auth.uid() or a.owner_id::text<>split_part(object_name,'/',1) then return false; end if;
  select * into e from private.dopmi_adoption_edits where id=a.id;
  if e.id is not null then
    return e.status in ('draft','changes_requested','rejected') and not object_name=any(a.photos);
  end if;
  return a.status in ('draft','changes_requested','rejected','archived');
end;
$$;

-- Preserve all existing function identities and grants. Only new APIs have an
-- explicit authenticated grant; internal helpers and the mirror have none.
revoke all on function private.dopmi_adoption_owner_row(public.dopmi_adoptions),
  private.dopmi_adoption_validate(public.dopmi_adoptions) from public,anon,authenticated,service_role;
revoke all on function public.dopmi_adoption_own(uuid),public.dopmi_adoption_mine(integer,integer)
  from public,anon,authenticated,service_role;
grant execute on function public.dopmi_adoption_own(uuid),public.dopmi_adoption_mine(integer,integer) to authenticated;

-- Story alone accepts one nonblank character for support cases. Verification,
-- paid expense validation, evidence and every other field retain their rules.
do $$
declare source text:=pg_get_functiondef('private.dopmi_rescue_validate(public.dopmi_rescue_records)'::regprocedure);
  previous text:=$before$if coalesce(char_length(btrim(r.public_data->>field)),0)<2 then$before$;
  replacement text:=$after$if (r.kind='case' and field='story' and coalesce(r.public_data->>field,'') !~ '[^[:space:]]')
      or (not (r.kind='case' and field='story') and coalesce(char_length(btrim(r.public_data->>field)),0)<2) then$after$;
begin
  if strpos(source,previous)=0 or strpos(substr(source,strpos(source,previous)+char_length(previous)),previous)>0 then
    raise exception 'La validación de historia cambió; revisar el delta antes de aplicar' using errcode='55000'; end if;
  execute replace(source,previous,replacement);
end;
$$;

commit;
