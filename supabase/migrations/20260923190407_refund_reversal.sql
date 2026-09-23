begin;
alter table public.dopmi_donations add column external_refund_pending boolean not null default false;
alter table public.dopmi_donations add column stripe_reversal_id text unique;
alter table private.dopmi_payment_jobs drop constraint dopmi_payment_jobs_kind_check;
alter table private.dopmi_payment_jobs add constraint dopmi_payment_jobs_kind_check check(kind in ('event','transfer','refund','reversal'));
create table private.dopmi_refund_adjustments (
 donation_id uuid primary key references public.dopmi_donations(id),
 before_state jsonb not null, refund_ids jsonb, reversal_id text, completed_at timestamptz,
 created_at timestamptz not null default now()
);
alter table private.dopmi_refund_adjustments enable row level security;
revoke all on private.dopmi_refund_adjustments from public,anon,authenticated;

-- Only a signature-verified webhook or authenticated server worker can invoke.
-- Hold the assignment until both the refund and reversal are verified in Stripe.
create function public.dopmi_refund_adjustment(operation text, data jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare d public.dopmi_donations; j private.dopmi_payment_jobs;
begin
 if operation='begin' then
   select * into j from private.dopmi_payment_jobs where job_key='transfer:'||(data->>'donation_id') for update;
   if not found or j.status<>'done' then
     raise exception 'Transferencia pendiente de conciliación' using errcode='40001';
   end if;
   select * into d from public.dopmi_donations where id=(data->>'donation_id')::uuid for update;
   if not found then raise exception 'Aportación inexistente' using errcode='22023'; end if;
   if d.payment_status='refunded' and d.transfer_status='reversed' then return to_jsonb(d); end if;
   if d.stripe_transfer_id is null or d.allocated_cents<=0 or d.payment_status<>'confirmed' then
     raise exception 'Revisión manual requerida' using errcode='22023';
   end if;
   insert into private.dopmi_refund_adjustments(donation_id,before_state) values(d.id,to_jsonb(d)) on conflict do nothing;
   insert into private.dopmi_payment_jobs(job_key,kind,donation_id) values('reversal:'||d.id,'reversal',d.id) on conflict do nothing;
   update public.dopmi_donations set external_refund_pending=true,refund_status='pending',transfer_status='attention',updated_at=now() where id=d.id returning * into d;
   return to_jsonb(d);
 elsif operation='finish' then
   select * into j from private.dopmi_payment_jobs where id=(data->>'job_id')::uuid and lease=(data->>'lease')::uuid for update;
   if not found or j.kind<>'reversal' then raise exception 'Intento inválido' using errcode='40001'; end if;
   if j.status='done' then return '{}'; end if;
   if j.status<>'running' or j.lease_until<=now() then raise exception 'Intento vencido' using errcode='40001'; end if;
   select * into d from public.dopmi_donations where id=j.donation_id for update;
   if not d.external_refund_pending or data->>'charge_id' is distinct from d.stripe_charge_id
      or data->>'transfer_id' is distinct from d.stripe_transfer_id
      or (data->>'refund_cents')::bigint is distinct from d.gross_cents
      or (data->>'reversed_cents')::bigint is distinct from d.allocated_cents
      or coalesce(data->>'reversal_id','') !~ '^trr_[a-zA-Z0-9_]+$'
      or coalesce(data->>'refund_id','') !~ '^re_[a-zA-Z0-9_]+$' then
     raise exception 'Conciliación no coincide' using errcode='22023';
   end if;
   update private.dopmi_refund_adjustments set refund_ids=data->'refund_ids',reversal_id=data->>'reversal_id',completed_at=now() where donation_id=d.id;
   update public.dopmi_donations set allocated_cents=0,reserved_cents=0,net_cents=gross_cents,refund_cents=gross_cents,
     platform_fee_cents=0,platform_loss_cents=stripe_fee_cents,status='refunded',payment_status='refunded',
     transfer_status='reversed',refund_status='refunded',external_refund_pending=false,
     stripe_refund_id=data->>'refund_id',stripe_reversal_id=data->>'reversal_id',updated_at=now() where id=d.id;
   update private.dopmi_payment_jobs set status='done',lease_until=null,error_code=null where id=j.id;
   return '{}';
 end if;
 raise exception 'Operación inválida' using errcode='22023';
end;
$$;
revoke all on function public.dopmi_refund_adjustment(text,jsonb) from public,anon,authenticated;
grant execute on function public.dopmi_refund_adjustment(text,jsonb) to service_role;

create or replace function public.dopmi_payment_job_claim(target_key text default null) returns jsonb
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
      refund_status=case when j.kind in ('refund','reversal') then 'attention' else refund_status end
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
create or replace function public.dopmi_payment_job_finish(data jsonb) returns jsonb
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
      refund_status=case when j.kind in ('refund','reversal') and refund_status<>'refunded' then case when needs_attention then 'attention' else 'pending' end else refund_status end,
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


commit;
