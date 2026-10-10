begin;

-- Auth identities may be removed after an account is finalized. Moderation
-- evidence retains the reviewed content while its reviewer reference becomes
-- anonymous. Apple revocation remains deliberately restrictive until its
-- encrypted credential has been revoked and removed by the Edge Function.
alter table private.dopmi_case_update_reviews
  drop constraint dopmi_case_update_reviews_reviewer_id_fkey,
  add constraint dopmi_case_update_reviews_reviewer_id_fkey
    foreign key (reviewer_id) references auth.users(id) on delete set null;

alter table private.dopmi_rescuer_profile_reviews
  drop constraint dopmi_rescuer_profile_reviews_reviewer_id_fkey,
  add constraint dopmi_rescuer_profile_reviews_reviewer_id_fkey
    foreign key (reviewer_id) references auth.users(id) on delete set null;

commit;
