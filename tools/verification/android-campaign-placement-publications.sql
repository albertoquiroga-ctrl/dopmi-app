-- OPERATOR ONLY: publication IDs may refer to private submissions. Never expose
-- this as a public view/RPC, paste it into public campaign output or commit rows.
-- These joins identify an account's original acquisition placement, not a new
-- last-click claim, its Facebook identity or proof of the converter's authorship.
-- Use is_qa to keep technical outcomes separate and exclude any other known QA
-- accounts in a private operator query. OFF/account deletion removes the source
-- and receipts. Post deletion removes its receipt; no historical row is rebuilt.

-- Exact first pet: both the immutable source reference and its owner must match.
select p.token as placement_token,p.experiment_id,p.arm_id,p.variant,p.is_qa,
  a.id as post_id,a.status as current_status,
  s.clicked_at,s.attributed_at,s.first_submitted_at,s.first_approved_at,
  r.first_submitted_at as publication_first_submitted_at,true as is_primary
from private.dopmi_android_rescuer_acquisition s
join private.dopmi_campaign_placements p on p.token=s.placement_token and p.variant=s.variant
join public.dopmi_adoptions a on a.id=s.first_adoption_id and a.owner_id=s.actor_id
join private.dopmi_campaign_adoption_submissions r on r.post_id=a.id
  and r.actor_id=s.actor_id and r.placement_token=s.placement_token
where p.experiment_id='resc_mty_20261121_p60_v1'
order by p.is_qa,p.arm_id,p.token,r.first_submitted_at,a.id;

-- Additional pets: prospective immutable receipts only, never mutable current
-- submitted_at or private edit submissions. They are secondary publications;
-- multiple pets still represent one acquired account in the primary metric.
select p.token as placement_token,p.experiment_id,p.arm_id,p.variant,p.is_qa,
  a.id as post_id,a.status as current_status,
  s.clicked_at,s.attributed_at,r.first_submitted_at,
  a.published_at as current_published_at,false as is_primary
from private.dopmi_campaign_adoption_submissions r
join private.dopmi_android_rescuer_acquisition s on s.actor_id=r.actor_id
  and s.placement_token=r.placement_token
join private.dopmi_campaign_placements p on p.token=s.placement_token and p.variant=s.variant
join public.dopmi_adoptions a on a.id=r.post_id and a.owner_id=s.actor_id
where p.experiment_id='resc_mty_20261121_p60_v1'
  and r.post_id is distinct from s.first_adoption_id
  and s.attributed_at <= r.first_submitted_at
  and r.first_submitted_at < s.clicked_at + interval '336 hours'
order by p.is_qa,p.arm_id,p.token,r.first_submitted_at,a.id;
