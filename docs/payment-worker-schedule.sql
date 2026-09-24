-- Run in the Dopmi Supabase SQL editor only after storing the existing
-- DOPMI_WORKER_SECRET in Vault under the name dopmi_payment_worker_token.
-- Do not paste the secret into this file or save its value in Git.
-- The cron command reads Vault at execution time; cron.job stores no token.
do $setup$
begin
  if not exists (select 1 from pg_extension where extname = 'pg_cron')
     or not exists (select 1 from pg_extension where extname = 'pg_net') then
    raise exception 'pg_cron and pg_net must be enabled';
  end if;
  if not exists (select 1 from vault.secrets where name = 'dopmi_payment_worker_token') then
    raise exception 'Store the worker token in Vault before scheduling';
  end if;
end
$setup$;

select cron.schedule(
  'dopmi-payment-worker-reconcile',
  '* * * * *',
  $job$
  select net.http_post(
    url := 'https://ohqxranynackjignryep.supabase.co/functions/v1/payment-worker',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (
        select decrypted_secret from vault.decrypted_secrets
        where name = 'dopmi_payment_worker_token'
      )
    ),
    body := '{"action":"reconcile"}'::jsonb,
    timeout_milliseconds := 30000
  );
  $job$
);

-- Verify after at least one minute. Do not select command from cron.job:
-- it contains no token, but the job text is not needed for monitoring.
select jobid, jobname, schedule, active
from cron.job where jobname = 'dopmi-payment-worker-reconcile';
