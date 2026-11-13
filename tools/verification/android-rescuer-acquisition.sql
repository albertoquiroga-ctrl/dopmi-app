-- Internal read-only pilot report. Run as the database operator.
-- A variant is a Facebook identity and message combination, not an individual
-- Facebook post or reader. Only eligible Android accounts with usage consent
-- are included. Compare matured cohorts once 14 days from the referral click
-- have elapsed. Earlier history without retained evidence cannot be excluded,
-- so the broad figures are first observable submissions. The new-account
-- subset includes accounts created on or after the referral click.
with variants(variant) as (
  values ('personal-a'), ('personal-b'), ('pagina-a'), ('pagina-b')
), eligible as (
  select source.variant, source.first_submitted_at, source.first_approved_at,
    source.clicked_at <= statement_timestamp() - interval '336 hours' as matured,
    account.created_at >= source.clicked_at as new_account
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
  count(eligible.first_approved_at) filter (where eligible.new_account)::integer as new_first_submissions_approved
from variants
left join eligible using (variant)
group by variants.variant
order by variants.variant;
