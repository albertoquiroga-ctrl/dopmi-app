begin;

-- These records are exposed only through the scoped SECURITY DEFINER RPCs.
-- Explicit deny policies document that raw PostgREST access is not a fallback.
create policy dopmi_saved_cases_rpc_only on public.dopmi_saved_cases
  as restrictive for all to authenticated using (false) with check (false);
create policy dopmi_saved_rescuers_rpc_only on public.dopmi_saved_rescuers
  as restrictive for all to authenticated using (false) with check (false);
create policy dopmi_content_reports_rpc_only on public.dopmi_content_reports
  as restrictive for all to authenticated using (false) with check (false);

commit;
