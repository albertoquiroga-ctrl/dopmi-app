import { test } from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { PGlite } from "@electric-sql/pglite";
import {
  authorizationUrl,
  providerIdentity,
  socialCallback,
  socialConfig,
  socialHandler,
  socialMetaHandler,
  stateHash,
  verifyMetaRequest,
} from "../../supabase/functions/_shared/social-verification.mjs";
const env = (k) =>
  ({
    SOCIAL_VERIFICATION_ENABLED: "true",
    SOCIAL_FACEBOOK_CLIENT_ID: "123",
    SOCIAL_FACEBOOK_CLIENT_SECRET: "private",
    SOCIAL_VERIFICATION_CALLBACK_URL:
      "https://example.supabase.co/functions/v1/social-verification-callback",
  })[k];
test("configuration is closed; authorization asks only basic scope and exact callback", () => {
  assert.equal(socialConfig(() => undefined, "facebook"), null);
  assert.equal(socialConfig(env, "other"), null);
  const url = new URL(
    authorizationUrl(socialConfig(env, "facebook"), "one-use"),
  );
  assert.equal(url.searchParams.get("scope"), "public_profile");
  assert.equal(url.searchParams.get("state"), "one-use");
  assert.equal(url.searchParams.has("client_secret"), false);
});
test("unauthenticated requests and cross-session status cannot read evidence", async () => {
  const req = (body) =>
    new Request("https://test", {
      method: "POST",
      headers: { Authorization: "Bearer valid" },
      body: JSON.stringify(body),
    });
  assert.equal(
    (await socialHandler({ authenticate: async () => null })(
      req({ operation: "list" }),
    )).status,
    401,
  );
  let args;
  const handler = socialHandler({
    authenticate: async () => ({ id: "actor", session_id: "session" }),
    status: async (...a) => {
      args = a;
      return null;
    },
  });
  assert.equal(
    (await handler(req({ operation: "status", attempt_id: "other" }))).status,
    404,
  );
  assert.deepEqual(args, ["actor", "session", "other"]);
});
test("callback rejects missing/replayed states and denial never exchanges token", async () => {
  let exchanged = false;
  const handler = socialCallback({
    consume: async () => null,
    fetcher: () => {
      exchanged = true;
    },
  });
  assert.equal(
    (await handler(new Request("https://test?state=used&code=secret"))).status,
    400,
  );
  let failed;
  const denied = socialCallback({
    consume: async () => ({ id: "attempt" }),
    fail: async (...a) => {
      failed = a;
    },
    fetcher: () => {
      exchanged = true;
    },
  });
  assert.equal(
    (await denied(new Request("https://test?state=valid&error=access_denied")))
      .status,
    200,
  );
  assert.deepEqual(failed, ["attempt", "denied"]);
  assert.equal(exchanged, false);
});
test("provider proof requires authoritative ID and rejects personal Instagram", async () => {
  let n = 0;
  const fetcher = async () =>
    new Response(
      JSON.stringify(
        ++n === 1 ? { access_token: "private" } : { id: "42", name: "Ana" },
      ),
    );
  assert.deepEqual(
    await providerIdentity(socialConfig(env, "facebook"), "code", fetcher),
    { subject: "42", label: "Ana" },
  );
  n = 0;
  await assert.rejects(
    providerIdentity(
      {
        provider: "instagram",
        client: "1",
        secret: "s",
        redirect: "https://test",
      },
      "c",
      async () =>
        new Response(JSON.stringify(
          ++n === 1
            ? { access_token: "private" }
            : { user_id: "42", username: "ana", account_type: "PERSONAL" },
        )),
    ),
    /professional_required/,
  );
});
test("SQL consumes once; expires; session ownership; unique social owner; client cannot write; delete cascades", async () => {
  const db = new PGlite();
  const owner = "00000000-0000-4000-8000-000000000001",
    other = "00000000-0000-4000-8000-000000000002",
    session = "00000000-0000-4000-8000-000000000003";
  try {
    await db.exec(
      `create role anon;create role authenticated;create role service_role;create schema auth;create table auth.users(id uuid primary key);create table auth.sessions(id uuid primary key,user_id uuid,not_after timestamptz);insert into auth.users values('${owner}'),('${other}');insert into auth.sessions(id,user_id) values('${session}','${owner}');`,
    );
    await db.exec(
      await readFile(
        new URL(
          "../../supabase/migrations/20261009205039_social_verification.sql",
          import.meta.url,
        ),
        "utf8",
      ),
    );
    const insert = async (user, hash, expiry = "now()+interval '10 minutes'") =>
      (await db.query(
        `insert into public.social_verification_attempts(owner_id,session_id,provider,state_hash,expires_at) values($1,$2,'facebook',$3,${expiry}) returning id`,
        [user, session, hash],
      )).rows[0].id;
    const hash = await stateHash("first"), id = await insert(owner, hash);
    assert.equal(
      (await db.query("select * from public.social_verification_consume($1)", [
        hash,
      ])).rows.length,
      1,
    );
    assert.equal(
      (await db.query("select * from public.social_verification_consume($1)", [
        hash,
      ])).rows.length,
      0,
    );
    await db.query("select public.social_verification_finish($1,$2,$3)", [
      id,
      "42",
      "Ana",
    ]);
    const expired = await stateHash("expired");
    await insert(owner, expired, "now()-interval '1 second'");
    assert.equal(
      (await db.query("select * from public.social_verification_consume($1)", [
        expired,
      ])).rows.length,
      0,
    );
    const wrong = await stateHash("other");
    await insert(other, wrong);
    assert.equal(
      (await db.query("select * from public.social_verification_consume($1)", [
        wrong,
      ])).rows.length,
      0,
    );
    await db.exec(
      `insert into auth.sessions(id,user_id) values('00000000-0000-4000-8000-000000000004','${other}')`,
    );
    const next = await insert(other, await stateHash("ownership"));
    await db.query(
      `update public.social_verification_attempts set session_id='00000000-0000-4000-8000-000000000004' where id=$1`,
      [next],
    );
    await db.query("select * from public.social_verification_consume($1)", [
      await stateHash("ownership"),
    ]);
    await assert.rejects(
      db.query("select public.social_verification_finish($1,$2,$3)", [
        next,
        "42",
        "Stolen",
      ]),
      /unique/,
    );
    const replacementHash = await stateHash("replacement");
    const replacement = (await db.query(
      "select public.social_verification_start($1,$2,$3,$4) as id",
      [owner, session, "instagram", replacementHash],
    )).rows[0].id;
    await db.query("select * from public.social_verification_consume($1)", [
      replacementHash,
    ]);
    await db.query("select public.social_verification_disconnect($1,$2)", [
      owner,
      "instagram",
    ]);
    await assert.rejects(
      db.query("select public.social_verification_finish($1,$2,$3)", [
        replacement,
        "99",
        "Cancelled",
      ]),
      /invalid_attempt/,
    );
    const expiredSessionHash = await stateHash("expired-session");
    await insert(owner, expiredSessionHash);
    await db.query(
      "update auth.sessions set not_after=now()-interval '1 second' where id=$1",
      [session],
    );
    assert.equal(
      (await db.query("select * from public.social_verification_consume($1)", [
        expiredSessionHash,
      ])).rows.length,
      0,
    );
    await assert.rejects(
      db.query("select public.social_verification_start($1,$2,$3,$4)", [
        owner,
        session,
        "facebook",
        await stateHash("expired-start"),
      ]),
      /invalid_session/,
    );
    // A removed Auth session makes a previously issued state unusable.
    await db.query("delete from auth.sessions where id=$1", [session]);
    const revoked = await stateHash("revoked");
    await insert(owner, revoked);
    assert.equal(
      (await db.query("select * from public.social_verification_consume($1)", [
        revoked,
      ])).rows.length,
      0,
    );
    await db.exec("set role authenticated");
    await assert.rejects(
      db.query("select * from public.social_verification_proofs"),
      /permission denied/,
    );
    await assert.rejects(
      db.query("select * from public.social_verification_consume($1)", [hash]),
      /permission denied/,
    );
    await db.exec("reset role");
    await db.query("delete from auth.users where id=$1", [owner]);
    assert.equal(
      (await db.query("select * from public.social_verification_proofs")).rows
        .length,
      0,
    );
    await db.query(
      `insert into public.social_verification_proofs(owner_id,provider,subject,label) values($1,'facebook','84','Other')`,
      [other],
    );
    const removalHash = await stateHash("deletion");
    const remove = async () =>
      (await db.query(
        "select public.social_verification_provider_remove('instagram','84',true,$1) as id",
        [removalHash],
      )).rows[0].id;
    const receipt = await remove();
    assert.equal(await remove(), receipt);
    assert.equal(
      (await db.query("select * from public.social_verification_proofs")).rows
        .length,
      1,
      "other provider must survive",
    );
    await db.query(
      "select public.social_verification_provider_remove('facebook','84',false,$1)",
      [removalHash],
    );
    assert.equal(
      (await db.query("select * from public.social_verification_proofs")).rows
        .length,
      0,
    );
    // Both deauthorization and deletion replays preserve a newly connected proof.
    await db.query(
      "insert into public.social_verification_proofs(owner_id,provider,subject,label) values($1,'facebook','84','Reconnected')",
      [other],
    );
    await db.query(
      "select public.social_verification_provider_remove('facebook','84',false,$1)",
      [removalHash],
    );
    assert.equal(
      (await db.query(
        "select label from public.social_verification_proofs where provider='facebook'",
      )).rows[0].label,
      "Reconnected",
    );
    const deletionHash = await stateHash("fresh-deletion");
    const deletion = await db.query(
      "select public.social_verification_provider_remove('facebook','84',true,$1) as id",
      [deletionHash],
    );
    await db.query(
      "insert into public.social_verification_proofs(owner_id,provider,subject,label) values($1,'facebook','84','Again')",
      [other],
    );
    const replay = await db.query(
      "select public.social_verification_provider_remove('facebook','84',true,$1) as id",
      [deletionHash],
    );
    assert.equal(replay.rows[0].id, deletion.rows[0].id);
    assert.equal(
      (await db.query(
        "select label from public.social_verification_proofs where provider='facebook'",
      )).rows[0].label,
      "Again",
    );
    // A first proof still processing when Meta revokes must never materialize.
    const otherSession = "00000000-0000-4000-8000-000000000004";
    const oldHash = await stateHash("first-in-flight");
    const oldAttempt = (await db.query(
      "select public.social_verification_start($1,$2,$3,$4) as id",
      [other, otherSession, "instagram", oldHash],
    )).rows[0].id;
    await db.query("select * from public.social_verification_consume($1)", [
      oldHash,
    ]);
    await db.query(
      "select public.social_verification_provider_remove('instagram','12345',false,$1)",
      [await stateHash("in-flight-revoke")],
    );
    await assert.rejects(
      db.query("select public.social_verification_finish($1,$2,$3)", [
        oldAttempt,
        "12345",
        "Old",
      ]),
      /revoked_attempt/,
    );
    const newHash = await stateHash("after-revocation");
    const newAttempt = (await db.query(
      "select public.social_verification_start($1,$2,$3,$4) as id",
      [other, otherSession, "instagram", newHash],
    )).rows[0].id;
    await db.query("select * from public.social_verification_consume($1)", [
      newHash,
    ]);
    await db.query("select public.social_verification_finish($1,$2,$3)", [
      newAttempt,
      "12345",
      "Fresh",
    ]);
    assert.equal(
      (await db.query(
        "select label from public.social_verification_proofs where provider='instagram'",
      )).rows[0].label,
      "Fresh",
    );
  } finally {
    await db.close();
  }
});
test("Meta HMAC checks signature, app, timestamp and subject; endpoint binds provider", async () => {
  const sign = async (payload, secret = "private") => {
    const encoded = Buffer.from(JSON.stringify(payload)).toString("base64url");
    const key = await crypto.subtle.importKey(
      "raw",
      new TextEncoder().encode(secret),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign"],
    );
    return Buffer.from(
      await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(encoded)),
    ).toString("base64url") + "." + encoded;
  };
  const payload = {
    algorithm: "HMAC-SHA256",
    issued_at: Math.floor(Date.now() / 1000),
    user_id: "42",
    application_id: "123",
  };
  assert.equal(
    await verifyMetaRequest(await sign(payload), "private", "123"),
    "42",
  );
  for (
    const value of [
      await sign(payload, "wrong"),
      await sign({ ...payload, issued_at: 1 }),
      await sign({ ...payload, application_id: "999" }),
      await sign({ ...payload, user_id: "../42" }),
    ]
  ) await assert.rejects(verifyMetaRequest(value, "private", "123"));
  let removed;
  const handler = socialMetaHandler({
    env,
    providerRemove: async (...args) => {
      removed = args;
      return "receipt";
    },
  });
  const signed = await sign(payload), body = new FormData();
  body.set("signed_request", signed);
  assert.equal(
    (await handler(
      new Request(
        "https://example.supabase.co/functions/v1/social-verification-meta/facebook/delete",
        { method: "POST", body },
      ),
    )).status,
    200,
  );
  assert.equal(removed[0], "facebook");
  assert.equal(removed[1], "42");
  assert.equal(removed[2], true);
  assert.equal(removed[3].length, 64);
  const bad = new FormData();
  bad.set("signed_request", await sign(payload, "wrong"));
  assert.equal(
    (await handler(
      new Request(
        "https://example.supabase.co/functions/v1/social-verification-meta/facebook/delete",
        { method: "POST", body: bad },
      ),
    )).status,
    400,
  );
});
