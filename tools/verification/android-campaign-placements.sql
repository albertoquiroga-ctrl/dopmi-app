-- Operator-only aggregate. These are retained, consented Android accounts,
-- not impressions, clicks, Facebook authors or proof of install. A shared token
-- continues to identify its assigned placement. No public view/RPC is created.
-- Primary acquisition counts an account once. All-pet receipts are secondary.
-- First approval follows the original first pet, even after the 336h window.
-- The first result has all 60 public placements including zeros. QA is a
-- separate second result; additionally exclude known technical accounts in a
-- private operator query if they ever used a public placement. Do not commit IDs.
with eligible as (
  select s.*,
    s.clicked_at <= statement_timestamp() - interval '336 hours' as matured,
    exists(select 1 from private.dopmi_android_acquisition_events e where e.actor_id=s.actor_id and e.event_type='automatic_greeting') as greeting,
    exists(select 1 from private.dopmi_android_acquisition_events e where e.actor_id=s.actor_id and e.event_type='first_user_message') as composer,
    exists(select 1 from private.dopmi_android_acquisition_events e where e.actor_id=s.actor_id and e.event_type='first_rescuer_reply') as reply,
    (select count(*)::integer from private.dopmi_campaign_adoption_submissions r
      where r.actor_id=s.actor_id and r.placement_token=s.placement_token) as submitted_pets
  from private.dopmi_android_rescuer_acquisition s where s.placement_token is not null
)
select p.token as placement_token, p.experiment_id, p.arm_id, p.variant, p.is_qa, p.enabled,
  count(e.actor_id)::integer as attributed_accounts,
  count(*) filter(where e.matured)::integer as matured_accounts,
  count(e.first_submitted_at)::integer as first_observable_submissions_14d,
  count(e.first_submitted_at) filter(where e.matured)::integer as matured_first_observable_submissions_14d,
  count(e.first_approved_at)::integer as first_observable_submissions_approved,
  count(*) filter(where e.greeting)::integer as automatic_greetings_14d,
  count(*) filter(where e.composer)::integer as first_user_messages_14d,
  count(*) filter(where e.reply)::integer as first_rescuer_replies_14d,
  count(*) filter(where e.matured and e.greeting)::integer as matured_automatic_greetings_14d,
  count(*) filter(where e.matured and e.composer)::integer as matured_first_user_messages_14d,
  count(*) filter(where e.matured and e.reply)::integer as matured_first_rescuer_replies_14d,
  coalesce(sum(e.submitted_pets),0)::integer as all_submitted_pets_14d,
  coalesce(sum(e.submitted_pets) filter(where e.matured),0)::integer as matured_all_submitted_pets_14d
from private.dopmi_campaign_placements p
left join eligible e on e.placement_token=p.token and e.variant=p.variant
where p.experiment_id='resc_mty_20261121_p60_v1' and not p.is_qa
group by p.token,p.experiment_id,p.arm_id,p.variant,p.is_qa,p.enabled
order by p.arm_id,p.token;

-- QA-only result; never add these counts to the public-placement cohort.
with eligible as (
  select s.*,
    s.clicked_at <= statement_timestamp() - interval '336 hours' as matured,
    exists(select 1 from private.dopmi_android_acquisition_events e where e.actor_id=s.actor_id and e.event_type='automatic_greeting') as greeting,
    exists(select 1 from private.dopmi_android_acquisition_events e where e.actor_id=s.actor_id and e.event_type='first_user_message') as composer,
    exists(select 1 from private.dopmi_android_acquisition_events e where e.actor_id=s.actor_id and e.event_type='first_rescuer_reply') as reply,
    (select count(*)::integer from private.dopmi_campaign_adoption_submissions r
      where r.actor_id=s.actor_id and r.placement_token=s.placement_token) as submitted_pets
  from private.dopmi_android_rescuer_acquisition s where s.placement_token is not null
)
select p.token as placement_token, p.experiment_id, p.arm_id, p.variant, p.is_qa, p.enabled,
  count(e.actor_id)::integer as attributed_accounts,
  count(*) filter(where e.matured)::integer as matured_accounts,
  count(e.first_submitted_at)::integer as first_observable_submissions_14d,
  count(e.first_submitted_at) filter(where e.matured)::integer as matured_first_observable_submissions_14d,
  count(e.first_approved_at)::integer as first_observable_submissions_approved,
  count(*) filter(where e.greeting)::integer as automatic_greetings_14d,
  count(*) filter(where e.composer)::integer as first_user_messages_14d,
  count(*) filter(where e.reply)::integer as first_rescuer_replies_14d,
  count(*) filter(where e.matured and e.greeting)::integer as matured_automatic_greetings_14d,
  count(*) filter(where e.matured and e.composer)::integer as matured_first_user_messages_14d,
  count(*) filter(where e.matured and e.reply)::integer as matured_first_rescuer_replies_14d,
  coalesce(sum(e.submitted_pets),0)::integer as all_submitted_pets_14d,
  coalesce(sum(e.submitted_pets) filter(where e.matured),0)::integer as matured_all_submitted_pets_14d
from private.dopmi_campaign_placements p
left join eligible e on e.placement_token=p.token and e.variant=p.variant
where p.experiment_id='resc_mty_20261121_p60_v1' and p.is_qa
group by p.token,p.experiment_id,p.arm_id,p.variant,p.is_qa,p.enabled
order by p.arm_id,p.token;
