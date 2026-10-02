begin;

create function public.dopmi_rescuer_public(person_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare verification public.dopmi_rescue_records; profile jsonb;
begin
  select * into verification from public.dopmi_rescue_records
    where owner_id=person_id and kind='verification' and status='approved' and approved_snapshot is not null
    order by approved_at desc,id limit 1;
  if not found or not private.dopmi_public_rescuer(person_id) then return null; end if;
  profile:=jsonb_build_object(
    'id',person_id,
    'name',coalesce(verification.approved_snapshot->>'public_name','Rescatista Dopmi'),
    'bio',coalesce(verification.approved_snapshot->>'bio',''),
    'city',coalesce(verification.approved_snapshot->>'city',''),
    'region',coalesce(verification.approved_snapshot->>'state',''),
    'verified',true,
    'saved',exists(select 1 from public.dopmi_saved_rescuers s where s.user_id=auth.uid() and s.rescuer_id=person_id and public.dopmi_actor_active()),
    'adopted_count',(select count(*) from public.dopmi_adoptions where owner_id=person_id and status='adopted'),
    'adoptions',coalesce((select jsonb_agg(private.dopmi_public_post(a) order by a.published_at desc,a.id) from public.dopmi_adoptions a where a.owner_id=person_id and a.status='published'),'[]'::jsonb),
    'cases',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'status',r.status,'public_data',r.approved_snapshot) order by r.approved_at desc,r.id) from public.dopmi_rescue_records r where r.owner_id=person_id and r.kind='case' and private.dopmi_rescue_public_visible(r)),'[]'::jsonb),
    'activity',coalesce((select jsonb_agg(jsonb_build_object('id',u.id,'case_id',u.case_id,'body',u.approved_snapshot->>'body','photos',u.approved_snapshot->'photos','published_at',u.published_at) order by u.published_at desc,u.id) from public.dopmi_case_updates u where u.owner_id=person_id and u.status='published' and u.approved_snapshot is not null),'[]'::jsonb)
  );
  return profile;
end;
$$;

create function public.dopmi_personal_impact() returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=auth.uid();
begin
  if not public.dopmi_actor_active() then raise exception 'Sesión activa requerida' using errcode='42501'; end if;
  return coalesce((select jsonb_agg(to_jsonb(result) order by result.last_supported_at desc,result.case_id) from (
    select c.id as case_id,c.approved_snapshot as public_data,
      sum(d.allocated_cents)::bigint as allocated_cents,max(d.processed_at) as last_supported_at,
      coalesce((select jsonb_agg(jsonb_build_object('id',u.id,'body',u.approved_snapshot->>'body','photos',u.approved_snapshot->'photos','published_at',u.published_at) order by u.published_at,u.id)
        from public.dopmi_case_updates u where u.case_id=c.id and u.status='published' and u.approved_snapshot is not null),'[]'::jsonb) as updates
    from public.dopmi_donations d
    join public.dopmi_rescue_records e on e.id=d.expense_id
    join public.dopmi_rescue_records c on c.id=e.parent_id
    where d.donor_id=actor and d.payment_status='confirmed' and d.allocated_cents>0 and private.dopmi_rescue_public_visible(c)
    group by c.id,c.approved_snapshot
  ) result),'[]'::jsonb);
end;
$$;

revoke all on function public.dopmi_rescuer_public(uuid),public.dopmi_personal_impact() from public,anon,authenticated;
grant execute on function public.dopmi_rescuer_public(uuid) to anon,authenticated;
grant execute on function public.dopmi_personal_impact() to authenticated;

commit;
