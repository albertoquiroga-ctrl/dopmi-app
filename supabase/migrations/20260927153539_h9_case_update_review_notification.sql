-- A correction and its subsequent approval share one notification source.
-- Refresh that notification without rolling back the second review.
begin;
create or replace function public.dopmi_review_case_update(update_id uuid,expected_version integer,decision text,feedback text default '') returns jsonb
language plpgsql security definer set search_path='' as $$
declare item public.dopmi_case_updates;
begin
  if not public.dopmi_is_admin() then raise exception 'Acceso administrativo requerido' using errcode='42501'; end if;
  select * into item from public.dopmi_case_updates where id=update_id for update;
  if not found or item.status<>'submitted' then raise exception 'Avance no disponible' using errcode='22023'; end if;
  if item.version is distinct from expected_version then raise exception 'El avance cambió' using errcode='40001'; end if;
  if decision not in ('published','changes_requested','rejected') or (decision<>'published' and char_length(btrim(coalesce(feedback,'')))<5) then raise exception 'Decisión inválida' using errcode='22023'; end if;
  update public.dopmi_case_updates set status=decision,review_feedback=btrim(coalesce(feedback,'')),
    approved_snapshot=case when decision='published' then jsonb_build_object('body',body,'photos',to_jsonb(photos)) else approved_snapshot end,
    published_at=case when decision='published' then now() else published_at end,version=version+1,updated_at=now()
    where id=item.id returning * into item;
  insert into private.dopmi_case_update_reviews(update_id,reviewer_id,decision,feedback,version,snapshot)
    values(item.id,auth.uid(),decision,btrim(coalesce(feedback,'')),item.version,to_jsonb(item));
  insert into public.dopmi_notifications(user_id,kind,rescue_id,source_id,title)
    values(item.owner_id,'review',item.case_id,item.id,case when decision='published' then 'Tu avance ya está publicado' else 'Tu avance necesita atención' end)
    on conflict(user_id,kind,source_id) do update set title=excluded.title,read_at=null,created_at=now();
  insert into private.admin_access_log(actor_id,action) values(auth.uid(),'case_updates.review');
  return to_jsonb(item);
end;
$$;
commit;
