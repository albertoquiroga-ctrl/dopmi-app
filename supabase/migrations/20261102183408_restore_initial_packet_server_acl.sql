begin;

-- Restore only the three service-role EXECUTE grants observed before the
-- initial-packet delivery. Function bodies, OIDs and all other ACLs stay intact.
-- The new packet RPC, private helpers and copied delegates remain inaccessible
-- to service_role; this does not authorize any financial operation.
grant execute on function public.dopmi_transition_rescue(uuid,integer,text) to service_role;
grant execute on function public.dopmi_review_rescue(uuid,integer,text,text,bigint,boolean,text,boolean) to service_role;
grant execute on function public.dopmi_rescue_file_access(text,boolean) to service_role;

commit;
