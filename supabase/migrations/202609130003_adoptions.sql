begin;

create function public.dopmi_actor_active() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.profiles p join auth.users u on u.id=p.id
    where p.id=(select auth.uid()) and p.account_status='active' and u.email_confirmed_at is not null);
$$;
revoke all on function public.dopmi_actor_active() from public;
grant execute on function public.dopmi_actor_active() to anon, authenticated;

create function private.dopmi_require_actor() returns uuid
language plpgsql security definer set search_path = '' as $$
begin
  if not public.dopmi_actor_active() then raise exception 'Cuenta activa y confirmada requerida' using errcode='42501'; end if;
  if not exists(select 1 from public.profiles where id=auth.uid() and terms_accepted_at is not null) then
    raise exception 'Acepta el aviso de desarrollo desde tu perfil' using errcode='22023';
  end if;
  return auth.uid();
end;
$$;

create table public.dopmi_adoptions (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  pet_name text not null default '' check(char_length(pet_name)<=80),
  species text not null default 'dog' check(species in ('dog','cat')),
  sex text not null default 'female' check(sex in ('female','male')),
  age_months integer not null default 0 check(age_months between 0 and 360),
  size text not null default 'medium' check(size in ('small','medium','large')),
  breed text not null default '' check(char_length(breed)<=80),
  city text not null default '' check(char_length(city)<=100),
  region text not null default '' check(char_length(region)<=100),
  story text not null default '' check(char_length(story)<=4000),
  vaccinated boolean, sterilized boolean, social_dogs boolean, social_cats boolean, social_children boolean,
  special_care text not null default '' check(char_length(special_care)<=1000),
  publisher_name text not null default '' check(char_length(publisher_name)<=80),
  publisher_bio text not null default '' check(char_length(publisher_bio)<=1000),
  photos text[] not null default '{}' check(cardinality(photos)<=5),
  status text not null default 'draft' check(status in ('draft','submitted','changes_requested','published','rejected','adopted','archived')),
  review_feedback text not null default '',
  version integer not null default 1,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  submitted_at timestamptz, published_at timestamptz
);
create index dopmi_adoptions_catalog on public.dopmi_adoptions(published_at desc,id) where status='published';
create index dopmi_adoptions_owner on public.dopmi_adoptions(owner_id,updated_at desc);
create index dopmi_adoptions_review on public.dopmi_adoptions(status,submitted_at,id);

create table private.dopmi_adoption_reviews (
  id uuid primary key default gen_random_uuid(), post_id uuid not null references public.dopmi_adoptions(id) on delete cascade,
  actor_id uuid not null, decision text not null, feedback text not null, version integer not null,
  created_at timestamptz not null default now()
);
alter table private.dopmi_adoption_reviews enable row level security;
create table public.dopmi_favorites (
  user_id uuid not null references public.profiles(id) on delete cascade,
  post_id uuid not null references public.dopmi_adoptions(id) on delete cascade,
  created_at timestamptz not null default now(), primary key(user_id,post_id)
);
create table public.dopmi_notifications (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null check(kind in ('review','message')), post_id uuid references public.dopmi_adoptions(id) on delete cascade,
  thread_id uuid, source_id uuid not null, title text not null, created_at timestamptz not null default now(), read_at timestamptz,
  unique(user_id,kind,source_id)
);
create index dopmi_notifications_user on public.dopmi_notifications(user_id,created_at desc,id);
alter table public.dopmi_adoptions enable row level security;
alter table public.dopmi_favorites enable row level security;
alter table public.dopmi_notifications enable row level security;
revoke all on public.dopmi_adoptions, public.dopmi_favorites, public.dopmi_notifications from public,anon,authenticated;
grant select on public.dopmi_adoptions, public.dopmi_favorites, public.dopmi_notifications to authenticated;
create policy dopmi_adoptions_private on public.dopmi_adoptions for select to authenticated
  using ((public.dopmi_actor_active() and owner_id=(select auth.uid())) or public.dopmi_is_admin());
create policy dopmi_favorites_own on public.dopmi_favorites for select to authenticated
  using(public.dopmi_actor_active() and user_id=(select auth.uid()));
