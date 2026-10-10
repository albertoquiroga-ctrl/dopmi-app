-- Application version conflict is HTTP409, never a retryable database serialization failure.
-- PostgREST14 retries user-raised40001 indefinitely. Existing APIs and permissions remain unchanged.
create or replace function public.dopmi_close_adoption(post_id uuid,expected_version integer,reason text,
  dopmi_support boolean default null,description text default '') returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); a public.dopmi_adoptions; result jsonb;
begin
  select * into a from public.dopmi_adoptions where id=post_id for update;
  if not found or a.owner_id<>actor then raise exception 'Publicación no disponible' using errcode='42501'; end if;
  if a.version is distinct from expected_version then raise exception 'La publicación cambió. Vuelve a cargarla.' using errcode='PT409'; end if;
  if a.status<>'published' or reason is null or reason not in('adopted','other')
    or (reason='adopted') is distinct from (dopmi_support is not null)
    or description is null or char_length(description)>1000 then raise exception 'Cierre inválido' using errcode='22023'; end if;
  result:=public.dopmi_transition_adoption(post_id,expected_version,case when reason='adopted' then 'adopted' else 'archive' end);
  insert into private.dopmi_adoption_closures(post_id,reason,dopmi_support,description,version)
    values(post_id,reason,dopmi_support,btrim(description),(result->>'version')::integer);
  return result;
end; $$;

create or replace function public.dopmi_archive_support_case(record_id uuid,expected_version integer) returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); r public.dopmi_rescue_records;
begin
  perform private.dopmi_rescue_lock(actor);
  select * into r from public.dopmi_rescue_records where id=record_id for update;
  if not found or r.owner_id<>actor or r.kind<>'case' then raise exception 'Caso no disponible' using errcode='42501'; end if;
  if r.version is distinct from expected_version then raise exception 'La solicitud cambió. Recarga antes de continuar' using errcode='PT409'; end if;
  if r.status<>'closed' then
    if r.status not in('draft','changes_requested','rejected') or r.approved_snapshot is not null
      or exists(select 1 from public.dopmi_rescue_records e where e.parent_id=r.id and
        (e.status not in('draft','changes_requested','rejected') or e.approved_snapshot is not null or e.reimbursable_cents<>0)) then
      raise exception 'Resuelve las revisiones y dependencias antes de archivar' using errcode='22023'; end if;
  end if;
  insert into private.dopmi_support_archives(record_id,owner_id) values(record_id,actor) on conflict do nothing;
  update public.dopmi_rescue_records set version=version+1,updated_at=now() where id=record_id returning * into r;
  perform private.dopmi_rescue_audit(r,'archive','');
end; $$;
