-- Operator-only READ ONLY wave2 report; no social identities or message contents.
-- Join by registry experiment_id, not transport UTM, which is shared for client compatibility.
-- Its 24 registered/enabled placements are not 24 sent comments or visible exposures.
-- Merge the private wave2 ledger for actual assigned/sent/visible denominators;
-- do not treat reserved or moderation-pending placements as publicly visible.
begin read only;
with eligible as (
 select s.*,
   s.clicked_at <= statement_timestamp()-interval '336 hours' as matured,
   exists(select 1 from private.dopmi_android_acquisition_events e where e.actor_id=s.actor_id and e.event_type='automatic_greeting') as greeting,
   exists(select 1 from private.dopmi_android_acquisition_events e where e.actor_id=s.actor_id and e.event_type='first_user_message') as first_message,
   exists(select 1 from private.dopmi_android_acquisition_events e where e.actor_id=s.actor_id and e.event_type='first_rescuer_reply') as rescuer_reply,
   (select count(*)::integer from private.dopmi_campaign_adoption_submissions r where r.actor_id=s.actor_id and r.placement_token=s.placement_token) as submitted_pets
 from private.dopmi_android_rescuer_acquisition s where s.placement_token is not null
)
select statement_timestamp() as observed_at_utc,p.token,p.experiment_id,p.arm_id,p.variant,p.is_qa,p.enabled,
 count(e.actor_id)::integer as retained_consented_android_accounts,
 count(*) filter(where e.matured)::integer as matured_accounts,
 count(e.first_submitted_at)::integer as first_submissions,
 count(e.first_approved_at)::integer as first_approvals,
 count(*) filter(where e.greeting)::integer as automatic_greetings,
 count(*) filter(where e.first_message)::integer as first_user_messages,
 count(*) filter(where e.rescuer_reply)::integer as first_rescuer_replies,
 coalesce(sum(e.submitted_pets),0)::integer as all_pet_submissions
from private.dopmi_campaign_placements p left join eligible e on e.placement_token=p.token and e.variant=p.variant
where p.experiment_id='resc_mty_20261122_wave2_v1'
group by p.token,p.experiment_id,p.arm_id,p.variant,p.is_qa,p.enabled
order by p.arm_id,p.token;
commit;
