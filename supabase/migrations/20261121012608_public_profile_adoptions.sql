begin;

-- Owners without a shelter seal use this profile response. Include the same
-- approved adoption projection as the full rescuer profile.
do $migration$
declare
  target regprocedure := to_regprocedure('public.dopmi_public_profile(uuid)');
  function_body text;
  existing_field text := $old$    'adopted_count',$old$;
  replacement_fields text := $new$    'adoptions',coalesce((
      select jsonb_agg(private.dopmi_public_post(listing) order by listing.published_at desc,listing.id)
      from public.dopmi_adoptions listing
      where listing.owner_id=person_id and listing.status='published'
    ),'[]'::jsonb),
    'adopted_count',$new$;
begin
  if target is null then
    raise exception 'Public profile adoption list: expected function is missing';
  end if;
  function_body := replace(pg_get_functiondef(target), E'\r\n', E'\n');
  if strpos(function_body, $field$'adoptions',$field$)>0 or
    (length(function_body)-length(replace(function_body,existing_field,'')))/length(existing_field)<>1 then
    raise exception 'Public profile adoption list: unexpected function definition';
  end if;
  -- Replacing the existing function preserves its owner, OID and grants.
  execute replace(function_body,existing_field,replacement_fields);
end;
$migration$;

commit;
