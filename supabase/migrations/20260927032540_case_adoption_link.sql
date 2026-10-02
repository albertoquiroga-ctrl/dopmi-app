begin;

alter table public.dopmi_adoptions
  add column rescue_case_id uuid references public.dopmi_rescue_records(id) on delete set null;
create unique index dopmi_adoptions_rescue_case
  on public.dopmi_adoptions(rescue_case_id) where rescue_case_id is not null;

create or replace function public.dopmi_save_adoption(payload jsonb,target_id uuid default null,expected_version integer default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); a public.dopmi_adoptions; photo text; linked_case uuid;
begin
  if jsonb_typeof(payload) is distinct from 'object' or char_length(payload::text)>16000 then
    raise exception 'Publicación inválida' using errcode='22023'; end if;
  if payload ? 'rescue_case_id' and nullif(payload->>'rescue_case_id','') is not null then
    begin linked_case:=(payload->>'rescue_case_id')::uuid;
    exception when invalid_text_representation then
      raise exception 'Caso vinculado inválido' using errcode='22023';
    end;
    if not exists(select 1 from public.dopmi_rescue_records r
      where r.id=linked_case and r.owner_id=actor and r.kind='case' and r.status='approved') then
      raise exception 'El caso aprobado no está disponible para vincular' using errcode='42501';
    end if;
  end if;
  if target_id is null then
    insert into public.dopmi_adoptions(owner_id,rescue_case_id) values(actor,linked_case) returning * into a;
  else
    select * into a from public.dopmi_adoptions where id=target_id for update;
    if not found or a.owner_id<>actor then raise exception 'Publicación no disponible' using errcode='42501'; end if;
    if expected_version is distinct from a.version then raise exception 'La publicación cambió. Vuelve a cargarla.' using errcode='40001'; end if;
    if a.status='submitted' then raise exception 'Retira la solicitud de revisión antes de editar.' using errcode='22023'; end if;
    linked_case:=case when payload ? 'rescue_case_id' then linked_case else a.rescue_case_id end;
  end if;
  update public.dopmi_adoptions set
    rescue_case_id=linked_case,
    pet_name=btrim(coalesce(payload->>'pet_name','')), species=coalesce(payload->>'species','dog'),
    sex=coalesce(payload->>'sex','female'), age_months=coalesce((payload->>'age_months')::integer,0),
    size=coalesce(payload->>'size','medium'), breed=btrim(coalesce(payload->>'breed','')),
    city=btrim(coalesce(payload->>'city','')),region=btrim(coalesce(payload->>'region','')),
    story=btrim(coalesce(payload->>'story','')), special_care=btrim(coalesce(payload->>'special_care','')),
    publisher_name=btrim(coalesce(payload->>'publisher_name','')),publisher_bio=btrim(coalesce(payload->>'publisher_bio','')),
    vaccinated=(payload->>'vaccinated')::boolean,sterilized=(payload->>'sterilized')::boolean,
    social_dogs=(payload->>'social_dogs')::boolean,social_cats=(payload->>'social_cats')::boolean,social_children=(payload->>'social_children')::boolean,
    photos=coalesce(array(select jsonb_array_elements_text(payload->'photos')),'{}'::text[]),
    status='draft',submitted_at=null,version=case when target_id is null then 1 else a.version+1 end,updated_at=now()
  where id=a.id returning * into a;
  foreach photo in array a.photos loop
    if photo is null or photo not like actor::text||'/'||a.id::text||'/%' then
      raise exception 'La foto no pertenece a esta publicación' using errcode='22023'; end if;
  end loop;
  return to_jsonb(a);
exception when unique_violation then
  raise exception 'Este caso ya tiene una publicación de adopción vinculada' using errcode='23505';
end;
$$;

revoke all on function public.dopmi_save_adoption(jsonb,uuid,integer) from public;
grant execute on function public.dopmi_save_adoption(jsonb,uuid,integer) to authenticated;

commit;
