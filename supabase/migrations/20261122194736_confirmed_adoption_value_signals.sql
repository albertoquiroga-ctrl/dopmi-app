begin;

-- Prospective server evidence, never a reconstruction from timestamps or text.
-- NULL means an unknown legacy owner message, which conservatively prevents a
-- later message from being attributed as that thread's first owner reply.
alter table public.dopmi_messages add column is_adoption_reply boolean;
revoke insert(is_adoption_reply), update(is_adoption_reply)
  on public.dopmi_messages from public, anon, authenticated, service_role;

-- Return event names only. These are global outcomes, independent of acquisition
-- cohorts, and carry no actor, post, thread, message, content or attribution data.
-- Callers take the business row lock first, preserving thread/post -> consent.
create function private.dopmi_confirmed_adoption_signals(actor uuid, signal_name text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare consented boolean;
begin
  if signal_name is null or signal_name not in
    ('adoption_contact_created', 'rescuer_first_reply', 'adoption_marked_adopted') then
    raise exception 'Señal no válida' using errcode = '22023';
  end if;
  select m.consent into consented from private.dopmi_adoption_measurement m
    where m.actor_id = actor for update;
  if not found or not consented then return '[]'::jsonb; end if;
  return jsonb_build_array(signal_name);
end;
$$;

-- One implementation owns validation, participant/photo authorization, UUID
-- retries, the single notification and prospective reply classification. Both
-- the old message JSON API and the additive envelope delegate to it.
create function private.dopmi_send_message_result(
  thread_id uuid, message_id uuid, message_body text, attachment_path text, message_origin text
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.dopmi_require_actor();
  t public.dopmi_threads;
  m public.dopmi_messages;
  recipient uuid;
  body_value text := btrim(coalesce(message_body, ''));
  photo text := nullif(attachment_path, '');
  reply_value boolean;
  first_reply boolean;
  signals jsonb := '[]'::jsonb;
begin
  select * into t from public.dopmi_threads where id = thread_id for update;
  if not found or actor not in(t.owner_id, t.adopter_id) then
    raise exception 'Conversación no disponible' using errcode = '42501';
  end if;
  select * into m from public.dopmi_messages where id = message_id;
  if found then
    if m.thread_id <> t.id or m.sender_id <> actor or m.body is distinct from body_value
      or m.attachment_path is distinct from photo then
      raise exception 'El identificador del mensaje ya se utilizó' using errcode = '22023';
    end if;
    -- A successful retry never mutates its flag, notifies twice or re-emits.
    return jsonb_build_object('message', to_jsonb(m) - 'is_adoption_reply', 'signals', signals);
  end if;
  recipient := case when actor = t.owner_id then t.adopter_id else t.owner_id end;
  if t.status <> 'active' or not exists(select 1 from public.profiles where id = recipient and account_status = 'active') then
    raise exception 'La conversación está cerrada o la cuenta no está disponible' using errcode = '22023';
  end if;
  if message_id is null or char_length(body_value) > 2000 or (body_value = '' and photo is null) then
    raise exception 'Escribe un mensaje o adjunta una foto' using errcode = '22023';
  end if;
  if photo is not null and (photo <> actor::text || '/' || t.id::text || '/' || message_id::text || '.jpg'
    or not exists(select 1 from storage.objects where bucket_id = 'dopmi-chat-photos' and name = photo)) then
    raise exception 'La foto no está disponible o no terminó de subir' using errcode = '22023';
  end if;
  if message_origin is null or message_origin not in('automatic_greeting', 'user')
    or (message_origin = 'automatic_greeting' and actor <> t.adopter_id) then
    raise exception 'Origen de mensaje no válido' using errcode = '22023';
  end if;
  -- The thread lock serializes incoming entries, owner sends and their retries.
  -- A greeting, text, photo or legacy adopter entry can be answered. Prior owner
  -- false means a send before any incoming entry; true/NULL prevents reattribution.
  reply_value := actor = t.owner_id and message_origin = 'user' and exists(
    select 1 from public.dopmi_messages prior
      where prior.thread_id = t.id and prior.sender_id = t.adopter_id);
  first_reply := reply_value and not exists(
    select 1 from public.dopmi_messages prior where prior.thread_id = t.id
      and prior.sender_id = t.owner_id and prior.is_adoption_reply is distinct from false);
  insert into public.dopmi_messages(id, thread_id, sender_id, body, attachment_path, origin, is_adoption_reply)
    values(message_id, t.id, actor, body_value, photo, message_origin, reply_value) returning * into m;
  update public.dopmi_threads set updated_at = now() where id = t.id;
  insert into public.dopmi_notifications(user_id, kind, post_id, thread_id, source_id, title)
    values(recipient, 'message', t.post_id, t.id, m.id, 'Tienes un nuevo mensaje sobre ' || t.pet_name);
  if first_reply then
    signals := private.dopmi_confirmed_adoption_signals(actor, 'rescuer_first_reply');
  end if;
  return jsonb_build_object('message', to_jsonb(m) - 'is_adoption_reply', 'signals', signals);
end;
$$;

create or replace function private.dopmi_send_message_with_origin(
  thread_id uuid, message_id uuid, message_body text, attachment_path text, message_origin text
) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  return private.dopmi_send_message_result(thread_id, message_id, message_body, attachment_path, message_origin) -> 'message';
end;
$$;

create function public.dopmi_send_message_v3(
  thread_id uuid, message_id uuid, message_body text, attachment_path text default null
) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  return private.dopmi_send_message_result(thread_id, message_id, message_body, attachment_path, 'user');
end;
$$;

create function private.dopmi_start_adoption_contact_result(post_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.dopmi_require_actor();
  a public.dopmi_adoptions;
  result uuid;
  created_new boolean;
  signals jsonb := '[]'::jsonb;
begin
  select * into a from public.dopmi_adoptions where id = $1 for update;
  if not found or a.status <> 'published' or a.owner_id = actor or not exists(
    select 1 from public.profiles where id = a.owner_id and account_status = 'active') then
    raise exception 'Esta publicación no está disponible para contacto' using errcode = '22023';
  end if;
  insert into public.dopmi_threads(post_id, owner_id, adopter_id, pet_name)
    values(a.id, a.owner_id, actor, a.pet_name)
    on conflict on constraint dopmi_threads_post_id_adopter_id_key do nothing returning id into result;
  created_new := result is not null;
  if created_new then
    perform private.dopmi_send_message_with_origin(result, gen_random_uuid(),
      '¡Hola! 👋 Me encantó ' || a.pet_name || ', me gustaría saber un poquito más sobre ' ||
      case when a.sex = 'female' then 'ella' else 'él' end || ' 🐾', null, 'automatic_greeting');
    signals := private.dopmi_confirmed_adoption_signals(actor, 'adoption_contact_created');
  else
    select id into result from public.dopmi_threads t where t.post_id = $1 and t.adopter_id = actor;
  end if;
  return jsonb_build_object('thread_id', result, 'created_new', created_new, 'signals', signals);
end;
$$;

create or replace function public.dopmi_start_adoption_contact(post_id uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
begin
  return (private.dopmi_start_adoption_contact_result(post_id) ->> 'thread_id')::uuid;
end;
$$;

create function public.dopmi_start_adoption_contact_v2(post_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  return private.dopmi_start_adoption_contact_result(post_id);
end;
$$;

create function public.dopmi_close_adoption_v2(post_id uuid, expected_version integer, reason text,
  dopmi_support boolean default null, description text default '') returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.dopmi_require_actor();
  a public.dopmi_adoptions;
  prior_adopted boolean;
  result jsonb;
  signals jsonb := '[]'::jsonb;
begin
  select * into a from public.dopmi_adoptions where id = post_id for update;
  if not found or a.owner_id <> actor then
    raise exception 'Publicación no disponible' using errcode = '42501';
  end if;
  -- Existing closure records are the evidence. No history is inferred or
  -- backfilled. Reactivation and intervening other closures never reset it.
  prior_adopted := exists(select 1 from private.dopmi_adoption_closures c
    where c.post_id = a.id and c.reason = 'adopted');
  result := public.dopmi_close_adoption(post_id, expected_version, reason, dopmi_support, description);
  if reason = 'adopted' and result ->> 'status' = 'adopted' and not prior_adopted then
    signals := private.dopmi_confirmed_adoption_signals(actor, 'adoption_marked_adopted');
  end if;
  return jsonb_build_object('adoption', result, 'signals', signals);
end;
$$;

-- The internal marker must not change the established message JSON shape.
create or replace function public.dopmi_thread_messages(
  thread_id uuid, before_time timestamptz default null, before_id uuid default null
) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.dopmi_actor_active() or not exists(select 1 from public.dopmi_threads t where t.id = $1
    and auth.uid() in(t.owner_id, t.adopter_id)) then
    raise exception 'Conversación no disponible' using errcode = '42501';
  end if;
  return coalesce((select jsonb_agg(to_jsonb(rows) - 'is_adoption_reply' order by rows.created_at, rows.id) from (
    select * from public.dopmi_messages m where m.thread_id = $1
      and (before_time is null or (m.created_at, m.id) < (before_time, before_id))
    order by m.created_at desc, m.id desc limit 40) rows), '[]'::jsonb);
end;
$$;

revoke all on function private.dopmi_confirmed_adoption_signals(uuid, text),
  private.dopmi_send_message_result(uuid, uuid, text, text, text),
  private.dopmi_send_message_with_origin(uuid, uuid, text, text, text),
  private.dopmi_start_adoption_contact_result(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.dopmi_start_adoption_contact_v2(uuid),
  public.dopmi_send_message_v3(uuid, uuid, text, text),
  public.dopmi_close_adoption_v2(uuid, integer, text, boolean, text)
  from public, anon, authenticated, service_role;
grant execute on function public.dopmi_start_adoption_contact_v2(uuid),
  public.dopmi_send_message_v3(uuid, uuid, text, text),
  public.dopmi_close_adoption_v2(uuid, integer, text, boolean, text) to authenticated;
-- CREATE OR REPLACE preserves every legacy RPC signature, default and ACL.

commit;