create policy dopmi_notifications_own on public.dopmi_notifications for select to authenticated
  using(public.dopmi_actor_active() and user_id=(select auth.uid()));

create function private.dopmi_public_post(p public.dopmi_adoptions) returns jsonb
language sql immutable set search_path='' as $$
  select jsonb_build_object('id',p.id,'owner_id',p.owner_id,'pet_name',p.pet_name,'species',p.species,'sex',p.sex,
    'age_months',p.age_months,'size',p.size,'breed',p.breed,'city',p.city,'region',p.region,'story',p.story,
    'vaccinated',p.vaccinated,'sterilized',p.sterilized,'social_dogs',p.social_dogs,'social_cats',p.social_cats,
    'social_children',p.social_children,'special_care',p.special_care,'publisher_name',p.publisher_name,
    'publisher_bio',p.publisher_bio,'photos',p.photos,'status',p.status,'published_at',p.published_at);
$$;

create function public.dopmi_catalog(filters jsonb default '{}', page_number integer default 1, page_size integer default 12)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb; actor uuid:=auth.uid();
begin
  if page_number is null or page_number<1 or page_size is null or page_size not between 1 and 30
    or jsonb_typeof(filters) is distinct from 'object' or char_length(filters::text)>1000 then
    raise exception 'Filtros o paginación inválidos' using errcode='22023';
  end if;
  with matches as (
    select a.* from public.dopmi_adoptions a join public.profiles p on p.id=a.owner_id
    where a.status='published' and p.account_status='active'
      and (coalesce(filters->>'species','')='' or a.species=filters->>'species')
      and (coalesce(filters->>'sex','')='' or a.sex=filters->>'sex')
      and (coalesce(filters->>'size','')='' or a.size=filters->>'size')
      and (coalesce(filters->>'city','')='' or strpos(lower(a.city),lower(filters->>'city'))>0)
      and (coalesce(filters->>'region','')='' or strpos(lower(a.region),lower(filters->>'region'))>0)
      and (coalesce(filters->>'query','')='' or strpos(lower(a.pet_name||' '||a.story),lower(filters->>'query'))>0)
      and (nullif(filters->>'min_age','') is null or a.age_months >= (filters->>'min_age')::integer)
      and (nullif(filters->>'max_age','') is null or a.age_months <= (filters->>'max_age')::integer)
      and (coalesce((filters->>'saved')::boolean,false)=false or (public.dopmi_actor_active() and exists(
        select 1 from public.dopmi_favorites f where f.post_id=a.id and f.user_id=actor)))
      and (nullif(filters->>'owner_id','') is null or a.owner_id=(filters->>'owner_id')::uuid)
  ), page as (select * from matches order by published_at desc,id limit page_size offset (page_number::bigint-1)*page_size)
  select jsonb_build_object('total',(select count(*) from matches),'items',coalesce((select jsonb_agg(
    private.dopmi_public_post(page::public.dopmi_adoptions) || jsonb_build_object('saved',exists(
      select 1 from public.dopmi_favorites f where f.post_id=page.id and f.user_id=actor and public.dopmi_actor_active()))
    order by page.published_at desc,page.id) from page),'[]'::jsonb)) into result;
  return result;
end;
$$;

