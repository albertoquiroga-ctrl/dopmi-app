-- Optional explicitly selected case size; preserve old clients and review rules.
begin;
create or replace function private.dopmi_case_fields(data jsonb) returns jsonb
language plpgsql immutable set search_path='' as $$
declare normalized jsonb; items jsonb; item jsonb; seen text[]:='{}'; id text;
begin
  if jsonb_typeof(data) is distinct from 'object' or octet_length(data::text)>40000 then
    raise exception 'Campos del caso inválidos' using errcode='22023';
  end if;
  normalized:=private.dopmi_rescue_fields(data-'need_items'-'size',array['pet_name','species','sex','age','story','city','state','need']);
  if data ? 'size' and coalesce(data->>'size','')<>'' then
    if jsonb_typeof(data->'size') is distinct from 'string' or data->>'size' not in ('small','medium','large') then
      raise exception 'Tamaño inválido' using errcode='22023'; end if;
    normalized:=normalized||jsonb_build_object('size',data->>'size');
  end if;
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
    if not public_fields ? 'size' and r.public_data ? 'size' then
      public_fields:=public_fields||jsonb_build_object('size',r.public_data->>'size');
    end if;
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


commit;
