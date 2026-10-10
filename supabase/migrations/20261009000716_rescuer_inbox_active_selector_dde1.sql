-- Additive selector metadata; retain historical groups, threads, totals and ACLs.
create or replace function public.dopmi_rescuer_inbox(page_number integer default 1,page_size integer default 20,history boolean default false)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); result jsonb;
begin
  if page_number is null or page_number<1 or page_size is null or page_size not between 1 and 50 or history is null then
    raise exception 'Paginación inválida' using errcode='22023'; end if;
  with posts as (
    select distinct on(coalesce(a.rescue_case_id,a.id))
      coalesce(a.rescue_case_id,a.id) id,a.id post_id,a.rescue_case_id case_id,
      coalesce(nullif(r.public_data->>'pet_name',''),a.pet_name) pet_name,a.photos[1] photo,
      (a.status='published' and coalesce(r.status<>'closed',true)) selector_active
    from public.dopmi_adoptions a left join public.dopmi_rescue_records r on r.id=a.rescue_case_id
    where a.owner_id=actor and (
      (not history and a.status not in('archived','adopted','rejected') and coalesce(r.status<>'closed',true))
      or exists(select 1 from private.dopmi_rescuer_threads(actor,history) t where t.group_id=coalesce(a.rescue_case_id,a.id)))
    order by coalesce(a.rescue_case_id,a.id),a.updated_at desc,a.id
  ), entries as (select * from private.dopmi_rescuer_threads(actor,history)),
  groups as (
    select p.*,coalesce((select sum(t.unread) from entries t where t.group_id=p.id),0) unread_count,
      (select count(*) from entries t where t.group_id=p.id) thread_count
    from posts p
  ), page as (select * from groups order by unread_count desc,lower(pet_name),id limit page_size offset (page_number::bigint-1)*page_size)
  select jsonb_build_object('total',(select count(*) from groups),
    'items',coalesce((select jsonb_agg(to_jsonb(p)||jsonb_build_object('threads_total',p.thread_count,
      'threads',(public.dopmi_rescuer_group_threads(p.id,1,20,history)->'items')) order by p.unread_count desc,lower(p.pet_name),p.id) from page p),'[]'::jsonb)) into result;
  return result;
end;
$$;
revoke all on function public.dopmi_rescuer_inbox(integer,integer,boolean) from public,anon;
grant execute on function public.dopmi_rescuer_inbox(integer,integer,boolean) to authenticated;
