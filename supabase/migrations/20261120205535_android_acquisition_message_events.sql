begin;

-- Existing messages remain unknown. Only the server's contact/composer paths
-- choose a prospective origin; neither public RPC accepts this field.
alter table public.dopmi_messages add column origin text not null default 'unknown'
  check (origin in ('unknown', 'automatic_greeting', 'user'));
revoke insert(origin), update(origin) on public.dopmi_messages from public, anon, authenticated;

create table private.dopmi_android_acquisition_events (
  actor_id uuid not null references private.dopmi_android_rescuer_acquisition(actor_id) on delete cascade,
  event_type text not null check (event_type in ('automatic_greeting', 'first_user_message', 'first_rescuer_reply')),
  observed_at timestamptz not null,
  primary key(actor_id, event_type)
);
alter table private.dopmi_android_acquisition_events enable row level security;
revoke all on private.dopmi_android_acquisition_events from public, anon, authenticated, service_role;

create function private.dopmi_observe_android_message_acquisition() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  thread public.dopmi_threads;
  source private.dopmi_android_rescuer_acquisition;
  milestone text;
  observed timestamptz;
  consented boolean;
begin
  if new.origin = 'unknown' then return null; end if;
  select * into thread from public.dopmi_threads where id = new.thread_id;
  if new.sender_id = thread.adopter_id then
    milestone := case new.origin when 'automatic_greeting' then 'automatic_greeting'
      when 'user' then 'first_user_message' end;
  elsif new.sender_id = thread.owner_id and new.origin = 'user' and exists (
    select 1 from public.dopmi_messages m where m.thread_id = thread.id
      and m.sender_id = thread.adopter_id and m.id <> new.id
  ) then
    -- A human reply may answer an automatic greeting, text, photo, or legacy
    -- inbound message. We never infer the inbound message's origin from text.
    milestone := 'first_rescuer_reply';
  end if;
  if milestone is null then return null; end if;

  -- The sender RPC already holds the thread lock. Enrollment and opt-out take
  -- the same consent row before touching the source. Neither takes a thread
  -- lock, so this adds no inverse thread/consent lock order.
  select m.consent into consented from private.dopmi_adoption_measurement m
    where m.actor_id = new.sender_id for update;
  if not found or not consented then return null; end if;
  -- A profile-deletion trigger can remove the source without the consent lock.
  -- Hold a key-share lock so its cascade either wins before this lookup or
  -- removes the milestone after this transaction; measurement cannot break send.
  select * into source from private.dopmi_android_rescuer_acquisition s
    where s.actor_id = new.sender_id for key share;
  if not found then return null; end if;
  observed := clock_timestamp();
  if observed < source.attributed_at or observed >= source.clicked_at + interval '336 hours' then
    return null;
  end if;
  insert into private.dopmi_android_acquisition_events(actor_id, event_type, observed_at)
    values(new.sender_id, milestone, observed) on conflict(actor_id, event_type) do nothing;
  return null;
end;
$$;
create trigger dopmi_observe_android_message_acquisition
after insert on public.dopmi_messages
for each row execute function private.dopmi_observe_android_message_acquisition();

-- This is the existing send implementation with one server-only argument.
-- Keep participant checks, the shared photo/thread lock, UUID retry semantics,
-- attachment authorization and the single notification in the same transaction.
create function private.dopmi_send_message_with_origin(
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
    return to_jsonb(m);
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
  insert into public.dopmi_messages(id, thread_id, sender_id, body, attachment_path, origin)
    values(message_id, t.id, actor, body_value, photo, message_origin) returning * into m;
  update public.dopmi_threads set updated_at = now() where id = t.id;
  insert into public.dopmi_notifications(user_id, kind, post_id, thread_id, source_id, title)
    values(recipient, 'message', t.post_id, t.id, m.id, 'Tienes un nuevo mensaje sobre ' || t.pet_name);
  return to_jsonb(m);
end;
$$;

create or replace function public.dopmi_send_message_v2(
  thread_id uuid, message_id uuid, message_body text, attachment_path text default null
) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  return private.dopmi_send_message_with_origin(thread_id, message_id, message_body, attachment_path, 'user');
end;
$$;

-- send_message(uuid,uuid,text) retains its validation and delegates to v2.
create or replace function public.dopmi_start_adoption_contact(post_id uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare actor uuid := private.dopmi_require_actor(); a public.dopmi_adoptions; result uuid;
begin
  select * into a from public.dopmi_adoptions where id = $1 for update;
  if not found or a.status <> 'published' or a.owner_id = actor or not exists(
    select 1 from public.profiles where id = a.owner_id and account_status = 'active') then
    raise exception 'Esta publicación no está disponible para contacto' using errcode = '22023';
  end if;
  insert into public.dopmi_threads(post_id, owner_id, adopter_id, pet_name)
    values(a.id, a.owner_id, actor, a.pet_name)
    on conflict on constraint dopmi_threads_post_id_adopter_id_key do nothing returning id into result;
  if result is not null then
    perform private.dopmi_send_message_with_origin(result, gen_random_uuid(),
      '¡Hola! 👋 Me encantó ' || a.pet_name || ', me gustaría saber un poquito más sobre ' ||
      case when a.sex = 'female' then 'ella' else 'él' end || ' 🐾', null, 'automatic_greeting');
  else
    select id into result from public.dopmi_threads t where t.post_id = $1 and t.adopter_id = actor;
  end if;
  return result;
end;
$$;

revoke all on function private.dopmi_send_message_with_origin(uuid, uuid, text, text, text),
  private.dopmi_observe_android_message_acquisition()
  from public, anon, authenticated, service_role;
-- CREATE OR REPLACE preserves the existing public RPC ACLs and signatures.

commit;
