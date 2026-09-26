import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';

test('legacy archive closes inherited grants, keeps current signup/storage/cron, and preserves rows', async () => {
  const db = new PGlite();
  try {
    const fixture = await readFile(new URL('payments.test.mjs', import.meta.url), 'utf8');
    await db.exec(fixture.match(/await db.exec\(`([\s\S]*?)`\);/)[1]);
    await db.exec(`
      create table public.users(id uuid primary key, email text, role text);
      create table public.pets(id uuid primary key, rescuer_id uuid references public.users);
      insert into public.users values('00000000-0000-4000-8000-000000000001','legacy@example.test','user');
      insert into public.pets values('00000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000001');
      grant all on public.users, public.pets to anon,authenticated,service_role;
      grant update(rescuer_id) on public.pets to authenticated;
      create function public.handle_new_auth_user() returns trigger language plpgsql security definer as $$
        begin insert into public.users values(new.id,new.email,'user'); return new; end $$;
      create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_auth_user();
      create function public.is_admin(uid uuid) returns boolean language sql security definer as $$select exists(select 1 from public.users where id=uid and role='admin')$$;
      grant execute on function public.is_admin(uuid) to anon,authenticated,service_role;
      create view public.v_deprecated_sponsorships as select * from public.users;
      create materialized view public.v_fund_pool_balance as select count(*) from public.pets;
      grant select on public.v_deprecated_sponsorships,public.v_fund_pool_balance to anon,authenticated;
      insert into storage.buckets(id,name,public) values('avatars','avatars',true);
      create policy avatars_read on storage.objects for select using(bucket_id='avatars');
      create schema cron; create function cron.alter_job(job_id bigint, active boolean) returns void language plpgsql as $fn$ begin update cron.job j set active=alter_job.active where j.jobid=job_id; end $fn$; create table cron.job(jobid bigserial,jobname text,active boolean);
      insert into cron.job(jobname,active) values('cleanup-expired-spei',true),('close-expired-sponsor-windows',true),('sponsorship-cycle-warnings',true),('dopmi-payment-worker-reconcile',true);
    `);
    const directory = new URL('../../supabase/migrations/', import.meta.url);
    for (const file of (await readdir(directory)).filter(name=>name.endsWith('.sql')).sort()) await db.exec(await readFile(new URL(file,directory),'utf8'));
    assert.equal((await db.query("select to_regclass('public.pets') as object")).rows[0].object,null);
    assert.equal((await db.query('select count(*)::int n from dopmi_legacy.pets')).rows[0].n,1);
    for (const role of ['anon','authenticated','service_role']) {
      assert.equal((await db.query("select has_schema_privilege($1,'dopmi_legacy','USAGE') allowed",[role])).rows[0].allowed,false);
      assert.equal((await db.query("select has_table_privilege($1,'dopmi_legacy.v_deprecated_sponsorships','SELECT') allowed",[role])).rows[0].allowed,false);
      assert.equal((await db.query("select has_function_privilege($1,'dopmi_legacy.is_admin(uuid)','EXECUTE') allowed",[role])).rows[0].allowed,false);
      assert.equal((await db.query("select has_column_privilege($1,'dopmi_legacy.pets','rescuer_id','UPDATE') allowed",[role])).rows[0].allowed,false);
    }
    assert.equal((await db.query("select public from storage.buckets where id='avatars'")).rows[0].public,false);
    assert.equal((await db.query("select count(*)::int n from pg_policies where schemaname='storage' and policyname like 'dopmi_%'")).rows[0].n,14);
    assert.deepEqual((await db.query('select jobname from cron.job where active')).rows,[{jobname:'dopmi-payment-worker-reconcile'}]);
    await db.exec("insert into auth.users(id,email) values('00000000-0000-4000-8000-000000000003','new@example.test')");
    assert.equal((await db.query("select count(*)::int n from public.profiles where id='00000000-0000-4000-8000-000000000003'")).rows[0].n,1);
    assert.equal((await db.query('select count(*)::int n from dopmi_legacy.users')).rows[0].n,1);
    // Reverse table movement keeps its foreign key valid and its data intact.
    await db.exec('alter table dopmi_legacy.users set schema public; alter table dopmi_legacy.pets set schema public;');
    assert.equal((await db.query('select count(*)::int n from public.pets join public.users on users.id=pets.rescuer_id')).rows[0].n,1);
  } finally { await db.close(); }
});

