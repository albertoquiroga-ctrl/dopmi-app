-- The previous identity table had table-wide UPDATE grants, including role.
-- Its security-definer guard checked current_user, which resolves to the
-- function owner and therefore skipped the intended client protection.
-- Keep legacy records/triggers for reference, but remove this alternate API
-- path to identity data. Milestone 1 uses profiles and the authorized RPC only.
begin;
do $$
declare legacy_columns text;
begin
  if to_regclass('public.users') is not null then
    execute 'revoke all privileges on table public.users from public, anon, authenticated';
    -- Table revocation alone does not revoke pre-existing column ACLs.
    select string_agg(format('%I', attname), ', ' order by attnum)
      into legacy_columns from pg_attribute
      where attrelid = 'public.users'::regclass and attnum > 0 and not attisdropped;
    if legacy_columns is not null then
      execute format('revoke all privileges (%s) on table public.users from public, anon, authenticated', legacy_columns);
    end if;
  end if;
end;
$$;
commit;
