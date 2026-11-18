-- Temporary owner reads for the pre-private-revisions DEV schema.
-- Apply only to QA project ohqxranynackjignryep. Remove before installing
-- the canonical 20261103024404 mini QA adoption edits migration.
begin;

do $$
begin
  if to_regclass('private.dopmi_adoption_edits') is not null then
    raise exception 'This compatibility patch requires the older DEV schema.';
  end if;
end;
$$;

create function public.dopmi_adoption_own(post_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare
  actor uuid := private.dopmi_require_actor();
  result jsonb;
begin
  select to_jsonb(a) || jsonb_build_object('_has_private_draft', false)
  into result
  from public.dopmi_adoptions a
  where a.id = post_id and a.owner_id = actor;
  return result;
end;
$$;

create function public.dopmi_adoption_mine(page_number integer default 1, page_size integer default 12)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare
  actor uuid := private.dopmi_require_actor();
  result jsonb;
begin
  if page_number is null or page_number < 1 or page_size is null or page_size not between 1 and 100 then
    raise exception 'Paginación inválida' using errcode='22023';
  end if;

  select jsonb_build_object(
    'total', (select count(*) from public.dopmi_adoptions a where a.owner_id = actor),
    'items', coalesce((
      select jsonb_agg(
        to_jsonb(a) || jsonb_build_object('_has_private_draft', false)
        order by a.updated_at desc, a.id
      )
      from (
        select * from public.dopmi_adoptions
        where owner_id = actor
        order by updated_at desc, id
        limit page_size offset (page_number::bigint - 1) * page_size
      ) a
    ), '[]'::jsonb)
  ) into result;
  return result;
end;
$$;

revoke all on function public.dopmi_adoption_own(uuid), public.dopmi_adoption_mine(integer, integer)
  from public, anon, authenticated, service_role;
grant execute on function public.dopmi_adoption_own(uuid), public.dopmi_adoption_mine(integer, integer)
  to authenticated;

commit;
