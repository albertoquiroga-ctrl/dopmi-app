begin;

-- Private TEST inventory is deliberately independent of the commercial catalog.
-- This migration grants no account access, creates no products or destinations,
-- and never changes the existing commercial gate or moderation requirements.
create table private.dopmi_store_preview_settings (
 singleton boolean primary key default true check(singleton),
 enabled boolean not null default false,
 external_links_enabled boolean not null default false,
 activation_reference text not null default '',
 check(not (enabled or external_links_enabled) or length(trim(activation_reference))>=10)
);
insert into private.dopmi_store_preview_settings(singleton) values(true);

create table private.dopmi_store_preview_grants (
 user_id uuid primary key references auth.users(id) on delete cascade,
 granted_at timestamptz not null default now(),
 expires_at timestamptz not null,
 revoked_at timestamptz,
 authorization_reference text not null check(length(trim(authorization_reference))>=10),
 check(isfinite(granted_at) and isfinite(expires_at) and expires_at>granted_at)
);

create table private.dopmi_store_preview_destinations (
 id uuid primary key default gen_random_uuid(),
 exact_url text not null unique,
 enabled boolean not null default false,
 authorization_reference text not null check(length(trim(authorization_reference))>=10),
 -- A future operational package must also verify that the exact destination
 -- does not redirect and is authorized for QA. No arbitrary query or fragment.
 check(exact_url ~ '^https://[a-z0-9]+([.-][a-z0-9]+)*\.[a-z]{2,}(/[a-zA-Z0-9/_-]*)?$'
   and exact_url !~* '(redirect|return_url|returnurl|destination)')
);

create table private.dopmi_store_preview_products (
 id uuid primary key default gen_random_uuid(),
 name text not null check(length(trim(name)) between 1 and 160 and name ~ '(^|[[:space:]])TEST($|[[:space:]])'),
 brand text not null check(length(trim(brand)) between 1 and 100 and brand ~ '(^|[[:space:]])TEST($|[[:space:]])'),
 species text not null check(species in ('dog','cat')),
 age text not null check(age in ('puppy','adult','senior')),
 size text not null check(size in ('small','medium','large')),
 weight_kg numeric(8,3) not null check(weight_kg>0 and weight_kg<=1000),
 position integer not null default 0 check(position between 0 and 100000),
 asset_key text not null default 'croquetas-banner-pet' check(asset_key='croquetas-banner-pet'),
 enabled boolean not null default false,
 destination_id uuid references private.dopmi_store_preview_destinations(id)
);

alter table private.dopmi_store_preview_settings enable row level security;
alter table private.dopmi_store_preview_grants enable row level security;
alter table private.dopmi_store_preview_destinations enable row level security;
alter table private.dopmi_store_preview_products enable row level security;
revoke all on private.dopmi_store_preview_settings,private.dopmi_store_preview_grants,
 private.dopmi_store_preview_destinations,private.dopmi_store_preview_products from public,anon,authenticated;

-- Invoker helper is only reached through the two explicitly ACL'd RPC below.
-- No admin, editable metadata or selected account mode can confer preview access.
create function private.dopmi_store_preview_expires_at() returns timestamptz
language sql stable set search_path='' as $$
 select g.expires_at from private.dopmi_store_preview_grants g
 join public.profiles p on p.id=g.user_id join auth.users u on u.id=g.user_id
 where g.user_id=(select auth.uid()) and g.revoked_at is null
  and g.granted_at<=statement_timestamp() and g.expires_at>statement_timestamp()
  and p.account_status='active' and u.email_confirmed_at is not null
  and exists(select 1 from private.dopmi_store_preview_settings s where s.singleton and s.enabled);
$$;
revoke all on function private.dopmi_store_preview_expires_at() from public,anon,authenticated;

-- SECURITY DEFINER is intentional: private schema USAGE/table access remains
-- revoked. Authorization uses the caller's auth.uid inside the private helper;
-- the public RPC ACL grants only authenticated, never anon or PUBLIC.
create function public.dopmi_store_preview_catalog(p_filters jsonb default '{}'::jsonb) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare expiry timestamptz; items jsonb;
begin
 expiry:=private.dopmi_store_preview_expires_at();
 if expiry is null then return jsonb_build_object('enabled',false,'preview',true,'items','[]'::jsonb);end if;
 if p_filters is null or jsonb_typeof(p_filters)<>'object' or octet_length(p_filters::text)>2000 then
  raise exception 'Filtros de prueba inválidos' using errcode='22023';
 end if;
 select coalesce(jsonb_agg(item order by sort_weight,position,id),'[]'::jsonb) into items from (
  select p.id,p.position,
   case p_filters->>'sort' when 'weight_asc' then p.weight_kg when 'weight_desc' then -p.weight_kg else 0 end sort_weight,
   jsonb_build_object('id',p.id,'name',p.name,'brand',p.brand,'species',p.species,'age',p.age,
    'size',p.size,'weight_kg',p.weight_kg,'position',p.position,'asset_key',p.asset_key,
    'merchant_name','Dopmi TEST') item
  from private.dopmi_store_preview_products p where p.enabled
   and not exists(select 1 from unnest(array['species','age','size','brand']) k
     where coalesce(p_filters->>k,'')<>'' and to_jsonb(p)->>k<>p_filters->>k)
 ) visible;
 return jsonb_build_object('enabled',true,'preview',true,'expires_at',expiry,
  'external_links_enabled',(select external_links_enabled from private.dopmi_store_preview_settings where singleton),
  'items',items);
end;
$$;

create function public.dopmi_store_preview_product_link(p_id uuid) returns text
language sql stable security definer set search_path='' as $$
 select d.exact_url from private.dopmi_store_preview_products p
 join private.dopmi_store_preview_destinations d on d.id=p.destination_id
 where p.id=p_id and p.enabled and d.enabled
  and private.dopmi_store_preview_expires_at() is not null
  and exists(select 1 from private.dopmi_store_preview_settings s where s.singleton and s.external_links_enabled);
$$;
revoke all on function public.dopmi_store_preview_catalog(jsonb),
 public.dopmi_store_preview_product_link(uuid) from public,anon,authenticated;
grant execute on function public.dopmi_store_preview_catalog(jsonb),
 public.dopmi_store_preview_product_link(uuid) to authenticated;

commit;
