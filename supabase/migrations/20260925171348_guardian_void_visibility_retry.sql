begin;

-- Repair only the retry queue stranded by the previous collector when Stripe
-- exposed invoice.void before PaymentIntent cancellation. No financial state,
-- reservation, authorization marker, retry count or Stripe reference changes.
-- The corrected worker must independently verify invoice + default payment +
-- intent before closing a cycle. Deploy it before applying this repair.
update private.dopmi_guardian_collection_jobs
set status='pending', available_at=greatest(available_at,now())
where status='attention' and decision='skip' and pay_requested_at is null
  and error_code='guardian_recovery_void_unconfirmed'
  and attempts<8 and first_attempt_at>=now()-interval '23 hours'
  and (lease_until is null or lease_until<=now());

commit;
