begin;

-- Detail observations are separate from discovery-card impressions. No backfill.
create table private.dopmi_adoption_detail_views (
  post_id uuid not null references public.dopmi_adoptions(id) on delete cascade,
  actor_id uuid not null references auth.users(id) on delete cascade,
  first_viewed_at timestamptz not null default now(),
  primary key(post_id, actor_id)
);
create index dopmi_adoption_detail_views_actor on private.dopmi_adoption_detail_views(actor_id);
create table private.dopmi_adoption_detail_tracking (
  singleton boolean primary key default true check(singleton),
  started_at timestamptz not null default now()
);
insert into private.dopmi_adoption_detail_tracking(singleton) values(true);
alter table private.dopmi_adoption_detail_views enable row level security;
alter table private.dopmi_adoption_detail_tracking enable row level security;
revoke all on private.dopmi_adoption_detail_views, private.dopmi_adoption_detail_tracking
  from public, anon, authenticated, service_role;
create index dopmi_favorites_report_post on public.dopmi_favorites(post_id);

create function public.dopmi_record_adoption_detail_view(post_id uuid, consent boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.dopmi_require_actor(); allowed boolean;
begin
  if consent is distinct from true then return; end if;
  perform 1 from public.dopmi_adoptions a join public.profiles p on p.id=a.owner_id
    where a.id=post_id and a.status='published' and a.owner_id<>actor
      and p.account_status='active' for share of a;
  if not found then return; end if;
  -- Serialize with withdrawal: a delayed observation cannot survive an opt-out.
  select m.consent into allowed from private.dopmi_adoption_measurement m
    where m.actor_id=actor for share;
  if allowed is distinct from true then return; end if;
  insert into private.dopmi_adoption_detail_views(post_id,actor_id)
    values(post_id,actor) on conflict do nothing;
end;
$$;

create function private.dopmi_erase_adoption_detail_views() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if not new.consent then
    delete from private.dopmi_adoption_detail_views where actor_id=new.actor_id;
  end if;
  return new;
end;
$$;
create trigger dopmi_erase_adoption_detail_views after update of consent
  on private.dopmi_adoption_measurement for each row
  execute function private.dopmi_erase_adoption_detail_views();

create function public.dopmi_admin_adoption_report(search_text text default '',
  species_filter text default '', page_number integer default 1) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare result jsonb;
begin
  if not public.dopmi_is_admin() then
    raise exception 'Acceso administrativo requerido' using errcode='42501';
  end if;
  if search_text is null or char_length(search_text)>100 or species_filter is null
    or species_filter not in('','dog','cat') or page_number is null or page_number<1 then
    raise exception 'Filtros inválidos' using errcode='22023';
  end if;
  with filtered as (
    select a.id,a.pet_name,a.species,a.publisher_name,a.city,a.region,a.published_at
    from public.dopmi_adoptions a join public.profiles p on p.id=a.owner_id
    where a.status='published' and p.account_status='active'
      and (species_filter='' or a.species=species_filter)
      and (btrim(search_text)='' or strpos(lower(a.pet_name),lower(btrim(search_text)))>0
        or strpos(lower(a.publisher_name),lower(btrim(search_text)))>0)
  ), page as (
    select * from filtered order by published_at desc nulls last,id
      limit 20 offset (page_number::bigint-1)*20
  ), counts as (
    select p.*,
      (select count(*) from private.dopmi_adoption_detail_views v where v.post_id=p.id) detail_viewers,
      (select count(*) from public.dopmi_favorites f join public.dopmi_adoptions a on a.id=f.post_id
        where f.post_id=p.id and f.user_id<>a.owner_id) current_favorites,
      (select count(*) from public.dopmi_threads t where t.post_id=p.id and exists(
        select 1 from public.dopmi_messages m where m.thread_id=t.id and m.sender_id=t.adopter_id)) contacts,
      (select count(*) from public.dopmi_threads t where t.post_id=p.id and exists(
        select 1 from public.dopmi_messages m where m.thread_id=t.id and m.sender_id=t.owner_id
          and ((m.origin='user' and m.is_adoption_reply is true)
            or (m.origin in('user','unknown') and m.is_adoption_reply is null and exists(
              select 1 from public.dopmi_messages incoming where incoming.thread_id=t.id
                and incoming.sender_id=t.adopter_id and incoming.created_at<=m.created_at))))) first_replies
    from page p
  )
  select jsonb_build_object('total',(select count(*) from filtered),
    'detail_tracking_started_at',(select started_at from private.dopmi_adoption_detail_tracking),
    'generated_at',now(),
    'items',coalesce((select jsonb_agg(to_jsonb(c) order by published_at desc nulls last,id) from counts c),'[]'::jsonb))
    into result;
  insert into private.admin_access_log(actor_id,action) values(auth.uid(),'adoptions.report');
  return result;
end;
$$;

revoke all on function public.dopmi_record_adoption_detail_view(uuid,boolean),
  public.dopmi_admin_adoption_report(text,text,integer), private.dopmi_erase_adoption_detail_views()
  from public, anon, authenticated, service_role;
grant execute on function public.dopmi_record_adoption_detail_view(uuid,boolean),
  public.dopmi_admin_adoption_report(text,text,integer) to authenticated;

commit;
