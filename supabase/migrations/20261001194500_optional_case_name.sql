-- Case names may be empty; authorization, evidence and other submission requirements remain unchanged.
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
    required_public:=array['species','sex','age','story','city','state'];
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
