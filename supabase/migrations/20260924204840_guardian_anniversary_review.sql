begin;

alter table private.dopmi_guardian_requests
 drop constraint dopmi_guardian_requests_status_check,
 add constraint dopmi_guardian_requests_status_check check(status in ('pending','applied','superseded','withdrawn')),
 add column withdrawn_at timestamptz,
 add column verified_period_start bigint check(verified_period_start between 1 and 4102444800),
 add column boundary_invoice_id text check(boundary_invoice_id ~ '^in_[A-Za-z0-9]+$'),
 add constraint dopmi_guardian_request_withdrawn check((status='withdrawn')=(withdrawn_at is not null));

-- Every new reservation must still match the invoice the worker verified,
-- after taking the same plan lock as amount changes and cancellation.
do $patch$
declare definition text; old_text text; new_text text;
begin
 definition:=pg_get_functiondef('public.dopmi_guardian_collection_server(text,jsonb)'::regprocedure);
 old_text:='hold:=public.dopmi_guardian_reserve(p.donor_id,(data->>''cycle_key'')::uuid,p.gross_cents);';
 new_text:='if data->>''verified_price_id'' is distinct from p.stripe_price_id
 or (data->>''verified_gross_cents'')::bigint is distinct from p.gross_cents then
 raise exception ''La factura no coincide con el importe vigente para su período'' using errcode=''40001''; end if; '||old_text;
 if position(old_text in definition)=0 then raise exception 'Review collection snapshot guard'; end if;
 execute replace(definition,old_text,new_text);

 definition:=pg_get_functiondef('public.dopmi_guardian_change_server(text,jsonb)'::regprocedure);
 old_text:='insert into private.dopmi_guardian_prices(subscription_id,revision,effective_from,price_id,gross_cents,request_id)';
 new_text:='if (data->>''verified_period_start'')::bigint is null
 or (data->>''verified_period_start'')::bigint<r.period_start
 or ((data->>''verified_period_start'')::bigint<>r.period_start and (
   (data->>''verified_period_start'')::bigint<r.effective_from
   or coalesce(data->>''boundary_invoice_id'','''') !~ ''^in_[A-Za-z0-9]+$''
   or (data->>''boundary_period_start'')::bigint is distinct from r.effective_from
   or data->>''boundary_price_id'' is distinct from r.price_id
   or (data->>''boundary_gross_cents'')::bigint is distinct from r.new_gross_cents)) then
 raise exception ''Falta evidencia del precio en el aniversario'' using errcode=''22023''; end if;
 update private.dopmi_guardian_requests set verified_period_start=(data->>''verified_period_start'')::bigint,
 boundary_invoice_id=data->>''boundary_invoice_id'' where id=r.id; '||old_text;
 if position(old_text in definition)=0 then raise exception 'Review change boundary confirmation'; end if;
 execute replace(definition,old_text,new_text);
end $patch$;

create or replace function private.dopmi_guardian_request_view(target uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',r.id,'kind',r.kind,'revision',r.revision,'status',r.status,
 'previous_gross_cents',r.previous_gross_cents,'new_gross_cents',r.new_gross_cents,
 'created_at',r.created_at,'applied_at',r.applied_at,'withdrawn_at',r.withdrawn_at,
 'effective_at',case when r.status='applied' and r.kind='amount' then to_timestamp(r.effective_from) else null end,
 'can_withdraw',r.status='pending' and r.kind='amount' and r.mutation_requested_at is null
   and p.status='active' and p.cancellation_requested_at is null and p.management_revision=r.revision,
 'review_reason',case when r.status<>'pending' or r.error_code is null then null
   when r.error_code='guardian_change_too_late' then 'near_anniversary'
   when r.error_code in ('guardian_change_calendar_changed','guardian_change_unconfirmed') or r.error_code like 'guardian_change_boundary_%' then 'period_review'
   when r.error_code='change_retry_limit' then 'retry_limit' else 'processor_review' end)
 from private.dopmi_guardian_requests r join private.dopmi_guardian_subscriptions p on p.stripe_subscription_id=r.subscription_id
 where r.id=target;
$$;

-- Explicit owner withdrawal only while no subscription mutation has been
-- authorized. It competes under the plan lock with mutation authorization.
-- A lost response is recoverable by replaying the same request ID.
create function public.dopmi_guardian_withdraw_amount(request_id uuid,expected_revision bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); r private.dopmi_guardian_requests; p private.dopmi_guardian_subscriptions; subscription text;
begin
 if actor is null then raise exception 'Sesión requerida' using errcode='42501'; end if;
 select q.subscription_id into subscription from private.dopmi_guardian_requests q where q.id=request_id and q.donor_id=actor and q.kind='amount';
 if not found then raise exception 'Solicitud no disponible' using errcode='42501'; end if;
 select * into p from private.dopmi_guardian_subscriptions where stripe_subscription_id=subscription for update;
 select * into r from private.dopmi_guardian_requests where id=request_id for update;
 if r.status='withdrawn' then return public.dopmi_guardian_state(); end if;
 if expected_revision is null or p.management_revision<>expected_revision or r.revision<>expected_revision
 or r.status<>'pending' or r.mutation_requested_at is not null
 or p.status<>'active' or p.cancellation_requested_at is not null then
 raise exception 'El cambio ya avanzó; consulta su estado antes de continuar' using errcode='40001'; end if;
 update private.dopmi_guardian_requests set status='withdrawn',withdrawn_at=now(),error_code=null where id=r.id;
 update private.dopmi_guardian_subscriptions set management_revision=management_revision+1,
 change_lease_until=case when change_request_id=r.id then null else change_lease_until end where donor_id=actor;
 return public.dopmi_guardian_state();
end; $$;
revoke all on function public.dopmi_guardian_withdraw_amount(uuid,bigint) from public,anon,authenticated,service_role;
grant execute on function public.dopmi_guardian_withdraw_amount(uuid,bigint) to authenticated;
commit;
