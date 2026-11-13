begin;

create function public.dopmi_admin_first_publication() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  cutoff timestamptz := statement_timestamp();
  window_start timestamptz := cutoff - interval '168 hours';
  report jsonb;
begin
  if not public.dopmi_is_admin() then
    raise exception 'Acceso administrativo requerido' using errcode = '42501';
  end if;

  -- Cohort membership is based on signup; mode and retained listings are
  -- evaluated at the report cutoff. Count authors once across their listings.
  with cohort as (
    select u.id, p.active_mode
    from auth.users u
    left join public.profiles p on p.id = u.id
    where u.created_at >= window_start
      and u.created_at < cutoff
      and u.deleted_at is null
      and not coalesce(u.is_anonymous, false)
      and p.account_status is distinct from 'deleted'
  ), author_progress as (
    select a.owner_id,
           bool_or(cardinality(a.photos) > 0) as attached_photo,
           bool_or(a.submitted_at is not null or a.published_at is not null
             or exists (
               select 1
               from private.dopmi_adoption_reviews r
               where r.post_id = a.id
                 and r.decision in ('published', 'changes_requested', 'rejected')
             )) as recorded_submission,
           bool_or(a.published_at is not null) as recorded_publication,
           bool_or(a.status = 'draft' and a.created_at <= cutoff - interval '24 hours') as older_draft
    from public.dopmi_adoptions a
    join cohort c on c.id = a.owner_id
    group by a.owner_id
  ), cohort_counts as (
    select count(*) as accounts_created,
           count(*) filter (where c.active_mode = 'rescuer') as rescuer_mode_accounts,
           count(*) filter (where a.owner_id is not null) as authors_with_drafts,
           count(*) filter (where a.attached_photo) as authors_with_photo,
           count(*) filter (where a.recorded_submission) as authors_with_submissions,
           count(*) filter (where a.recorded_publication) as authors_with_publications,
           count(*) filter (where a.older_draft and not a.attached_photo
             and not a.recorded_submission) as stalled_draft_authors
    from cohort c
    left join author_progress a on a.owner_id = c.id
  ), first_reviews as (
    -- This queue is global. Revisions to published listings have their own
    -- state and do not delay a first publication.
    select count(*) as pending, min(submitted_at) as oldest_submitted_at
    from public.dopmi_adoptions
    where status = 'submitted' and published_at is null
  )
  select jsonb_build_object(
    'generated_at', cutoff,
    'window_started_at', window_start,
    'accounts_created', c.accounts_created,
    'rescuer_mode_accounts', c.rescuer_mode_accounts,
    'authors_with_drafts', c.authors_with_drafts,
    'authors_with_photo', c.authors_with_photo,
    'authors_with_submissions', c.authors_with_submissions,
    'authors_with_publications', c.authors_with_publications,
    'first_reviews_pending', q.pending,
    'oldest_first_review_hours', floor(extract(epoch from (cutoff - q.oldest_submitted_at)) / 3600)::integer,
    'stalled_draft_authors', c.stalled_draft_authors
  ) into report
  from cohort_counts c
  cross join first_reviews q;

  return report;
end;
$$;

revoke all on function public.dopmi_admin_first_publication() from public, anon, authenticated, service_role;
grant execute on function public.dopmi_admin_first_publication() to authenticated;

commit;
