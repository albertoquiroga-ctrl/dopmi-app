begin;

-- Favorites in Matches are published pets whose adopter has not sent a message.
-- Keep the underlying like for Saved Pets, discovery, and rescuer metrics.
create function public.dopmi_match_favorites(
  page_number integer default 1,
  page_size integer default 20
) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  actor uuid := auth.uid();
begin
  if not public.dopmi_actor_active() then
    raise exception 'Se requiere una cuenta activa y confirmada' using errcode = '42501';
  end if;
  if page_number is null or page_number < 1
    or page_size is null or page_size not between 1 and 50 then
    raise exception 'No se puede mostrar esa lista' using errcode = '22023';
  end if;

  return (
    with eligible as (
      select f.post_id, f.created_at
      from public.dopmi_favorites f
      join public.dopmi_adoptions a on a.id = f.post_id
      join public.profiles p on p.id = a.owner_id
      where f.user_id = actor and a.status = 'published' and p.account_status = 'active'
        and not exists (
          select 1
          from public.dopmi_threads t
          join public.dopmi_messages m on m.thread_id = t.id and m.sender_id = t.adopter_id
          where t.post_id = f.post_id and t.adopter_id = actor
        )
    ),
    page as (
      select post_id, created_at from eligible
      order by created_at desc, post_id
      limit page_size offset (page_number::bigint - 1) * page_size
    )
    select jsonb_build_object(
      'total', (select count(*) from eligible),
      'items', coalesce((
        select jsonb_agg(
          private.dopmi_public_post(a) || jsonb_build_object('saved', true, 'available', true)
          order by page.created_at desc, page.post_id
        )
        from page
        join public.dopmi_adoptions a on a.id = page.post_id
      ), '[]'::jsonb)
    )
  );
end;
$$;

revoke all on function public.dopmi_match_favorites(integer, integer) from public, anon, authenticated;
grant execute on function public.dopmi_match_favorites(integer, integer) to authenticated;

commit;
