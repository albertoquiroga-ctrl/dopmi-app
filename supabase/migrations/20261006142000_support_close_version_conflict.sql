-- Preserve the build295 transition API and all existing lifecycle/financial guards.
-- The new support-close flow returns a non-retryable HTTP409 for a stale version.
create function public.dopmi_close_support_case(record_id uuid,expected_version integer) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
  return public.dopmi_transition_rescue(record_id,expected_version,'close');
exception when serialization_failure then
  raise exception 'La solicitud cambió. Recarga antes de continuar' using errcode='PT409';
end; $$;
revoke all on function public.dopmi_close_support_case(uuid,integer) from public,anon;
grant execute on function public.dopmi_close_support_case(uuid,integer) to authenticated;
