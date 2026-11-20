begin;

-- The seal is a review of five profile fields. This does not publish profile
-- contact details or change adoption, support case, or payment requirements.
create function private.dopmi_rescuer_seal_avatar(person uuid,path text) returns boolean
language sql stable security definer set search_path='' as $$
  select path is not null
    and path ~ ('^'||person::text||'/'||person::text||'/[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}\.(jpg|png|webp)$')
    and exists(select 1 from storage.objects o where o.bucket_id='dopmi-rescuer-profile-media' and o.name=path);
$$;

create function private.dopmi_rescuer_seal_evidence(person uuid) returns jsonb
language sql stable security definer set search_path='' as $$
  select jsonb_strip_nulls(jsonb_build_object(
    'public_name',nullif(btrim(p.display_name),''),
    'avatar_path',case when private.dopmi_rescuer_seal_avatar(person,p.avatar_path) then p.avatar_path end,
    'email',case when u.email_confirmed_at is not null then nullif(btrim(u.email),'') end,
    'phone',case when u.phone_confirmed_at is not null and u.phone ~ '^\+?[1-9][0-9]{7,14}$'
      then '+'||ltrim(u.phone,'+') end,
    'instagram_url',case when p.instagram_url ~ '^https://(www\.)?instagram\.com/[^/?#[:space:]][^[:space:]]*$'
      then p.instagram_url end,
    'facebook_url',case when p.facebook_url ~ '^https://(www\.)?facebook\.com/[^/?#[:space:]][^[:space:]]*$'
      then p.facebook_url end))
  from auth.users u left join public.dopmi_rescuer_profiles p on p.owner_id=u.id
  where u.id=person;
$$;

create function private.dopmi_rescuer_seal_result(r public.dopmi_rescue_records,evidence jsonb) returns jsonb
language sql immutable set search_path='' as $$
  select jsonb_build_object(
    'status',coalesce(r.status,'not_started'),'record_id',r.id,'feedback',coalesce(r.feedback,''),
    'verification_method',case when r.id is not null then coalesce(r.private_data->>'verification_method','documents') end,
    'missing',to_jsonb(array_remove(array[
      case when evidence->>'public_name' is null then 'name' end,
      case when evidence->>'avatar_path' is null then 'photo' end,
      case when evidence->>'email' is null then 'email' end,
      case when evidence->>'phone' is null then 'phone' end,
      case when evidence->>'instagram_url' is null and evidence->>'facebook_url' is null then 'social' end
    ]::text[],null::text)));
$$;

create function public.dopmi_rescuer_seal_status() returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); r public.dopmi_rescue_records;
begin
  select * into r from public.dopmi_rescue_records where owner_id=actor and kind='verification';
  return private.dopmi_rescuer_seal_result(r,private.dopmi_rescuer_seal_evidence(actor));
end;
$$;

create function public.dopmi_submit_rescuer_seal() returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); r public.dopmi_rescue_records; evidence jsonb; result jsonb;
begin
  perform private.dopmi_rescue_lock(actor);
  -- Snapshot the currently committed profile. A separate profile edit may be
  -- made after submission; it cannot alter this request or its photo.
  perform 1 from public.dopmi_rescuer_profiles where owner_id=actor for share;
  select * into r from public.dopmi_rescue_records where owner_id=actor and kind='verification' for update;
  evidence:=private.dopmi_rescuer_seal_evidence(actor);
  result:=private.dopmi_rescuer_seal_result(r,evidence);
  if result->'missing'<>'[]'::jsonb or (r.id is not null and r.status not in ('draft','changes_requested','rejected')) then
    return result;
  end if;
  if r.id is null then
    insert into public.dopmi_rescue_records(owner_id,kind) values(actor,'verification') returning * into r;
  elsif r.private_data->>'verification_method' is distinct from 'profile' then
    -- The existing private record history is the archival boundary.
    -- Its exact original document paths remain addressable under the existing
    -- authorized evidence policy, and must not enter the new review packet.
    perform private.dopmi_rescue_audit(r,'seal_profile_conversion','Solicitud anterior conservada en el historial privado');
  end if;
  update public.dopmi_rescue_records set status='submitted',version=version+1,
    public_data=jsonb_build_object('public_name',evidence->>'public_name'),
    private_data=(evidence-'public_name')||'{"verification_method":"profile"}'::jsonb,
    files='[]'::jsonb,feedback='',submitted_at=statement_timestamp(),updated_at=statement_timestamp()
    where id=r.id returning * into r;
  perform private.dopmi_rescue_audit(r,'submit','Solicitud de sello basada en el perfil');
  return private.dopmi_rescuer_seal_result(r,evidence);
