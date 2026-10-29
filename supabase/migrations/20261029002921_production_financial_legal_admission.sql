begin;

-- New production financial instructions require their actor's actual LIVE
-- legal proof. Existing TEST fixtures/clients retain the reviewed TEST contract.
-- No caller can invoke this helper directly or choose a different environment.
create function private.dopmi_require_current_legal(target_actor uuid) returns void
language plpgsql stable security definer set search_path='' as $$
declare environment text;
begin
  select e.environment into environment from private.dopmi_payment_environment e where e.singleton;
  if environment='test' then return; end if;
  if environment is distinct from 'production' or target_actor is null or not exists(
    select 1 from public.profiles p join auth.users u on u.id=p.id
    join private.dopmi_consents c on c.owner_id=p.id
    where p.id=target_actor and p.account_status='active' and u.email_confirmed_at is not null
      and p.terms_version='terms-live-2026-10-28' and p.privacy_version='privacy-live-2026-10-28'
      and p.terms_accepted_at is not null and p.privacy_accepted_at is not null and p.adult_confirmed_at is not null
      and c.terms_version=p.terms_version and c.privacy_version=p.privacy_version and c.adult_confirmed
      and c.accepted_at=p.terms_accepted_at and c.accepted_at=p.privacy_accepted_at
  ) then
    raise exception 'Acepta los términos y el aviso de privacidad vigentes' using errcode='42501';
  end if;
end $$;
revoke all on function private.dopmi_require_current_legal(uuid) from public,anon,authenticated,service_role;

-- Use final installed function definitions. Each unique insertion is confined
-- to a new instruction, after stable-key recovery where it exists. Fail closed
-- on drift. No shared identity guard, reads, cancellation, historical payment
-- authorization, recurring collection or provider reconciliation is changed.
do $patch$
declare
  target regprocedure;
  anchor text;
  admission text;
  definition text;
begin
  for target,anchor,admission in values
    ('public.dopmi_payment_server_expense_v1(text,jsonb)'::regprocedure,
      $a$select * into r from public.dopmi_rescue_records where id=(data->>'expense_id')::uuid;$a$,
      $b$perform private.dopmi_require_current_legal(actor); $b$),
    ('public.dopmi_oneoff_case_server(text,jsonb)'::regprocedure,
      $a$gross:=(data->>'gross_cents')::bigint;$a$,
      $b$perform private.dopmi_require_current_legal(actor); $b$),
    ('public.dopmi_guardian_registration_server(text,jsonb)'::regprocedure,
      $a$insert into private.dopmi_guardian_registrations(owner_id,request_key,initial_gross_cents,gross_cents,consent_version)$a$,
      $b$perform private.dopmi_require_current_legal(actor); $b$),
    ('public.dopmi_guardian_registration_server(text,jsonb)'::regprocedure,
      $a$update private.dopmi_guardian_registrations set gross_cents=gross,consent_at=now(),revision=revision+1$a$,
      $b$if gross>r.gross_cents then perform private.dopmi_require_current_legal(actor); end if; $b$),
    ('public.dopmi_guardian_activation_server(text,jsonb)'::regprocedure,
      $a$held:=public.dopmi_guardian_reserve(donor,requested_key,gross);$a$,
      $b$perform private.dopmi_require_current_legal(donor); $b$),
    ('public.dopmi_saved_card_server(text,jsonb)'::regprocedure,
      $a$insert into private.dopmi_saved_card_customers(owner_id) values(actor) on conflict(owner_id) do nothing;$a$,
      $b$perform private.dopmi_require_current_legal(actor); $b$),
    ('public.dopmi_guardian_method_server(text,jsonb)'::regprocedure,
      $a$insert into private.dopmi_guardian_method_jobs(donor_id,subscription_id,request_key,revision,consent_version,expires_at,return_url,selected_method_id,remove_saved)$a$,
      $b$if not coalesce((data->>'remove_saved')::boolean,false) then perform private.dopmi_require_current_legal(actor); end if; $b$),
    ('public.dopmi_guardian_registration_method_server(text,jsonb)'::regprocedure,
      $a$insert into private.dopmi_guardian_registration_method_changes(registration_id,owner_id,request_key,registration_revision,consent_version)$a$,
      $b$perform private.dopmi_require_current_legal(actor); $b$),
    ('public.dopmi_guardian_request(text,uuid,bigint,bigint,text)'::regprocedure,
      $a$if p.gross_cents=new_gross_cents then raise exception 'El nuevo monto debe ser diferente' using errcode='22023'; end if;$a$,
      $b$if new_gross_cents>p.gross_cents then perform private.dopmi_require_current_legal(actor); end if; $b$),
    ('public.dopmi_payment_server(text,jsonb)'::regprocedure,
      $a$result:=public.dopmi_payment_server_before_pending_stripe(operation,data);$a$,
      $b$if operation='connect_admit' then
    perform private.dopmi_require_current_legal((data->>'actor')::uuid);
    return jsonb_build_object('allowed',true);
  end if;
  $b$)
  loop
    definition:=pg_get_functiondef(target);
    if (length(definition)-length(replace(definition,anchor,'')))/length(anchor)<>1 then
      raise exception 'Financial legal admission anchor changed for %: review patch',target;
    end if;
    execute replace(definition,anchor,admission||anchor);
  end loop;
end $patch$;

-- CREATE OR REPLACE keeps every previous ACL. The new action uses the existing
-- service-only dispatcher; it is not a public metadata or consent setter.
do $$ begin
  if has_function_privilege('anon','public.dopmi_payment_server(text,jsonb)','EXECUTE') or
    has_function_privilege('authenticated','public.dopmi_payment_server(text,jsonb)','EXECUTE') or
    not has_function_privilege('service_role','public.dopmi_payment_server(text,jsonb)','EXECUTE') then
    raise exception 'Financial dispatcher ACL changed: review Connect admission';
  end if;
end $$;

commit;
