begin;
-- Dedicated public contact fields: never copy private Auth/verification contacts.
alter table public.dopmi_rescuer_profiles
  add column public_email text not null default '' check(char_length(public_email)<=254),
  add column public_phone text not null default '' check(char_length(public_phone)<=16),
  add column public_address text not null default '' check(char_length(public_address)<=500),
  add column website_url text not null default '' check(char_length(website_url)<=500),
  add column contact_consent boolean not null default false,
  add column contact_publication_enabled boolean not null default false,
  add column field_feedback jsonb not null default '{}'::jsonb;
create or replace function public.dopmi_save_rescuer_profile(payload jsonb,expected_version integer default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); item public.dopmi_rescuer_profiles; avatar text; ig text; fb text; email text; phone text; address text; website text; consent boolean;
begin
  if jsonb_typeof(payload) is distinct from 'object' or char_length(payload::text)>5000
    or payload - array['display_name','bio','city','region','instagram_url','facebook_url','avatar_path','public_email','public_phone','public_address','website_url','contact_consent']::text[] <> '{}'::jsonb then
    raise exception 'Perfil inválido' using errcode='22023'; end if;
  select * into item from public.dopmi_rescuer_profiles where owner_id=actor for update;
  if not found then
    if expected_version is not null then raise exception 'El perfil cambió. Vuelve a cargarlo.' using errcode='PT409'; end if;
    insert into public.dopmi_rescuer_profiles(owner_id) values(actor) returning * into item;
  elsif expected_version is distinct from item.version then raise exception 'El perfil cambió. Vuelve a cargarlo.' using errcode='PT409';
  elsif item.status='submitted' then raise exception 'Retira el perfil de revisión antes de editar.' using errcode='22023'; end if;
  avatar:=nullif(payload->>'avatar_path',''); ig:=btrim(coalesce(payload->>'instagram_url','')); fb:=btrim(coalesce(payload->>'facebook_url',''));
  if avatar is not null and avatar !~ ('^'||actor::text||'/'||actor::text||'/[0-9a-f-]{36}\.(jpg|png|webp)$') then raise exception 'Avatar inválido' using errcode='22023'; end if;
  if (ig<>'' and ig !~ '^https://(www\.)?instagram\.com/') or (fb<>'' and fb !~ '^https://(www\.)?facebook\.com/') then raise exception 'Usa enlaces https válidos de Instagram o Facebook' using errcode='22023'; end if;
  if payload ? 'contact_consent' and jsonb_typeof(payload->'contact_consent') <> 'boolean' then raise exception 'Consentimiento inválido' using errcode='22023'; end if;
  email:=btrim(coalesce(payload->>'public_email','')); phone:=btrim(coalesce(payload->>'public_phone',''));
  address:=btrim(coalesce(payload->>'public_address','')); website:=btrim(coalesce(payload->>'website_url',''));
  consent:=coalesce((payload->>'contact_consent')::boolean,false);
  if (email<>'' and email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$')
    or (phone<>'' and phone !~ '^\+[1-9][0-9]{7,14}$')
    or (website<>'' and website !~ '^https://[^[:space:]/?#@]+([/?#][^[:space:]]*)?$') then
    raise exception 'Datos de contacto inválidos' using errcode='22023'; end if;
  update public.dopmi_rescuer_profiles set
    display_name=btrim(coalesce(payload->>'display_name','')),bio=btrim(coalesce(payload->>'bio','')),
    city=btrim(coalesce(payload->>'city','')),region=btrim(coalesce(payload->>'region','')),
    instagram_url=ig,facebook_url=fb,avatar_path=avatar,
    public_email=email,public_phone=phone,public_address=address,website_url=website,contact_consent=consent,contact_publication_enabled=case when consent then contact_publication_enabled else false end,field_feedback='{}'::jsonb,
    status='draft',review_feedback='',submitted_at=null,version=item.version+1,updated_at=now()
  where owner_id=actor returning * into item;
  return to_jsonb(item);
end;
$$;

create or replace function public.dopmi_transition_rescuer_profile(expected_version integer,action text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); item public.dopmi_rescuer_profiles;
begin
  select * into item from public.dopmi_rescuer_profiles where owner_id=actor for update;
  if not found then raise exception 'Perfil no disponible' using errcode='22023'; end if;
  if expected_version is distinct from item.version then raise exception 'El perfil cambió. Vuelve a cargarlo.' using errcode='PT409'; end if;
  if action='revoke_contacts' then
    update public.dopmi_rescuer_profiles set contact_consent=false,contact_publication_enabled=false,version=version+1,updated_at=now() where owner_id=actor returning * into item;
  elsif action='submit' then
    if item.contact_consent and item.public_phone<>'' and not exists(select 1 from auth.users u where u.id=actor and ltrim(u.phone,'+')=ltrim(item.public_phone,'+') and u.phone_confirmed_at is not null) then
      raise exception 'Verifica el teléfono por SMS antes de publicarlo' using errcode='22023'; end if;
    if item.status not in ('draft','changes_requested','rejected') or char_length(item.display_name)<1 or char_length(item.bio)<20 or char_length(item.city)<1 or char_length(item.region)<1
      or not private.dopmi_rescuer_verified(actor) then raise exception 'Completa tu perfil y verificación antes de enviarlo' using errcode='22023'; end if;
    if item.avatar_path is not null and not exists(select 1 from storage.objects where bucket_id='dopmi-rescuer-profile-media' and name=item.avatar_path) then raise exception 'El avatar no terminó de subir' using errcode='22023'; end if;
    update public.dopmi_rescuer_profiles set status='submitted',submitted_at=now(),version=version+1,updated_at=now() where owner_id=actor returning * into item;
  elsif action='withdraw' and item.status='submitted' then
    update public.dopmi_rescuer_profiles set status='draft',version=version+1,updated_at=now() where owner_id=actor returning * into item;
  else raise exception 'Transición no disponible' using errcode='22023'; end if;
  return to_jsonb(item);
end;
$$;

create or replace function public.dopmi_review_rescuer_profile_v2(profile_owner uuid,expected_version integer,decision text,feedback text default '',field_feedback jsonb default '{}'::jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
#variable_conflict use_variable
declare item public.dopmi_rescuer_profiles;
begin
  if not public.dopmi_is_admin() then raise exception 'Acceso administrativo requerido' using errcode='42501'; end if;
  if jsonb_typeof(field_feedback) is distinct from 'object' or char_length(field_feedback::text)>5000
    or field_feedback - array['display_name','bio','city','region','instagram_url','facebook_url','avatar_path','public_email','public_phone','public_address','website_url','contact_consent']::text[] <> '{}'::jsonb
    or exists(select 1 from jsonb_each(field_feedback) e where jsonb_typeof(e.value)<>'string' or char_length(e.value #>> '{}')>500) then
    raise exception 'Observaciones por campo inválidas' using errcode='22023'; end if;
  select * into item from public.dopmi_rescuer_profiles where owner_id=profile_owner for update;
  if not found or item.status<>'submitted' then raise exception 'Perfil no disponible' using errcode='22023'; end if;
  if item.version is distinct from expected_version then raise exception 'El perfil cambió' using errcode='PT409'; end if;
  if decision not in ('published','changes_requested','rejected') or (decision<>'published' and char_length(btrim(coalesce(feedback,'')))<5) then raise exception 'Decisión inválida' using errcode='22023'; end if;
  if decision='published' and item.contact_consent and item.public_phone<>'' and not exists(select 1 from auth.users u where u.id=item.owner_id and ltrim(u.phone,'+')=ltrim(item.public_phone,'+') and u.phone_confirmed_at is not null) then
    raise exception 'El teléfono público no está verificado' using errcode='22023'; end if;
  update public.dopmi_rescuer_profiles set status=decision,contact_publication_enabled=case when decision='published' then contact_consent else contact_publication_enabled end,review_feedback=btrim(coalesce(feedback,'')),field_feedback=field_feedback,
    approved_snapshot=case when decision='published' then jsonb_build_object('display_name',display_name,'bio',bio,'city',city,'region',region,'instagram_url',instagram_url,'facebook_url',facebook_url,'avatar_path',avatar_path,'public_email',public_email,'public_phone',public_phone,'public_address',public_address,'website_url',website_url,'contact_consent',contact_consent) else approved_snapshot end,
    published_at=case when decision='published' then now() else published_at end,version=version+1,updated_at=now()
    where owner_id=profile_owner returning * into item;
  insert into private.dopmi_rescuer_profile_reviews(owner_id,reviewer_id,decision,feedback,version,snapshot)
    values(item.owner_id,auth.uid(),decision,btrim(coalesce(feedback,'')),item.version,to_jsonb(item));
  insert into public.dopmi_notifications(user_id,kind,source_id,title) values(item.owner_id,'review',item.owner_id,case when decision='published' then 'Tu perfil público fue aprobado' else 'Tu perfil público necesita atención' end)
    on conflict(user_id,kind,source_id) do update set title=excluded.title,read_at=null,created_at=now();
  insert into private.admin_access_log(actor_id,action) values(auth.uid(),'rescuer_profiles.review');
  return to_jsonb(item);
end;
$$;

create or replace function public.dopmi_rescuer_public(person_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare verification public.dopmi_rescue_records; edited public.dopmi_rescuer_profiles; profile jsonb; source jsonb;
begin
  select * into verification from public.dopmi_rescue_records where owner_id=person_id and kind='verification' and status='approved' and approved_snapshot is not null order by approved_at desc,id limit 1;
  if not found or not private.dopmi_public_rescuer(person_id) then return null; end if;
  select * into edited from public.dopmi_rescuer_profiles where owner_id=person_id and approved_snapshot is not null;
  source:=case when found then edited.approved_snapshot else verification.approved_snapshot end;
  profile:=jsonb_build_object(
    'id',person_id,'name',coalesce(source->>'display_name',source->>'public_name','Rescatista Dopmi'),'bio',coalesce(source->>'bio',''),
    'city',coalesce(source->>'city',''),'region',coalesce(source->>'region',source->>'state',''),'avatar_path',source->>'avatar_path',
    'instagram_url',coalesce(source->>'instagram_url',''),'facebook_url',coalesce(source->>'facebook_url',''),'verified',true,
    'saved',exists(select 1 from public.dopmi_saved_rescuers s where s.user_id=auth.uid() and s.rescuer_id=person_id and public.dopmi_actor_active()),
    'adopted_count',(select count(*) from public.dopmi_adoptions where owner_id=person_id and status='adopted'),
    'adoptions',coalesce((select jsonb_agg(private.dopmi_public_post(a) order by a.published_at desc,a.id) from public.dopmi_adoptions a where a.owner_id=person_id and a.status='published'),'[]'::jsonb),
    'cases',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'status',r.status,'public_data',r.approved_snapshot) order by r.approved_at desc,r.id) from public.dopmi_rescue_records r where r.owner_id=person_id and r.kind='case' and private.dopmi_rescue_public_visible(r)),'[]'::jsonb),
    'activity',coalesce((select jsonb_agg(jsonb_build_object('id',u.id,'case_id',u.case_id,'body',u.approved_snapshot->>'body','photos',u.approved_snapshot->'photos','published_at',u.published_at) order by u.published_at desc,u.id) from public.dopmi_case_updates u where u.owner_id=person_id and u.status='published' and u.approved_snapshot is not null and exists(select 1 from public.dopmi_rescue_records c where c.id=u.case_id and private.dopmi_rescue_public_visible(c))),'[]'::jsonb));
  profile:=profile || jsonb_build_object(
    'member_since',(select created_at from public.profiles where id=person_id),
    'active_adoptions',(select count(*) from public.dopmi_adoptions where owner_id=person_id and status='published'),
    'website_url',case when edited.contact_consent and edited.contact_publication_enabled and coalesce((source->>'contact_consent')::boolean,false) then coalesce(source->>'website_url','') else '' end,
    'public_email',case when edited.contact_consent and edited.contact_publication_enabled and coalesce((source->>'contact_consent')::boolean,false) then coalesce(source->>'public_email','') else '' end,
    'public_address',case when edited.contact_consent and edited.contact_publication_enabled and coalesce((source->>'contact_consent')::boolean,false) then coalesce(source->>'public_address','') else '' end,
    'public_phone',case when edited.contact_consent and edited.contact_publication_enabled and coalesce((source->>'contact_consent')::boolean,false)
      and exists(select 1 from auth.users u where u.id=person_id and ltrim(u.phone,'+')=ltrim(source->>'public_phone','+') and u.phone_confirmed_at is not null)
      then coalesce(source->>'public_phone','') else '' end);
  return profile;
end;
$$;

create or replace function public.dopmi_review_rescuer_profile(profile_owner uuid,expected_version integer,decision text,feedback text default '') returns jsonb
language sql security definer set search_path='' as $$
  select public.dopmi_review_rescuer_profile_v2(profile_owner,expected_version,decision,feedback,'{}'::jsonb);
$$;
revoke all on function public.dopmi_review_rescuer_profile_v2(uuid,integer,text,text,jsonb) from public,anon,authenticated;
grant execute on function public.dopmi_review_rescuer_profile_v2(uuid,integer,text,text,jsonb) to authenticated;
create or replace function public.dopmi_rescuer_public_metrics(person_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
  if public.dopmi_rescuer_public(person_id) is null then return null; end if;
  with cases as materialized (
    select r.id,r.status from public.dopmi_rescue_records r
    where r.owner_id=person_id and r.kind='case' and private.dopmi_rescue_public_visible(r)
  ), expenses as materialized (
    select e.parent_id,e.reimbursable_cents as target,
      (public.dopmi_expense_funding(e.id)->>'funded_cents')::bigint as funded
    from public.dopmi_rescue_records e join cases c on c.id=e.parent_id
    where e.kind='expense' and private.dopmi_rescue_public_visible(e)
  ), adoptions as materialized (
    -- Historical counts reveal no retired listing identity or unpublished edits.
    select a.id,a.rescue_case_id,a.status from public.dopmi_adoptions a
    where a.owner_id=person_id and a.published_at is not null
  )
  select jsonb_build_object(
    'received_support_pets',(select count(distinct parent_id) from expenses where funded>0),
    'published_cases',(select count(*) from cases),
    'active_donation_cases',(select count(*) from cases c where c.status='approved'
      and exists(select 1 from expenses e where e.parent_id=c.id and e.target>e.funded)),
    'active_adoptions',(select count(*) from adoptions where status='published'),
    'published_donation_cases',(select count(*) from cases c where exists(select 1 from expenses e where e.parent_id=c.id)),
    'published_adoptions',(select count(*) from adoptions),
    'funded_cents',(select coalesce(sum(funded),0) from expenses),
    'completed_needs',(select count(*) from expenses where target>0 and funded>=target),
    'helped_pets',(select count(*) from (
      select id from cases union select coalesce(rescue_case_id,id) from adoptions
    ) pets),
    'closed_cases',(select count(*) from cases where status='closed')
  ) into result;
  return result;
end;
$$;
commit;
