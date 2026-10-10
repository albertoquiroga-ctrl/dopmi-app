begin;
-- Supports owner-scoped retention/cleanup without changing archival semantics.
create index dopmi_support_archives_owner on private.dopmi_support_archives(owner_id);
commit;
