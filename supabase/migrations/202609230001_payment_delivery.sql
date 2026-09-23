begin;

-- Read-only Connect status must not reject a confirmed user merely because
-- their rescuer review is still pending. Starting onboarding remains guarded
-- by dopmi_payment_server('connect_begin').
create function public.dopmi_connect_status(target_actor uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare a private.dopmi_connect_accounts;
begin
  if target_actor is null or not exists(
    select 1 from public.profiles p join auth.users u on u.id=p.id
    where p.id=target_actor and p.account_status='active' and u.email_confirmed_at is not null
  ) then
    raise exception 'Cuenta activa y confirmada requerida' using errcode='42501';
  end if;
  select * into a from private.dopmi_connect_accounts where owner_id=target_actor;
  return coalesce(to_jsonb(a),'{}'::jsonb)||jsonb_build_object('verified',private.dopmi_rescuer_verified(target_actor));
end;
$$;

-- A caller can claim one exact webhook/transfer/refund job. This prevents a
-- successful webhook response from depending on an unrelated queue item.
create function public.dopmi_payment_job_claim(target_key text default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare j private.dopmi_payment_jobs;
begin
  if target_key is not null and length(target_key)>160 then
    raise exception 'Clave de trabajo inválida' using errcode='22023';
  end if;
  select * into j from private.dopmi_payment_jobs
  where (target_key is null or job_key=target_key)
    and ((status='ready' and available_at<=now()) or (status='running' and lease_until<now()))
  order by available_at,id for update skip locked limit 1;
  if not found then
    if target_key is null then return null; end if;
    select * into j from private.dopmi_payment_jobs where job_key=target_key;
    if not found then return null; end if;
    return jsonb_build_object('skipped',true,'status',j.status,'kind',j.kind,'donation_id',j.donation_id,'error_code',j.error_code);
  end if;
  if j.attempts>=8 or (j.kind<>'event' and j.first_attempt_at<now()-interval '23 hours') then
    update private.dopmi_payment_jobs set status='attention',error_code='retry_limit' where id=j.id;
    update public.dopmi_donations set
      transfer_status=case when j.kind='transfer' then 'attention' else transfer_status end,
      refund_status=case when j.kind='refund' then 'attention' else refund_status end
    where id=j.donation_id;
    return jsonb_build_object('skipped',true,'status','attention','kind',j.kind,'donation_id',j.donation_id,'error_code','retry_limit');
  end if;
  update private.dopmi_payment_jobs set status='running',attempts=attempts+1,
    lease=gen_random_uuid(),lease_until=now()+interval '5 minutes',first_attempt_at=coalesce(first_attempt_at,now())
  where id=j.id returning * into j;
  return to_jsonb(j);
end;
$$;

-- Persist processor effects and complete the lease in the same transaction.
-- An error after a successful commit must never downgrade a completed job.
create function public.dopmi_payment_job_finish(data jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare j private.dopmi_payment_jobs; needs_attention boolean;
begin
  select * into j from private.dopmi_payment_jobs
    where id=(data->>'job_id')::uuid and lease=(data->>'lease')::uuid for update;
  if not found then raise exception 'Intento de procesamiento vencido' using errcode='40001'; end if;
  if j.status='done' then return '{}'; end if;
  if j.status<>'running' or j.lease_until<=now() then
    raise exception 'Intento de procesamiento vencido' using errcode='40001';
  end if;
  if data->>'error_code' is not null then
    needs_attention:=coalesce((data->>'attention')::boolean,false);
    update private.dopmi_payment_jobs set status=case when needs_attention then 'attention' else 'ready' end,
      error_code=left(data->>'error_code',80),available_at=now()+make_interval(secs=>least(3600,30*power(2,j.attempts)::integer)),lease_until=null
    where id=j.id;
    update public.dopmi_donations set
      transfer_status=case when j.kind='transfer' and transfer_status not in ('transferred','reversed') then case when needs_attention then 'attention' else 'pending' end else transfer_status end,
      refund_status=case when j.kind='refund' and refund_status<>'refunded' then case when needs_attention then 'attention' else 'pending' end else refund_status end,
      updated_at=now()
    where id=j.donation_id;
  else
    if j.kind='transfer' then
      if coalesce(data->>'result_id','') !~ '^tr_[a-zA-Z0-9_]+$' then raise exception 'Transferencia inválida' using errcode='22023'; end if;
      update public.dopmi_donations set stripe_transfer_id=data->>'result_id',transfer_status='transferred',updated_at=now()
      where id=j.donation_id and payment_status='confirmed' and allocated_cents>0
        and (stripe_transfer_id is null or stripe_transfer_id=data->>'result_id');
      if not found then raise exception 'Transferencia no coincide' using errcode='22023'; end if;
    elsif j.kind='refund' then
      if coalesce(data->>'result_id','') !~ '^re_[a-zA-Z0-9_]+$' then raise exception 'Devolución inválida' using errcode='22023'; end if;
      update public.dopmi_donations set stripe_refund_id=data->>'result_id',refund_status='refunded',updated_at=now(),
        payment_status=case when allocated_cents=0 then 'refunded' else payment_status end,
        status=case when allocated_cents=0 then 'refunded' else status end
      where id=j.donation_id and refund_cents>0 and (stripe_refund_id is null or stripe_refund_id=data->>'result_id');
      if not found then raise exception 'Devolución no coincide' using errcode='22023'; end if;
    end if;
    update private.dopmi_payment_jobs set status='done',lease_until=null,error_code=null where id=j.id;
  end if;
  return '{}';
end;
$$;

-- Reprocessing reads processor identifiers already stored for the donation.
-- It cannot create another Checkout or another charge.
create function public.dopmi_payment_replay_get(target_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$
  select to_jsonb(d)||jsonb_build_object('session_id',c.session_id)
  from public.dopmi_donations d
  left join private.dopmi_checkouts c on c.donation_id=d.id
  where d.id=target_id;
$$;

create or replace function public.dopmi_expense_funding(record_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare r public.dopmi_rescue_records; assigned bigint; reserved bigint; transferred bigint;
begin
  select * into r from public.dopmi_rescue_records where id=record_id;
  if not found or r.kind<>'expense' or not (private.dopmi_rescue_public_visible(r)
    or (r.owner_id=auth.uid() and public.dopmi_actor_active())) then
    raise exception 'Gasto no disponible' using errcode='42501';
  end if;
  select coalesce(sum(allocated_cents),0),coalesce(sum(reserved_cents),0),
    coalesce(sum(allocated_cents) filter(where transfer_status='transferred' and stripe_transfer_id is not null),0)
    into assigned,reserved,transferred from public.dopmi_donations where expense_id=r.id;
  return jsonb_build_object('expense_id',r.id,'title',r.approved_snapshot->>'title','reimbursable_cents',r.reimbursable_cents,
    'funded_cents',assigned,'transferred_cents',transferred,'available_cents',greatest(0,r.reimbursable_cents-assigned-reserved),'payable',private.dopmi_expense_payable(r));
end;
$$;

-- Expose only the aggregate assigned amount with each public expense. Donor
-- identities and processor identifiers remain private.
create or replace function public.dopmi_rescue_public(case_id uuid default null, page_number integer default 1) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
  if page_number is null or page_number<1 then raise exception 'Página inválida' using errcode='22023'; end if;
  return jsonb_build_object('total',(select count(*) from public.dopmi_rescue_records r
      where (case when case_id is null then r.kind='case' else r.id=case_id or r.parent_id=case_id end) and private.dopmi_rescue_public_visible(r)),
    'items',coalesce((select jsonb_agg(x) from (select r.id,r.owner_id,r.kind,r.parent_id,r.status,r.approved_snapshot as public_data,
      r.reimbursable_cents,r.urgent,r.approved_at,
      (select coalesce(sum(d.allocated_cents),0) from public.dopmi_donations d join public.dopmi_rescue_records e on e.id=d.expense_id
        where e.id=r.id or (r.kind='case' and e.parent_id=r.id)) as funded_cents,
      (select coalesce(sum(d.allocated_cents),0) from public.dopmi_donations d join public.dopmi_rescue_records e on e.id=d.expense_id
        where (e.id=r.id or (r.kind='case' and e.parent_id=r.id)) and d.transfer_status='transferred' and d.stripe_transfer_id is not null) as transferred_cents,
      (select approved_snapshot->>'public_name' from public.dopmi_rescue_records where owner_id=r.owner_id and kind='verification') as rescuer_name
      from public.dopmi_rescue_records r where (case when case_id is null then r.kind='case' else r.id=case_id or r.parent_id=case_id end)
      and private.dopmi_rescue_public_visible(r) order by r.kind,r.approved_at desc,r.id limit 20 offset (page_number::bigint-1)*20)x),'[]'));
end;
$$;

revoke all on function public.dopmi_connect_status(uuid),public.dopmi_payment_job_claim(text),public.dopmi_payment_job_finish(jsonb),public.dopmi_payment_replay_get(uuid)
  from public,anon,authenticated;
grant execute on function public.dopmi_connect_status(uuid),public.dopmi_payment_job_claim(text),public.dopmi_payment_job_finish(jsonb),public.dopmi_payment_replay_get(uuid)
  to service_role;

commit;
