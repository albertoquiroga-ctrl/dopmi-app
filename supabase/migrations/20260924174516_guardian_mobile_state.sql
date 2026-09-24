begin;
-- Public projection only: no processor IDs, payment methods, leases or secrets.
-- A stored activation key lets its owner resume the same attempt on any device.
create function public.dopmi_guardian_state() returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=auth.uid(); activation jsonb;
begin
 if actor is null then raise exception 'Inicia sesión para consultar tu Guardián' using errcode='42501'; end if;
 select jsonb_build_object('key',c.cycle_key,'gross_cents',c.gross_cents,
 'consent_version',a.consent_version,'created_at',a.consent_at,
 'checkout_expires_at',a.checkout_expires_at,
 'status',case when a.status='settled' then case s.status when 'ready' then 'active' when 'canceled' then 'canceled' when 'attention' then 'attention' else 'funded_pending_schedule' end else a.status end)
 into activation from private.dopmi_guardian_activations a
 join private.dopmi_guardian_cycles c on c.id=a.cycle_id
 left join private.dopmi_guardian_schedule_jobs s on s.cycle_id=a.cycle_id
 where a.donor_id=actor order by a.consent_at desc,a.cycle_id desc limit 1;
 return jsonb_build_object('plan',private.dopmi_guardian_plan_view(actor),'activation',activation);
end; $$;
revoke all on function public.dopmi_guardian_state() from public,anon,authenticated,service_role;
grant execute on function public.dopmi_guardian_state() to authenticated;
commit;