end;
$$;

create function private.dopmi_rescuer_seal_validate(r public.dopmi_rescue_records) returns void
language plpgsql security definer set search_path='' as $$
begin
  if r.files<>'[]'::jsonb or nullif(btrim(r.public_data->>'public_name'),'') is null
    or not coalesce(private.dopmi_rescuer_seal_avatar(r.owner_id,r.private_data->>'avatar_path'),false)
    or not (
      coalesce(r.private_data->>'instagram_url','') ~ '^https://(www\.)?instagram\.com/[^/?#[:space:]][^[:space:]]*$'
      or coalesce(r.private_data->>'facebook_url','') ~ '^https://(www\.)?facebook\.com/[^/?#[:space:]][^[:space:]]*$')
    or not exists(select 1 from auth.users u where u.id=r.owner_id
      and u.email_confirmed_at is not null and r.private_data->>'email'=nullif(btrim(u.email),'')
      and u.phone_confirmed_at is not null and u.phone ~ '^\+?[1-9][0-9]{7,14}$'
      and r.private_data->>'phone'='+'||ltrim(u.phone,'+')) then
    raise exception 'Los datos de esta solicitud ya no están disponibles o cambiaron. Solicita una actualización del perfil.' using errcode='22023';
  end if;
end;
$$;

-- Use the same audit, status, explicit publish decision and separation of
-- reviewer from applicant as documentary verification. Require affirmative
-- review of the profile in the new client, never an empty file checklist.
create function public.dopmi_review_rescuer_seal(record_id uuid,expected_version integer,decision text,note text,reviewed_profile boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.dopmi_rescue_records; person uuid;
begin
  if not public.dopmi_is_admin() then raise exception 'Acceso administrativo requerido' using errcode='42501'; end if;
  select owner_id into person from public.dopmi_rescue_records where id=record_id and kind='verification';
  if person is null then raise exception 'Solicitud no disponible' using errcode='22023'; end if;
  perform private.dopmi_rescue_lock(person);
  select * into r from public.dopmi_rescue_records where id=record_id and kind='verification';
  if not public.dopmi_is_admin() then raise exception 'Acceso administrativo requerido' using errcode='42501'; end if;
  if r.owner_id=auth.uid() then
    raise exception 'Otra persona del equipo debe revisar tu solicitud' using errcode='42501';
  end if;
  if r.id is null or r.private_data->>'verification_method' is distinct from 'profile' then
    raise exception 'Revisa este expediente desde la solicitud correspondiente' using errcode='22023';
  end if;
  if decision='approved' and reviewed_profile is distinct from true then
    raise exception 'Confirma que revisaste el perfil y la foto' using errcode='22023';
  end if;
  return public.dopmi_review_rescue_before_initial_packet(record_id,expected_version,decision,note,0,false,'',reviewed_profile);
end;
$$;

-- Narrow, exact patches preserve ACLs/OIDs and every unrelated rule. Fail
-- closed if the live/source definition has drifted before any of these writes.
do $migration$
declare patch record; definition text; target regprocedure;
begin
  for patch in select * from (values
    ('private.dopmi_rescue_validate(public.dopmi_rescue_records)',
      $old$  if r.kind='verification' then$old$,
      $new$  if r.kind='verification' and r.private_data->>'verification_method'='profile' then
    perform private.dopmi_rescuer_seal_validate(r);
    return;
  end if;
  if r.kind='verification' then$new$),
    ('private.dopmi_rescue_audit(public.dopmi_rescue_records,text,text)',
      $old$values(r.id,auth.uid(),event,note,r.version,to_jsonb(r))$old$,
      $new$values(r.id,auth.uid(),event,note,r.version,
      case when r.kind='verification' and r.private_data->>'verification_method'='profile'
        then jsonb_set(to_jsonb(r),'{private_data}','{"verification_method":"profile"}'::jsonb)
        else to_jsonb(r) end)$new$),
    ('public.dopmi_save_rescue(text,jsonb,jsonb,jsonb,uuid,integer,uuid)',
      $old$  if record_kind='expense' then$old$,
      $new$  if record_kind='verification' and exists(select 1 from public.dopmi_rescue_records
    where owner_id=actor and kind='verification' and private_data->>'verification_method'='profile') then
    raise exception 'Actualiza los datos desde tu perfil de rescatista' using errcode='22023';
  end if;
  if record_kind='expense' then$new$),
    ('public.dopmi_transition_rescue(uuid,integer,text)',
      $old$  if r.owner_id=actor and r.kind='expense' then$old$,
      $new$  if r.owner_id=actor and r.kind='verification' and action='submit' and r.private_data->>'verification_method'='profile' then
    raise exception 'Envía el sello actualizado desde tu perfil de rescatista' using errcode='22023';
  end if;
  if r.owner_id=actor and r.kind='expense' then$new$),
    ('public.dopmi_review_rescue(uuid,integer,text,text,bigint,boolean,text,boolean)',
      $old$  if r.kind='expense' then$old$,
      $new$  if r.kind='verification' and decision='approved' and r.private_data->>'verification_method'='profile' then
    raise exception 'Abre el panel actualizado para revisar los datos del sello' using errcode='22023';
  end if;
  if r.kind='expense' then$new$),
    ('public.dopmi_rescue_file_access(text,boolean)',
      $old$    if r.kind='expense' then$old$,
      $new$    if r.kind='verification' and r.private_data->>'verification_method'='profile' then return false; end if;
    if r.kind='expense' then$new$),
    ('public.dopmi_rescuer_profile_file_access(text,boolean)',
      $old$  if writing then return public.dopmi_actor_active() and item.owner_id=auth.uid() and item.status in ('draft','changes_requested','rejected','published') and (item.approved_snapshot->>'avatar_path') is distinct from object_name; end if;$old$,
      $new$  if writing then
    if not public.dopmi_actor_active() or item.owner_id is distinct from auth.uid() then return false; end if;
    perform private.dopmi_rescue_lock(item.owner_id);
    return item.status in ('draft','changes_requested','rejected','published')
      and (item.approved_snapshot->>'avatar_path') is distinct from object_name
      and not exists(select 1 from public.dopmi_rescue_records r
        where r.owner_id=item.owner_id and r.kind='verification' and r.status in ('submitted','approved')
          and r.private_data->>'verification_method'='profile' and r.private_data->>'avatar_path'=object_name);
  end if;$new$)
  ) as changes(signature,before_text,after_text) loop
    target:=to_regprocedure(patch.signature);
    if target is null then raise exception 'Rescuer seal: missing function %',patch.signature; end if;
    definition:=replace(pg_get_functiondef(target),E'\r\n',E'\n');
    if (length(definition)-length(replace(definition,patch.before_text,'')))/length(patch.before_text)<>1 then
      raise exception 'Rescuer seal: unexpected definition for %',patch.signature;
    end if;
    execute replace(definition,patch.before_text,patch.after_text);
  end loop;
end;
$migration$;
alter function public.dopmi_rescuer_profile_file_access(text,boolean) volatile;

revoke all on function private.dopmi_rescuer_seal_avatar(uuid,text),private.dopmi_rescuer_seal_evidence(uuid),
  private.dopmi_rescuer_seal_result(public.dopmi_rescue_records,jsonb),
  private.dopmi_rescuer_seal_validate(public.dopmi_rescue_records)
  from public,anon,authenticated,service_role;
revoke all on function public.dopmi_rescuer_seal_status(),public.dopmi_submit_rescuer_seal(),
  public.dopmi_review_rescuer_seal(uuid,integer,text,text,boolean) from public,anon,authenticated,service_role;
grant execute on function public.dopmi_rescuer_seal_status(),public.dopmi_submit_rescuer_seal(),
  public.dopmi_review_rescuer_seal(uuid,integer,text,text,boolean) to authenticated;

commit;
