-- Internal operator-only report. This is the personal-a iOS CPP pilot, not
-- verified installation/referrer evidence. The source window begins at server
-- enrollment after login and consent. It does not recover the original click
-- date. Do not pool these denominators with Android/Apple download aggregates.
-- Account creation precedes enrollment, so no Android-style new-account subset
-- is inferred. Raw source records include QA; exclude the known QA account in
-- a separate private operator query before comparing live campaign outcomes.
with eligible as (
  select s.variant, s.source_method, s.first_submitted_at, s.first_approved_at,
    s.attributed_at <= statement_timestamp() - interval '336 hours' as matured,
    exists(select 1 from private.dopmi_ios_cpp_acquisition_events e
      where e.actor_id=s.actor_id and e.event_type='automatic_greeting') as automatic_greeting,
    exists(select 1 from private.dopmi_ios_cpp_acquisition_events e
      where e.actor_id=s.actor_id and e.event_type='first_user_message') as user_message,
    exists(select 1 from private.dopmi_ios_cpp_acquisition_events e
      where e.actor_id=s.actor_id and e.event_type='first_rescuer_reply') as rescuer_reply
  from private.dopmi_ios_cpp_acquisition s
), pilot(variant,source_method) as (values ('personal-a','ios_cpp_open'))
select pilot.variant, pilot.source_method,
  count(eligible.variant)::integer as attributed_accounts,
  count(*) filter (where eligible.matured)::integer as matured_accounts,
  count(eligible.first_submitted_at)::integer as first_observable_submissions_14d,
  count(eligible.first_submitted_at) filter (where eligible.matured)::integer as matured_first_observable_submissions_14d,
  count(eligible.first_approved_at)::integer as first_observable_submissions_approved,
  count(*) filter (where eligible.automatic_greeting)::integer as first_observable_automatic_greetings_14d,
  count(*) filter (where eligible.user_message)::integer as first_observable_user_messages_14d,
  count(*) filter (where eligible.rescuer_reply)::integer as first_observable_rescuer_replies_14d,
  count(*) filter (where eligible.matured and eligible.automatic_greeting)::integer as matured_first_observable_automatic_greetings_14d,
  count(*) filter (where eligible.matured and eligible.user_message)::integer as matured_first_observable_user_messages_14d,
  count(*) filter (where eligible.matured and eligible.rescuer_reply)::integer as matured_first_observable_rescuer_replies_14d
from pilot left join eligible using(variant,source_method)
group by pilot.variant,pilot.source_method;
