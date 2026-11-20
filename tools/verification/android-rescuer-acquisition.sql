-- Internal read-only pilot report. Run as the database operator.
-- A variant is a Facebook identity and message combination, not an individual
-- Facebook post or reader. Only eligible Android accounts with usage consent
-- are included. Compare matured cohorts once 14 days from the referral click
-- have elapsed. Earlier history without retained evidence cannot be excluded,
-- so the broad figures are first observable submissions. The new-account
-- subset includes accounts created on or after the referral click.
-- Messaging milestones are prospective INSERT observations by the attributed
-- actor, never the other participant's activity. Composer text OR photo counts;
-- an automatic greeting is separate. Legacy origins stay unknown. No content,
-- photo paths, thread IDs or counterpart IDs leave this aggregate report.
with variants(variant) as (
  values ('personal-a'), ('personal-b'), ('pagina-a'), ('pagina-b')
), eligible as (
  select source.variant, source.first_submitted_at, source.first_approved_at,
    source.clicked_at <= statement_timestamp() - interval '336 hours' as matured,
    account.created_at >= source.clicked_at as new_account,
    exists(select 1 from private.dopmi_android_acquisition_events e
      where e.actor_id=source.actor_id and e.event_type='automatic_greeting') as automatic_greeting,
    exists(select 1 from private.dopmi_android_acquisition_events e
      where e.actor_id=source.actor_id and e.event_type='first_user_message') as user_message,
    exists(select 1 from private.dopmi_android_acquisition_events e
      where e.actor_id=source.actor_id and e.event_type='first_rescuer_reply') as rescuer_reply
  from private.dopmi_android_rescuer_acquisition source
  join auth.users account on account.id = source.actor_id
)
select variants.variant,
  count(eligible.variant)::integer as attributed_accounts,
  count(*) filter (where eligible.matured)::integer as matured_accounts,
  count(eligible.first_submitted_at)::integer as first_observable_submissions_14d,
  count(eligible.first_submitted_at) filter (
    where eligible.matured
  )::integer as matured_first_observable_submissions_14d,
  count(eligible.first_approved_at)::integer as first_observable_submissions_approved,
  count(*) filter (where eligible.new_account)::integer as new_attributed_accounts,
  count(*) filter (where eligible.new_account and eligible.matured)::integer as new_matured_accounts,
  count(eligible.first_submitted_at) filter (where eligible.new_account)::integer as new_first_submissions_14d,
  count(eligible.first_submitted_at) filter (
    where eligible.new_account and eligible.matured
  )::integer as new_matured_first_submissions_14d,
  count(eligible.first_approved_at) filter (where eligible.new_account)::integer as new_first_submissions_approved,
  count(*) filter (where eligible.automatic_greeting)::integer as first_observable_automatic_greetings_14d,
  count(*) filter (where eligible.user_message)::integer as first_observable_user_messages_14d,
  count(*) filter (where eligible.rescuer_reply)::integer as first_observable_rescuer_replies_14d,
  count(*) filter (where eligible.matured and eligible.automatic_greeting)::integer as matured_first_observable_automatic_greetings_14d,
  count(*) filter (where eligible.matured and eligible.user_message)::integer as matured_first_observable_user_messages_14d,
  count(*) filter (where eligible.matured and eligible.rescuer_reply)::integer as matured_first_observable_rescuer_replies_14d,
  count(*) filter (where eligible.new_account and eligible.automatic_greeting)::integer as new_first_observable_automatic_greetings_14d,
  count(*) filter (where eligible.new_account and eligible.user_message)::integer as new_first_observable_user_messages_14d,
  count(*) filter (where eligible.new_account and eligible.rescuer_reply)::integer as new_first_observable_rescuer_replies_14d
from variants
left join eligible using (variant)
group by variants.variant
order by variants.variant;
