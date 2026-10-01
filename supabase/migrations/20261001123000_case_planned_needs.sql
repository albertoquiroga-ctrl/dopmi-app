-- Planned needs are moderated case content, not payable expenses or funded balances.
-- Existing legacy text and all save ownership/version/state checks remain intact.
create function private.dopmi_case_fields(data jsonb) returns jsonb
language plpgsql immutable set search_path='' as $$
declare normalized jsonb; items jsonb; item jsonb; seen text[]:='{}'; id text;
begin
  if jsonb_typeof(data) is distinct from 'object' or octet_length(data::text)>40000 then
    raise exception 'Campos del caso inválidos' using errcode='22023';
  end if;
  normalized:=private.dopmi_rescue_fields(data-'need_items',array['pet_name','species','sex','age','story','city','state','need']);
  if not data ? 'need_items' then return normalized; end if;
  items:=data->'need_items';
  if jsonb_typeof(items) is distinct from 'array' or jsonb_array_length(items)>20 then
    raise exception 'Necesidades inválidas' using errcode='22023';
  end if;
  for item in select value from jsonb_array_elements(items) loop
    id:=item->>'id';
    if jsonb_typeof(item) is distinct from 'object'
      or (item-'id'-'type'-'title'-'amount_cents'-'detail'-'urgent')<>'{}'::jsonb
      or jsonb_typeof(item->'id') is distinct from 'string'
      or coalesce(id,'') !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      or id=any(seen)
      or jsonb_typeof(item->'type') is distinct from 'string'
      or coalesce(item->>'type','') not in ('food','medicine','veterinary')
      or jsonb_typeof(item->'title') is distinct from 'string'
      or coalesce(char_length(btrim(item->>'title')),0) not between 1 and 150
      or jsonb_typeof(item->'amount_cents') is distinct from 'number'
      or coalesce(item->>'amount_cents','') !~ '^[0-9]{1,9}$'
      or jsonb_typeof(item->'detail') is distinct from 'string'
      or char_length(item->>'detail')>1000
      or jsonb_typeof(item->'urgent') is distinct from 'boolean' then
      raise exception 'Revisa los datos de la necesidad' using errcode='22023';
    end if;
    if (item->>'amount_cents')::bigint not between 1 and 100000000 then
      raise exception 'Revisa el costo estimado de la necesidad' using errcode='22023';
    end if;
    seen:=array_append(seen,id);
  end loop;
  return normalized||jsonb_build_object('need_items',items);
end;
$$;
revoke all on function private.dopmi_case_fields(jsonb) from public,anon,authenticated,service_role;

