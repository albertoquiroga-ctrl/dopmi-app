begin;

alter table public.dopmi_messages add column attachment_path text;
alter table public.dopmi_messages drop constraint dopmi_messages_body_check;
alter table public.dopmi_messages add constraint dopmi_messages_content_check
  check(char_length(body)<=2000 and (char_length(btrim(body))>0 or attachment_path is not null));
create unique index dopmi_messages_attachment on public.dopmi_messages(attachment_path) where attachment_path is not null;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('dopmi-chat-photos','dopmi-chat-photos',false,5242880,array['image/jpeg']);

create function public.dopmi_chat_photo_access(object_name text,operation text default 'read') returns boolean
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=auth.uid(); thread_key uuid; message_key uuid; t public.dopmi_threads; published boolean;
begin
  if not public.dopmi_actor_active() or operation not in('read','insert','delete')
    or object_name is null or object_name !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.jpg$' then return false; end if;
  thread_key:=split_part(object_name,'/',2)::uuid;
  message_key:=split_part(split_part(object_name,'/',3),'.',1)::uuid;
  select * into t from public.dopmi_threads where id=thread_key;
  if not found or actor not in(t.owner_id,t.adopter_id) or split_part(object_name,'/',1) not in(t.owner_id::text,t.adopter_id::text) then return false; end if;
  if operation='delete' then
    -- Share send's thread lock. VOLATILE queries recheck publication with a fresh
    -- snapshot after waiting, rather than the DELETE statement's older snapshot.
    select * into t from public.dopmi_threads where id=thread_key for update;
    if not found or actor not in(t.owner_id,t.adopter_id) then return false; end if;
  end if;
  published:=exists(select 1 from public.dopmi_messages m where m.id=message_key and m.thread_id=t.id and m.attachment_path=object_name and m.sender_id::text=split_part(object_name,'/',1));
  if operation='read' then return published or split_part(object_name,'/',1)=actor::text; end if;
  if published or exists(select 1 from public.dopmi_messages where id=message_key) or split_part(object_name,'/',1)<>actor::text then return false; end if;
  if operation='delete' then return true; end if;
  return t.status='active' and exists(select 1 from public.profiles p where p.id=case when actor=t.owner_id then t.adopter_id else t.owner_id end and p.account_status='active');
end;
$$;
revoke all on function public.dopmi_chat_photo_access(text,text) from public,anon,authenticated;
grant execute on function public.dopmi_chat_photo_access(text,text) to authenticated;

create policy dopmi_chat_photos_read on storage.objects for select to authenticated
  using(bucket_id='dopmi-chat-photos' and public.dopmi_chat_photo_access(name,'read'));
create policy dopmi_chat_photos_insert on storage.objects for insert to authenticated
  with check(bucket_id='dopmi-chat-photos' and public.dopmi_chat_photo_access(name,'insert'));
create policy dopmi_chat_photos_delete on storage.objects for delete to authenticated
  using(bucket_id='dopmi-chat-photos' and public.dopmi_chat_photo_access(name,'delete'));
create policy dopmi_chat_photos_read_boundary on storage.objects as restrictive for select to authenticated
  using(bucket_id<>'dopmi-chat-photos' or public.dopmi_chat_photo_access(name,'read'));
create policy dopmi_chat_photos_insert_boundary on storage.objects as restrictive for insert to authenticated
  with check(bucket_id<>'dopmi-chat-photos' or public.dopmi_chat_photo_access(name,'insert'));
create policy dopmi_chat_photos_delete_boundary on storage.objects as restrictive for delete to authenticated
  using(bucket_id<>'dopmi-chat-photos' or public.dopmi_chat_photo_access(name,'delete'));
create policy dopmi_chat_photos_update_boundary on storage.objects as restrictive for update to authenticated
  using(bucket_id<>'dopmi-chat-photos') with check(bucket_id<>'dopmi-chat-photos');

create function public.dopmi_send_message_v2(thread_id uuid,message_id uuid,message_body text,attachment_path text default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); t public.dopmi_threads; m public.dopmi_messages; recipient uuid; body_value text:=btrim(coalesce(message_body,'')); photo text:=nullif(attachment_path,'');
begin
  select * into t from public.dopmi_threads where id=thread_id for update;
  if not found or actor not in(t.owner_id,t.adopter_id) then raise exception 'Conversación no disponible' using errcode='42501'; end if;
  select * into m from public.dopmi_messages where id=message_id;
  if found then
    if m.thread_id<>t.id or m.sender_id<>actor or m.body is distinct from body_value or m.attachment_path is distinct from photo then
      raise exception 'El identificador del mensaje ya se utilizó' using errcode='22023'; end if;
    return to_jsonb(m);
  end if;
  recipient:=case when actor=t.owner_id then t.adopter_id else t.owner_id end;
  if t.status<>'active' or not exists(select 1 from public.profiles where id=recipient and account_status='active') then
    raise exception 'La conversación está cerrada o la cuenta no está disponible' using errcode='22023'; end if;
  if message_id is null or char_length(body_value)>2000 or (body_value='' and photo is null) then
    raise exception 'Escribe un mensaje o adjunta una foto' using errcode='22023'; end if;
  if photo is not null and (photo<>actor::text||'/'||t.id::text||'/'||message_id::text||'.jpg'
    or not exists(select 1 from storage.objects where bucket_id='dopmi-chat-photos' and name=photo)) then
    raise exception 'La foto no está disponible o no terminó de subir' using errcode='22023'; end if;
  insert into public.dopmi_messages(id,thread_id,sender_id,body,attachment_path) values(message_id,t.id,actor,body_value,photo) returning * into m;
  update public.dopmi_threads set updated_at=now() where id=t.id;
  insert into public.dopmi_notifications(user_id,kind,post_id,thread_id,source_id,title)
    values(recipient,'message',t.post_id,t.id,m.id,'Tienes un nuevo mensaje sobre '||t.pet_name);
  return to_jsonb(m);
end;
$$;
revoke all on function public.dopmi_send_message_v2(uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function public.dopmi_send_message_v2(uuid,uuid,text,text) to authenticated;

create or replace function public.dopmi_send_message(thread_id uuid,message_id uuid,message_body text) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
  if message_body is null or char_length(btrim(message_body)) not between 1 and 2000 then
    raise exception 'Escribe un mensaje de 1 a 2000 caracteres' using errcode='22023'; end if;
  return public.dopmi_send_message_v2(thread_id,message_id,message_body,null);
end;
$$;
commit;
