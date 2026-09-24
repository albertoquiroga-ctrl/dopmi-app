-- Keep the existing service-only gateway, its grants and all other payment
-- operations intact. PL/pgSQL declares a row variable `d`; using `d` as a SQL
-- alias in this branch makes the reference `d.id` ambiguous (SQLSTATE 42702).
do $fix$
declare
  definition text;
  old_select constant text := 'select d.id,c.session_id from public.dopmi_donations d join private.dopmi_checkouts c on c.donation_id=d.id';
  new_select constant text := 'select donation.id,c.session_id from public.dopmi_donations donation join private.dopmi_checkouts c on c.donation_id=donation.id';
  old_filter constant text := 'where d.payment_status=''pending'' and c.session_id is not null order by d.updated_at,d.id limit 50';
  new_filter constant text := 'where donation.payment_status=''pending'' and c.session_id is not null order by donation.updated_at,donation.id limit 50';
begin
  definition := pg_get_functiondef('public.dopmi_payment_server(text,jsonb)'::regprocedure);
  if position(old_select in definition) = 0 or position(old_filter in definition) = 0 then
    raise exception 'Unexpected dopmi_payment_server definition; review before altering it';
  end if;
  execute replace(replace(definition, old_select, new_select), old_filter, new_filter);
end
$fix$;
