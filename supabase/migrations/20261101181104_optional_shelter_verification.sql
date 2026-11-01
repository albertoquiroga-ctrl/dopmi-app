begin;

-- Dopmi verification is an optional shelter credential. It is not permission
-- to request support; active/confirmed ownership, case review and Stripe remain.
create function private.dopmi_support_owner_active(person uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.profiles p join auth.users u on u.id=p.id
    where p.id=person and p.account_status='active' and u.email_confirmed_at is not null);
$$;
revoke all on function private.dopmi_support_owner_active(uuid) from public,anon,authenticated,service_role;

-- Patch only the obsolete predicate in the established wrapper chain. Each
-- source fragment must occur exactly once, otherwise the entire migration aborts.
-- CREATE OR REPLACE preserves ownership, ACLs and every unrelated guard/body.
do $migration$
declare patch record; definition text; target regprocedure;
begin
  for patch in select * from (values
    ('public.dopmi_transition_rescue(uuid,integer,text)',
      $old$    if r.kind<>'verification' and not private.dopmi_rescuer_verified(actor) then
      raise exception 'Primero completa la verificación de rescatista' using errcode='22023'; end if;$old$, ''),
    ('public.dopmi_review_rescue(uuid,integer,text,text,bigint,boolean,text,boolean)',
      $old$    if r.kind<>'verification' and not private.dopmi_rescuer_verified(person) then
      raise exception 'El rescatista no tiene verificación vigente' using errcode='22023'; end if;$old$,
      $new$    if not private.dopmi_support_owner_active(person) then
      raise exception 'Cuenta activa y confirmada requerida' using errcode='22023'; end if;$new$),
    ('private.dopmi_rescue_public_visible(public.dopmi_rescue_records)',
      'private.dopmi_rescuer_verified(r.owner_id)', 'private.dopmi_support_owner_active(r.owner_id)'),
    ('private.dopmi_expense_payable(public.dopmi_rescue_records)',
      'private.dopmi_rescuer_verified(r.owner_id)', 'private.dopmi_support_owner_active(r.owner_id)'),
    ('public.dopmi_payment_server_expense_v1(text,jsonb)',
      $old$   if not private.dopmi_rescuer_verified(actor) then raise exception 'Completa la verificación de rescatista' using errcode='42501'; end if;$old$, ''),
    ('public.dopmi_payment_server(text,jsonb)',
      'private.dopmi_rescuer_verified(person)', 'private.dopmi_support_owner_active(person)'),
    ('private.dopmi_public_rescuer(uuid)',
      'or private.dopmi_rescuer_verified(person)',
      $new$or private.dopmi_rescuer_verified(person)
        or exists(select 1 from public.dopmi_rescue_records c where c.owner_id=person
          and c.kind='case' and private.dopmi_rescue_public_visible(c))$new$),
    ('public.dopmi_rescuer_public(uuid)',
      'if not found or not private.dopmi_public_rescuer(person_id) then return null; end if;',
      $new$if not private.dopmi_public_rescuer(person_id) or (verification.id is null and not exists(
    select 1 from public.dopmi_rescue_records c where c.owner_id=person_id
      and c.kind='case' and private.dopmi_rescue_public_visible(c))) then return null; end if;$new$),
    ('public.dopmi_rescuer_public(uuid)',
      $old$'verified',true,$old$, $new$'verified',private.dopmi_rescuer_verified(person_id),$new$),
    ('public.dopmi_rescue_public(uuid,integer)',
      'as rescuer_name', 'as rescuer_name, private.dopmi_rescuer_verified(r.owner_id) as rescuer_verified'),
    ('public.dopmi_transition_rescuer_profile(integer,text)',
      $old$or not private.dopmi_rescuer_verified(actor) then raise exception 'Completa tu perfil y verificación antes de enviarlo'$old$,
      $new$or not private.dopmi_support_owner_active(actor) then raise exception 'Completa tu perfil antes de enviarlo'$new$),
    ('public.dopmi_rescuer_profile_file_access(text,boolean)',
      'private.dopmi_rescuer_verified(item.owner_id)', 'private.dopmi_public_rescuer(item.owner_id)')
  ) as changes(signature,before_text,after_text)
  loop
    target:=to_regprocedure(patch.signature);
    if target is null then raise exception 'Optional verification: missing function %',patch.signature; end if;
    definition:=replace(pg_get_functiondef(target),E'\r\n',E'\n');
    if (length(definition)-length(replace(definition,patch.before_text,'')))/length(patch.before_text)<>1 then
      raise exception 'Optional verification: unexpected definition for %',patch.signature;
    end if;
    execute replace(definition,patch.before_text,patch.after_text);
  end loop;
end;
$migration$;

-- The verification predicate, existing records/snapshots, finance, flags,
-- scheduled jobs and every client's grants are deliberately unchanged.
commit;
