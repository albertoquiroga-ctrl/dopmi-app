begin;
create table public.dopmi_threads (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.dopmi_adoptions(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  adopter_id uuid not null references public.profiles(id) on delete cascade,
  pet_name text not null,
  status text not null default 'active' check(status in ('active','closed')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique(post_id,adopter_id), check(owner_id<>adopter_id)
);
create index dopmi_threads_owner on public.dopmi_threads(owner_id,updated_at desc,id);
create index dopmi_threads_adopter on public.dopmi_threads(adopter_id,updated_at desc,id);
create table public.dopmi_messages (
  id uuid primary key,
  thread_id uuid not null references public.dopmi_threads(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check(char_length(body) between 1 and 2000),
  created_at timestamptz not null default now()
);
create index dopmi_messages_thread on public.dopmi_messages(thread_id,created_at desc,id desc);
alter table public.dopmi_notifications add constraint dopmi_notifications_thread_fkey
  foreign key(thread_id) references public.dopmi_threads(id) on delete cascade;
alter table public.dopmi_threads enable row level security;
alter table public.dopmi_messages enable row level security;
revoke all on public.dopmi_threads,public.dopmi_messages from public,anon,authenticated;
grant select on public.dopmi_threads,public.dopmi_messages to authenticated;
create policy dopmi_threads_participant on public.dopmi_threads for select to authenticated
  using(public.dopmi_actor_active() and (owner_id=(select auth.uid()) or adopter_id=(select auth.uid())));
create policy dopmi_messages_participant on public.dopmi_messages for select to authenticated
  using(public.dopmi_actor_active() and exists(select 1 from public.dopmi_threads t where t.id=thread_id
    and (t.owner_id=(select auth.uid()) or t.adopter_id=(select auth.uid()))));

create function public.dopmi_start_thread(post_id uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); a public.dopmi_adoptions; result uuid;
begin
  select * into a from public.dopmi_adoptions where id=post_id for update;
  if not found or a.status<>'published' or a.owner_id=actor or not exists(
    select 1 from public.profiles where id=a.owner_id and account_status='active') then
    raise exception 'Esta publicación no está disponible para contacto' using errcode='22023'; end if;
  insert into public.dopmi_threads(post_id,owner_id,adopter_id,pet_name) values(a.id,a.owner_id,actor,a.pet_name)
    on conflict on constraint dopmi_threads_post_id_adopter_id_key do nothing;
  select id into result from public.dopmi_threads t where t.post_id=$1 and t.adopter_id=actor;
  return result;
end;
$$;

create function public.dopmi_send_message(thread_id uuid,message_id uuid,message_body text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); t public.dopmi_threads; m public.dopmi_messages; recipient uuid;
begin
  select * into t from public.dopmi_threads where id=thread_id for update;
  if not found or actor not in (t.owner_id,t.adopter_id) then
    raise exception 'Conversación no disponible' using errcode='42501'; end if;
  select * into m from public.dopmi_messages where id=message_id;
  if found then
    if m.thread_id<>t.id or m.sender_id<>actor or m.body is distinct from btrim(message_body) then
      raise exception 'El identificador del mensaje ya se utilizó' using errcode='22023'; end if;
    return to_jsonb(m);
  end if;
  recipient:=case when actor=t.owner_id then t.adopter_id else t.owner_id end;
  if t.status<>'active' or not exists(select 1 from public.profiles where id=recipient and account_status='active') then
    raise exception 'La conversación está cerrada o la cuenta no está disponible' using errcode='22023'; end if;
  if message_id is null or message_body is null or char_length(btrim(message_body)) not between 1 and 2000 then
    raise exception 'Escribe un mensaje de 1 a 2000 caracteres' using errcode='22023'; end if;
  insert into public.dopmi_messages(id,thread_id,sender_id,body) values(message_id,t.id,actor,btrim(message_body)) returning * into m;
  update public.dopmi_threads set updated_at=now() where id=t.id;
  insert into public.dopmi_notifications(user_id,kind,post_id,thread_id,source_id,title)
    values(recipient,'message',t.post_id,t.id,m.id,'Tienes un nuevo mensaje sobre '||t.pet_name);
  return to_jsonb(m);
end;
$$;

create function public.dopmi_list_threads(page_number integer default 1) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid; result jsonb;
begin
  if not public.dopmi_actor_active() then raise exception 'Cuenta activa y confirmada requerida' using errcode='42501'; end if;
  actor:=auth.uid();
  if page_number is null or page_number<1 then raise exception 'Página inválida' using errcode='22023'; end if;
  select jsonb_build_object('total',(select count(*) from public.dopmi_threads where actor in(owner_id,adopter_id)),
    'items',coalesce((select jsonb_agg(to_jsonb(rows)) from (
      select t.*,p.display_name as participant_name,
        (select m.body from public.dopmi_messages m where m.thread_id=t.id order by m.created_at desc,m.id desc limit 1) as last_message,
        (select count(*) from public.dopmi_notifications n where n.thread_id=t.id and n.user_id=actor and n.read_at is null) as unread_count
      from public.dopmi_threads t join public.profiles p on p.id=case when t.owner_id=actor then t.adopter_id else t.owner_id end
      where actor in(t.owner_id,t.adopter_id) order by t.updated_at desc,t.id
      limit 20 offset (page_number::bigint-1)*20) rows),'[]'::jsonb)) into result;
  return result;
end;
$$;

create function public.dopmi_thread_messages(thread_id uuid,before_time timestamptz default null,before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
  if not public.dopmi_actor_active() or not exists(select 1 from public.dopmi_threads t where t.id=$1
    and auth.uid() in(t.owner_id,t.adopter_id)) then raise exception 'Conversación no disponible' using errcode='42501'; end if;
  return coalesce((select jsonb_agg(to_jsonb(rows) order by rows.created_at,rows.id) from (
    select * from public.dopmi_messages m where m.thread_id=$1
      and (before_time is null or (m.created_at,m.id)<(before_time,before_id))
    order by m.created_at desc,m.id desc limit 40) rows),'[]'::jsonb);
end;
$$;

create function public.dopmi_close_thread(thread_id uuid) returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor();
begin
  update public.dopmi_threads set status='closed',updated_at=now() where id=$1 and actor in(owner_id,adopter_id);
  if not found then raise exception 'Conversación no disponible' using errcode='42501'; end if;
end;
$$;
create function public.dopmi_read_thread(thread_id uuid) returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor();
begin
  update public.dopmi_notifications set read_at=coalesce(read_at,now()) where dopmi_notifications.thread_id=$1 and user_id=actor;
end;
$$;
revoke all on function public.dopmi_start_thread(uuid),public.dopmi_send_message(uuid,uuid,text),public.dopmi_list_threads(integer),
 public.dopmi_thread_messages(uuid,timestamptz,uuid),public.dopmi_close_thread(uuid),public.dopmi_read_thread(uuid) from public,anon;
grant execute on function public.dopmi_start_thread(uuid),public.dopmi_send_message(uuid,uuid,text),public.dopmi_list_threads(integer),
 public.dopmi_thread_messages(uuid,timestamptz,uuid),public.dopmi_close_thread(uuid),public.dopmi_read_thread(uuid) to authenticated;
commit;
