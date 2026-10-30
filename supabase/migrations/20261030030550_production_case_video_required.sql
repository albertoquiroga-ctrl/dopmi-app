begin;

-- A disabled provider must not create a permanent video exemption for a new
-- production case. Explicit TEST behavior and already-recorded exemptions stay
-- intact; this migration neither rewrites cases nor enables any service.
create or replace function private.dopmi_video_submission_guard() returns trigger
language plpgsql security definer set search_path='' as $$
declare environment text; video_enabled boolean;
begin
 if new.kind='case' and new.status in ('pending_stripe','submitted','approved') then
  environment:=public.dopmi_payment_environment_server()->>'environment';
  select enabled into video_enabled from private.dopmi_video_settings where singleton;
  if environment is distinct from 'test' then
   -- A service outage cannot waive a requirement already recorded at submission.
   -- Equally, an explicit historical exemption is never silently backfilled.
   new.video_thanks_required:=old.video_thanks_required;
  elsif not video_enabled then
   new.video_thanks_required:=false;
  end if;
  -- Only an explicit TEST binding may retain the historical OFF exemption.
  -- Missing/unknown binding and missing settings fail closed for new sends.
  if new.video_thanks_required and old.status in ('draft','changes_requested','rejected')
     and environment is distinct from 'test' and (
     environment is distinct from 'production' or
     video_enabled is not true) then
   raise exception 'El agradecimiento en video aún no está disponible. Tu caso sigue guardado como borrador. Intenta enviarlo más tarde.'
     using errcode='22023';
  end if;
  -- Retain the installed content/moderation pipeline while OFF, too. The same
  -- identified constraint lets Connect save readiness and defer a pending case
  -- with missing/stale media, rather than aborting the account synchronization.
  if (video_enabled or environment is distinct from 'test') and new.video_thanks_required and old.status is distinct from new.status then
   if (environment is distinct from 'test' and environment is distinct from 'production') or
    not exists(select 1 from private.dopmi_video_assets a where a.parent_id=new.id and a.purpose='thanks' and a.technical_state='ready'
   and a.content_snapshot=private.dopmi_video_content(new) and a.moderation_state in ('pending','approved')
   and (new.status<>'approved' or a.moderation_state='approved')) then
    raise exception 'Agradecimiento requerido: carga un video listo y aprobado antes de publicar'
     using errcode='23514',constraint='dopmi_video_submission_ready';
   end if;
  end if;
 end if;
 return new;
end;
$$;

revoke all on function private.dopmi_video_submission_guard() from public,anon,authenticated,service_role;

commit;
