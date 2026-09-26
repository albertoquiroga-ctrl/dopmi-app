// Local recovery drill. Snapshot stays outside Git; never connects remotely.
import pg from 'pg';
import { execFileSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { readFile, readdir } from 'node:fs/promises';
import { resolve } from 'node:path';
import assert from 'node:assert/strict';
const quote = value => '"' + value.replaceAll('"', '""') + '"';
const literal = value => "'" + value.replaceAll("'", "''") + "'";
let stage = 'read snapshot';
const databaseName = 'dopmi_h7_restore_' + randomUUID().replaceAll('-', '');
let databaseCreated = false;
// Fixed loopback target, never accepts a remote URL or an existing database name.
const client = new pg.Client({host:'127.0.0.1',port:54322,user:'postgres',password:'postgres',database:databaseName});
const db = {exec: sql => client.query(sql), query: (sql,values) => client.query(sql,values)};
try {
  execFileSync('docker',['exec','supabase_db_dopmi','psql','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1','-c',`create database ${databaseName}`],{stdio:'pipe'});
  databaseCreated = true;
  await client.connect();
  const directory = resolve(process.argv[2] ?? '../../.tools/legacy-backup');
  const data = JSON.parse(await readFile(resolve(directory, 'database.json'), 'utf8'));
  const metadata = JSON.parse(await readFile(resolve(directory, 'metadata.json'), 'utf8'));
  const migrationDirectory = new URL('../../supabase/migrations/', import.meta.url);
  stage = 'platform bootstrap';
  const fixture = await readFile(new URL('payments.test.mjs', import.meta.url), 'utf8');
  await db.exec(fixture.match(/await db.exec\(`([\s\S]*?)`\);/)[1].replaceAll(/create role (anon|authenticated|service_role);/g,''));
  await db.exec('create extension postgis; create domain public.geography_point as geography(Point,4326);');
  const platform = JSON.parse(await readFile(resolve(directory, 'platform.json'), 'utf8'));
  for (const definition of Object.values(platform)) await db.exec(definition);
  await db.exec('create schema cron; create function cron.alter_job(job_id bigint, active boolean) returns void language plpgsql as $fn$ begin update cron.job j set active=alter_job.active where j.jobid=job_id; end $fn$; create table cron.job(jobid bigserial,jobname text primary key, active boolean);');
  for (const name of ['cleanup-expired-spei','close-expired-sponsor-windows','sponsorship-cycle-warnings','dopmi-payment-worker-reconcile']) {
    await db.query('insert into cron.job(jobname,active) values($1,true)', [name]);
  }
  stage = 'restore types and tables';
  for (const type of data.enums) await db.exec(`create type ${quote(type.schema)}.${quote(type.typname)} as enum (${type.labels.map(literal).join(',')})`);
  for (const name of Object.keys(data.data)) {
    const columns = data.columns.filter(column => column.table_name === name).map(column =>
      `${quote(column.name)} ${column.type}${column.default_value ? ' default ' + column.default_value : ''}${column.not_null ? ' not null' : ''}`);
    await db.exec(`create table public.${quote(name)} (${columns.join(',')})`);
    await db.query(`insert into public.${quote(name)} select * from jsonb_populate_recordset(null::public.${quote(name)},$1::jsonb)`, [JSON.stringify(data.data[name])]);
  }
  for (const constraint of [...data.constraints].sort((a,b) => Number(a.type === 'f') - Number(b.type === 'f'))) {
    await db.exec(`alter table public.${quote(constraint.table_name)} add constraint ${quote(constraint.name)} ${constraint.definition}`);
  }
  stage = 'restore routines, views, indexes, triggers and policies';
  for (const fn of metadata.functions) await db.exec(fn.definition);
  for (const view of metadata.views) await db.exec(`create ${view.kind === 'm' ? 'materialized ' : ''}view public.${quote(view.name)} as ${view.definition}`);
  for (const index of metadata.indexes) {
    if (!(await db.query('select to_regclass($1) as oid', ['public.' + quote(index.indexname)])).rows[0].oid) await db.exec(index.indexdef);
  }
  for (const trigger of metadata.triggers) await db.exec(trigger.definition);
  for (const policy of metadata.policies) {
    await db.exec(`create policy ${quote(policy.policyname)} on ${quote(policy.schemaname)}.${quote(policy.tablename)} as ${policy.permissive} for ${policy.cmd} to ${policy.roles.map(quote).join(',')}${policy.qual ? ' using (' + policy.qual + ')' : ''}${policy.with_check ? ' with check (' + policy.with_check + ')' : ''}`);
  }
  for (const table of metadata.table_acl) if (table.rls) await db.exec(`alter table public.${quote(table.name)} enable row level security`);
  // Broad fixture grants make the retirement assertions exercise revocation too.
  await db.exec('grant all on all tables in schema public to anon,authenticated,service_role; grant execute on all functions in schema public to anon,authenticated,service_role;');
  for (const bucket of metadata.buckets) await db.query('insert into storage.buckets(id,name,public) values($1,$1,$2)', [bucket.id,bucket.public]);
  const snapshots = async schema => {
    const result = {};
    for (const name of Object.keys(data.data)) result[name] = (await db.query(`select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text),'[]'::jsonb) as rows from ${quote(schema)}.${quote(name)} t`)).rows[0].rows;
    return result;
  };
  const before = await snapshots('public');
  stage = 'apply current migrations and archive';
  const migrations = (await readdir(migrationDirectory)).filter(name => name.endsWith('.sql')).sort();
  for (const file of migrations) await db.exec(await readFile(new URL(file,migrationDirectory), 'utf8'));
  assert.deepEqual(await snapshots('dopmi_legacy'), before);
  for (const role of ['anon','authenticated','service_role']) {
    assert.equal((await db.query('select has_schema_privilege($1,\'dopmi_legacy\',\'USAGE\') as allowed',[role])).rows[0].allowed,false);
    for (const name of Object.keys(data.data)) assert.equal((await db.query('select has_table_privilege($1,$2,\'SELECT\') as allowed',[role,'dopmi_legacy.' + quote(name)])).rows[0].allowed,false);
  }
  assert.equal((await db.query('select count(*)::int n from cron.job where active')).rows[0].n,1);
  assert.equal((await db.query("select active from cron.job where jobname='dopmi-payment-worker-reconcile'")).rows[0].active,true);
  assert.equal((await db.query("select count(*)::int n from pg_policies where schemaname='storage' and policyname not like 'dopmi_%'")).rows[0].n,0);
  stage = 'verify current signup survives archival';
  await db.exec("insert into auth.users(id,email) values('00000000-0000-4000-8000-999999999999','restore-drill@example.test')");
  assert.equal((await db.query("select count(*)::int n from public.profiles where id='00000000-0000-4000-8000-999999999999'")).rows[0].n,1);
  stage = 'verify recovery of archived rows';
  // Transactional reverse move proves data/constraints survive, without enabling old APIs.
  await db.exec('begin');
  for (const name of Object.keys(data.data)) await db.exec(`alter table dopmi_legacy.${quote(name)} set schema public`);
  assert.deepEqual(await snapshots('public'), before);
  await db.exec('rollback');
  console.log(JSON.stringify({restoredTables:Object.keys(data.data).length,restoredRows:Object.values(data.data).reduce((sum,rows)=>sum+rows.length,0),constraints:data.constraints.length,routines:metadata.functions.length,archiveAndRecovery:'passed',currentSignup:'passed',clientAccess:'denied',financialCron:'preserved',storageBlobs:'not copied or deleted'}));
} catch (error) {
  // Do not leak snapshot rows, query parameters or credentials into CI/chat logs.
  console.error(`Recovery drill failed at ${stage}; code=${error.code ?? error.name}`);
  process.exitCode = 1;
} finally {
  await client.end();
  if (databaseCreated) execFileSync('docker',['exec','supabase_db_dopmi','psql','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1','-c',`drop database ${databaseName}`],{stdio:'pipe'});
}