create or replace function public.dopmi_save_rescue(record_kind text, public_fields jsonb, private_fields jsonb, attachments jsonb,
  target_id uuid default null, expected_version integer default null, case_id uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid; r public.dopmi_rescue_records; c public.dopmi_rescue_records; pub text[]; priv text[]; roles text[];
begin
  actor:=private.dopmi_require_actor(); perform private.dopmi_rescue_lock(actor);
  if record_kind is null or record_kind not in ('verification','case','expense') then raise exception 'Tipo inválido' using errcode='22023'; end if;
  if target_id is null then
    if record_kind='verification' and exists(select 1 from public.dopmi_rescue_records where owner_id=actor and kind='verification') then
      raise exception 'Ya tienes una verificación. Abre la solicitud existente' using errcode='40001'; end if;
    insert into public.dopmi_rescue_records(owner_id,kind,parent_id) values(actor,record_kind,case_id) returning * into r;
  else
    select * into r from public.dopmi_rescue_records where id=target_id for update;
    if not found or r.owner_id<>actor then raise exception 'Solicitud no disponible' using errcode='42501'; end if;
    if r.version is distinct from expected_version then raise exception 'La solicitud cambió. Recarga antes de continuar' using errcode='40001'; end if;
    if r.kind<>record_kind or r.parent_id is distinct from case_id or r.status not in ('draft','changes_requested','rejected') then
      raise exception 'Esta solicitud no se puede editar en su estado actual' using errcode='22023'; end if;
  end if;
  if r.kind='expense' then
    select * into c from public.dopmi_rescue_records where id=r.parent_id;
    if not found or c.kind<>'case' or c.owner_id<>actor or c.status='closed' then
      raise exception 'Selecciona uno de tus casos abiertos' using errcode='22023'; end if;
  end if;
  if record_kind='verification' then
    pub:=array['public_name','bio','city','state']; priv:=array['legal_name','phone','experience','social_url','identity_type']; roles:=array['identity','address'];
  elsif record_kind='case' then
    pub:=array['pet_name','species','sex','age','story','city','state','need']; priv:='{}'; roles:=array['public'];
  else
    pub:=array['title','description','category','round_label']; priv:=array['paid_on','vendor','amount_cents','receipt_reference','urgency_reason']; roles:=array['receipt','proof','public'];
  end if;
  if record_kind='case' then
    public_fields:=private.dopmi_case_fields(public_fields);
  else
    public_fields:=private.dopmi_rescue_fields(public_fields,pub);
  end if;
  private_fields:=private.dopmi_rescue_fields(private_fields,priv);
  if jsonb_typeof(attachments) is distinct from 'array' or jsonb_array_length(attachments)>12
    or exists(select 1 from jsonb_array_elements(attachments) f where jsonb_typeof(f)<>'object'
      or (f-'path'-'role')<>'{}'::jsonb or not coalesce(f->>'role','')=any(roles)
      or coalesce(f->>'path','') !~ ('^'||actor::text||'/'||r.id::text||'/[0-9a-f-]{36}\.(jpg|png|webp|pdf)$')
      or (f->>'role'='public' and f->>'path' !~ '\.(jpg|png|webp)$'))
    or (select count(*) from jsonb_array_elements(attachments))<>(select count(distinct f->>'path') from jsonb_array_elements(attachments) f) then
    raise exception 'Archivos o permisos de publicación inválidos' using errcode='22023'; end if;
  update public.dopmi_rescue_records set public_data=public_fields,private_data=private_fields,files=attachments,
    version=version+1,updated_at=now(),status='draft' where id=r.id returning * into r;
  return to_jsonb(r);
end;
$$;

-- Planned needs are optional, matching publication without financial support.
create or replace function private.dopmi_rescue_validate(r public.dopmi_rescue_records) returns void
language plpgsql security definer set search_path='' as $$
declare required_public text[]; required_private text[]; roles text[]; field text;
begin
  if r.kind='verification' then
    required_public:=array['public_name','bio','city','state'];
    required_private:=array['legal_name','phone','experience','social_url','identity_type'];
    roles:=array['identity','address'];
    if coalesce(r.private_data->>'identity_type','') not in ('ine','passport','license')
      or coalesce(r.private_data->>'social_url','') !~ '^https://[^ /]+/.+'
      or coalesce(r.private_data->>'phone','') !~ '^\+?[0-9 ()-]{10,20}$' then
      raise exception 'Revisa identificación, teléfono y enlace social HTTPS' using errcode='22023'; end if;
  elsif r.kind='case' then
    required_public:=array['pet_name','species','sex','age','story','city','state'];
    perform private.dopmi_case_fields(r.public_data); required_private:='{}'; roles:=array['public'];
    if coalesce(r.public_data->>'species','') not in ('dog','cat') or coalesce(r.public_data->>'sex','') not in ('male','female','unknown') then
      raise exception 'Revisa especie y sexo' using errcode='22023'; end if;
  else
    required_public:=array['title','description','category'];
    required_private:=array['paid_on','vendor','amount_cents','receipt_reference']; roles:=array['receipt','proof'];
    if coalesce(r.public_data->>'category','') not in ('food','veterinary','medicine','other') then
      raise exception 'Selecciona la necesidad que cubrió el gasto' using errcode='22023'; end if;
    if r.public_data->>'category'='food' then required_public:=required_public||'round_label'::text; end if;
    if coalesce(r.private_data->>'amount_cents','') !~ '^[0-9]{1,9}$' then
      raise exception 'Escribe el gasto en centavos enteros' using errcode='22023'; end if;
    if (r.private_data->>'amount_cents')::bigint not between 1 and 100000000 then
      raise exception 'El gasto debe ser mayor a cero y hasta $1,000,000' using errcode='22023'; end if;
    begin
      if coalesce(r.private_data->>'paid_on','') !~ '^\d{4}-\d{2}-\d{2}$'
        or (r.private_data->>'paid_on')::date > (now() at time zone 'America/Mexico_City')::date then
        raise exception 'Fecha de pago inválida'; end if;
    exception when others then raise exception 'Indica una fecha válida de un gasto ya pagado' using errcode='22023'; end;
    -- Catch the same receipt submitted twice, including separate food rounds.
    if exists(select 1 from public.dopmi_rescue_records x where x.kind='expense' and x.owner_id=r.owner_id and x.id<>r.id
      and x.status in ('submitted','approved') and lower(x.private_data->>'vendor')=lower(r.private_data->>'vendor')
      and lower(x.private_data->>'receipt_reference')=lower(r.private_data->>'receipt_reference')
      and x.private_data->>'paid_on'=r.private_data->>'paid_on') then
      raise exception 'Este comprobante ya tiene una solicitud en revisión o aprobada' using errcode='22023'; end if;
  end if;
  foreach field in array required_public loop
    if coalesce(char_length(btrim(r.public_data->>field)),0)<2 then
      raise exception 'Completa la información para publicación' using errcode='22023'; end if;
  end loop;
  foreach field in array required_private loop
    if coalesce(char_length(btrim(r.private_data->>field)),0)<1 then
      raise exception 'Completa los datos privados de revisión' using errcode='22023'; end if;
  end loop;
  foreach field in array roles loop
    if not exists(select 1 from jsonb_array_elements(r.files) f where f->>'role'=field) then
      raise exception 'Falta adjuntar evidencia: %',field using errcode='22023'; end if;
  end loop;
  if exists(select 1 from jsonb_array_elements(r.files) f where not exists(select 1 from storage.objects o
    where o.bucket_id='dopmi-rescue-evidence' and o.name=f->>'path')) then
    raise exception 'Hay un archivo que no terminó de subir. Vuelve a adjuntarlo' using errcode='22023'; end if;
end;
$$;
