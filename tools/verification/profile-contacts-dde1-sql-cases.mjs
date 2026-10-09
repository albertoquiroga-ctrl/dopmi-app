import { test } from 'node:test';
import assert from 'node:assert/strict';

export function registerProfileContactsSqlCases(getDb, { rescuer, staff, other }) {
  const payload = {
    display_name: 'Refugio de prueba', bio: 'Rescatamos y cuidamos animales con responsabilidad.',
    city: 'Monterrey', region: 'Nuevo León', public_email: 'public@example.test',
    public_phone: '+525512345678', public_address: 'Dirección pública de prueba',
    website_url: 'https://example.test/refugio', contact_consent: true,
  };
  async function actor(db, id, role = 'authenticated') {
    await db.exec('reset role');
    await db.query("select set_config('request.jwt.claim.sub',$1,true)", [id]);
    await db.exec(`set local role ${role}`);
  }
  async function save(db, data, version = null) {
    return (await db.query('select public.dopmi_save_rescuer_profile($1::jsonb,$2) value', [JSON.stringify(data), version])).rows[0].value;
  }
  async function transition(db, version, action) {
    return (await db.query('select public.dopmi_transition_rescuer_profile($1,$2) value', [version, action])).rows[0].value;
  }
  async function publicProfile(db) {
    return (await db.query('select public.dopmi_rescuer_public($1) value', [rescuer])).rows[0].value;
  }
  async function reject(db, operation, pattern) {
    await db.exec('savepoint negative_case');
    try { await assert.rejects(operation, pattern); }
    finally { await db.exec('rollback to negative_case; release negative_case'); }
  }
  async function confirmPhone(db) {
    await db.exec('reset role');
    await db.query('update auth.users set phone=$1,phone_confirmed_at=now() where id=$2', ['525512345678', rescuer]);
    await actor(db, rescuer);
  }
  async function approve(db, profile, feedback = {}) {
    const submitted = await transition(db, profile.version, 'submit');
    await actor(db, staff);
    const approved = (await db.query('select public.dopmi_review_rescuer_profile_v2($1,$2,$3,$4,$5::jsonb) value',
      [rescuer, submitted.version, 'published', '', JSON.stringify(feedback)])).rows[0].value;
    await actor(db, rescuer);
    return approved;
  }

  test('dde1 public contacts require verified phone and approval; private identity is preserved', async () => {
    const db = getDb();
    const identity = (await db.query('select to_jsonb(r) value from public.dopmi_rescue_records r where owner_id=$1 and kind=$2', [rescuer, 'verification'])).rows;
    const connect = (await db.query('select to_jsonb(c) value from private.dopmi_connect_accounts c where owner_id=$1', [rescuer])).rows;
    await actor(db, rescuer);
    let profile = await save(db, payload);
    assert.equal(profile.contact_publication_enabled, false);
    assert.equal((await publicProfile(db)).public_email, '');
    await reject(db, () => transition(db, profile.version, 'submit'), /Verifica el/);
    await confirmPhone(db);
    profile = await approve(db, profile);
    const published = await publicProfile(db);
    assert.equal(published.public_email, payload.public_email);
    assert.equal(published.public_phone, payload.public_phone);
    assert.equal(published.website_url, payload.website_url);
    profile = await save(db, { ...payload, public_email: 'unapproved@example.test' }, profile.version);
    assert.equal((await publicProfile(db)).public_email, payload.public_email);
    await reject(db, () => save(db, payload, profile.version - 1), /perfil cambió/);
    await db.exec('reset role');
    assert.deepEqual((await db.query('select to_jsonb(r) value from public.dopmi_rescue_records r where owner_id=$1 and kind=$2', [rescuer, 'verification'])).rows, identity);
    assert.deepEqual((await db.query('select to_jsonb(c) value from private.dopmi_connect_accounts c where owner_id=$1', [rescuer])).rows, connect);
  });

  test('dde1 contact withdrawal hides immediately during review; re-enable needs new approval', async () => {
    const db = getDb();
    await confirmPhone(db);
    let profile = await approve(db, await save(db, payload));
    profile = await save(db, payload, profile.version);
    profile = await transition(db, profile.version, 'submit');
    profile = await transition(db, profile.version, 'revoke_contacts');
    let published = await publicProfile(db);
    assert.equal(published.public_email, '');
    assert.equal(published.public_address, '');
    assert.equal(published.public_phone, '');
    assert.equal(published.website_url, '');
    assert.equal(published.name, payload.display_name);
    profile = await transition(db, profile.version, 'withdraw');
    profile = await save(db, payload, profile.version);
    assert.equal((await publicProfile(db)).public_email, '');
    await approve(db, profile);
    assert.equal((await publicProfile(db)).public_email, payload.public_email);
  });

  test('dde1 field feedback is bounded and admin-only; editable metadata never grants review', async () => {
    const db = getDb();
    await confirmPhone(db);
    let profile = await transition(db, (await save(db, payload)).version, 'submit');
    await db.exec('reset role');
    await db.query("update auth.users set raw_user_meta_data=raw_user_meta_data||'{\"is_admin\":true}'::jsonb where id=$1", [other]);
    await actor(db, other);
    const review = fields => db.query('select public.dopmi_review_rescuer_profile_v2($1,$2,$3,$4,$5::jsonb)',
      [rescuer, profile.version, 'changes_requested', 'Corrige la descripción.', JSON.stringify(fields)]);
    await reject(db, () => review({ bio: 'Aclara tu experiencia.' }), /administrativo/);
    await actor(db, staff);
    await reject(db, () => review({ is_admin: 'sí' }), /Observaciones/);
    await reject(db, () => review({ bio: true }), /Observaciones/);
    await reject(db, () => review({ bio: 'a'.repeat(501) }), /Observaciones/);
    await review({ bio: 'Aclara tu experiencia.' });
    await actor(db, rescuer);
    profile = (await db.query('select public.dopmi_my_rescuer_profile() value')).rows[0].value;
    assert.deepEqual(profile.field_feedback, { bio: 'Aclara tu experiencia.' });
    await actor(db, '', 'anon');
    await reject(db, () => db.query('select public.dopmi_save_rescuer_profile($1::jsonb)', [JSON.stringify(payload)]), /permission denied/);
  });
}