create function public.dopmi_adoption_detail(post_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$
  select private.dopmi_public_post(a)||jsonb_build_object('saved',exists(
    select 1 from public.dopmi_favorites f where f.user_id=auth.uid() and f.post_id=a.id and public.dopmi_actor_active()))
  from public.dopmi_adoptions a join public.profiles p on p.id=a.owner_id
  where a.id=post_id and a.status='published' and p.account_status='active';
$$;

create function public.dopmi_public_profile(person_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$
  select jsonb_build_object('id',a.owner_id,'name',a.publisher_name,'bio',a.publisher_bio,'city',a.city,'region',a.region,
    'adopted_count',(select count(*) from public.dopmi_adoptions x where x.owner_id=person_id and x.status='adopted'))
  from public.dopmi_adoptions a join public.profiles p on p.id=a.owner_id
  where a.owner_id=person_id and a.status in ('published','adopted') and p.account_status='active'
  order by a.published_at desc,a.id limit 1;
$$;

create function public.dopmi_save_adoption(payload jsonb,target_id uuid default null,expected_version integer default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); a public.dopmi_adoptions; photo text;
begin
  if jsonb_typeof(payload) is distinct from 'object' or char_length(payload::text)>16000 then
    raise exception 'Publicación inválida' using errcode='22023'; end if;
  if target_id is null then
    insert into public.dopmi_adoptions(owner_id) values(actor) returning * into a;
  else
    select * into a from public.dopmi_adoptions where id=target_id for update;
    if not found or a.owner_id<>actor then raise exception 'Publicación no disponible' using errcode='42501'; end if;
    if expected_version is distinct from a.version then raise exception 'La publicación cambió. Vuelve a cargarla.' using errcode='40001'; end if;
    if a.status='submitted' then raise exception 'Retira la solicitud de revisión antes de editar.' using errcode='22023'; end if;
  end if;
  -- Only these user-authored fields are copied. Owner, review, status and dates are server controlled.
  update public.dopmi_adoptions set
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
end;
$$;

create function public.dopmi_transition_adoption(post_id uuid,expected_version integer,action text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); a public.dopmi_adoptions; next_status text;
begin
  select * into a from public.dopmi_adoptions where id=post_id for update;
  if not found or a.owner_id<>actor then raise exception 'Publicación no disponible' using errcode='42501'; end if;
  if expected_version is distinct from a.version then raise exception 'La publicación cambió. Vuelve a cargarla.' using errcode='40001'; end if;
  if action='submit' and a.status in ('draft','changes_requested') then
    if char_length(a.pet_name)<1 or char_length(a.city)<1 or char_length(a.region)<1 or char_length(a.story)<20
      or char_length(a.publisher_name)<1 or cardinality(a.photos)<1 then
      raise exception 'Completa nombre, ubicación, historia, nombre público y al menos una foto.' using errcode='22023'; end if;
    if exists(select 1 from unnest(a.photos) photo where not exists(
      select 1 from storage.objects o where o.bucket_id='dopmi-adoption-photos' and o.name=photo)) then
      raise exception 'Una foto no terminó de subir. Vuelve a adjuntarla.' using errcode='22023'; end if;
    next_status:='submitted';
  elsif action='withdraw' and a.status='submitted' then next_status:='draft';
  elsif action='adopted' and a.status='published' then next_status:='adopted';
  elsif action='archive' and a.status<>'archived' then next_status:='archived';
  else raise exception 'Esta transición no está disponible' using errcode='22023'; end if;
  update public.dopmi_adoptions set status=next_status,version=version+1,updated_at=now(),
    submitted_at=case when next_status='submitted' then now() else submitted_at end
    where id=post_id returning * into a;
  return to_jsonb(a);
end;
$$;

create function public.dopmi_review_adoption(post_id uuid,expected_version integer,decision text,feedback text default '') returns jsonb
language plpgsql security definer set search_path='' as $$
declare a public.dopmi_adoptions; review_id uuid; next_status text;
begin
  if not public.dopmi_is_admin() then raise exception 'Acceso administrativo requerido' using errcode='42501'; end if;
  select * into a from public.dopmi_adoptions where id=post_id for update;
  if not found then raise exception 'Publicación no disponible' using errcode='22023'; end if;
  if expected_version is distinct from a.version then raise exception 'La publicación cambió. Vuelve a cargarla.' using errcode='40001'; end if;
  if decision in ('published','changes_requested','rejected') and a.status='submitted' then next_status:=decision;
  elsif decision='archived' and a.status in ('published','adopted') then next_status:='archived';
  else raise exception 'Esta decisión no está disponible' using errcode='22023'; end if;
  if feedback is null or char_length(feedback)>2000 or (decision<>'published' and char_length(btrim(feedback))<5) then
    raise exception 'Escribe el motivo de la decisión (5 a 2000 caracteres).' using errcode='22023'; end if;
  if not exists(select 1 from public.profiles where id=a.owner_id and account_status='active') then
    raise exception 'La cuenta responsable no está activa' using errcode='42501'; end if;
  update public.dopmi_adoptions set status=next_status,review_feedback=btrim(feedback),version=version+1,updated_at=now(),
    published_at=case when next_status='published' then now() else published_at end where id=post_id returning * into a;
  insert into private.dopmi_adoption_reviews(post_id,actor_id,decision,feedback,version)
    values(post_id,auth.uid(),next_status,btrim(feedback),a.version) returning id into review_id;
  insert into private.admin_access_log(actor_id,action) values(auth.uid(),'adoptions.review');
  insert into public.dopmi_notifications(user_id,kind,post_id,source_id,title)
    values(a.owner_id,'review',a.id,review_id,case next_status when 'published' then 'Tu publicación fue aprobada'
      when 'changes_requested' then 'Hay correcciones para tu publicación' when 'rejected' then 'Tu publicación no fue aprobada'
      else 'Tu publicación fue retirada' end);
  return to_jsonb(a);
end;
$$;

create function public.dopmi_admin_adoptions(status_filter text default 'submitted',page_number integer default 1) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
  if not public.dopmi_is_admin() then raise exception 'Acceso administrativo requerido' using errcode='42501'; end if;
  if page_number is null or page_number<1 then raise exception 'Página inválida' using errcode='22023'; end if;
  select jsonb_build_object('total',(select count(*) from public.dopmi_adoptions where status_filter='' or status=status_filter),
    'items',coalesce((select jsonb_agg(to_jsonb(a)) from (select * from public.dopmi_adoptions
      where status_filter='' or status=status_filter order by submitted_at nulls last,created_at,id
      limit 20 offset (page_number::bigint-1)*20) a),'[]'::jsonb)) into result;
  insert into private.admin_access_log(actor_id,action) values(auth.uid(),'adoptions.list');
  return result;
end;
$$;

create function public.dopmi_adoption_reviews(post_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
  if not public.dopmi_is_admin() then raise exception 'Acceso administrativo requerido' using errcode='42501'; end if;
  return coalesce((select jsonb_agg(to_jsonb(r)) from (select v.* from private.dopmi_adoption_reviews v
    where v.post_id=$1 order by v.created_at desc,v.id limit 50) r),'[]'::jsonb);
end;
$$;

create function public.dopmi_set_favorite(post_id uuid,saved boolean) returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor();
begin
  if saved then
    if public.dopmi_adoption_detail(post_id) is null then raise exception 'Publicación no disponible' using errcode='22023'; end if;
    insert into public.dopmi_favorites(user_id,post_id) values(actor,post_id) on conflict do nothing;
  else delete from public.dopmi_favorites where user_id=actor and dopmi_favorites.post_id=$1; end if;
end;
$$;

create function public.dopmi_read_notification(notification_id uuid) returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor();
begin
  update public.dopmi_notifications set read_at=coalesce(read_at,now()) where id=notification_id and user_id=actor;
end;
$$;

revoke all on function private.dopmi_require_actor(),private.dopmi_public_post(public.dopmi_adoptions) from public,anon,authenticated;
revoke all on function public.dopmi_catalog(jsonb,integer,integer),public.dopmi_adoption_detail(uuid),public.dopmi_public_profile(uuid) from public;
grant execute on function public.dopmi_catalog(jsonb,integer,integer),public.dopmi_adoption_detail(uuid),public.dopmi_public_profile(uuid) to anon,authenticated;
revoke all on function public.dopmi_save_adoption(jsonb,uuid,integer),public.dopmi_transition_adoption(uuid,integer,text),
 public.dopmi_review_adoption(uuid,integer,text,text),public.dopmi_admin_adoptions(text,integer),public.dopmi_adoption_reviews(uuid),
 public.dopmi_set_favorite(uuid,boolean),public.dopmi_read_notification(uuid) from public,anon;
grant execute on function public.dopmi_save_adoption(jsonb,uuid,integer),public.dopmi_transition_adoption(uuid,integer,text),
 public.dopmi_review_adoption(uuid,integer,text,text),public.dopmi_admin_adoptions(text,integer),public.dopmi_adoption_reviews(uuid),
 public.dopmi_set_favorite(uuid,boolean),public.dopmi_read_notification(uuid) to authenticated;
commit;
