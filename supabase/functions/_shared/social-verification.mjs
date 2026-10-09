const providers = new Set(["facebook", "instagram"]);
export async function stateHash(value) {
  const bytes = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return [...new Uint8Array(bytes)].map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}
export function socialConfig(env, provider) {
  if (
    !providers.has(provider) || env("SOCIAL_VERIFICATION_ENABLED") !== "true"
  ) return null;
  const prefix = provider === "facebook"
    ? "SOCIAL_FACEBOOK"
    : "SOCIAL_INSTAGRAM";
  const client = env(`${prefix}_CLIENT_ID`),
    secret = env(`${prefix}_CLIENT_SECRET`);
  const redirect = env("SOCIAL_VERIFICATION_CALLBACK_URL");
  if (
    !client || !secret || !redirect ||
    !/^https:\/\/[a-z0-9-]+\.supabase\.co\/functions\/v1\/social-verification-callback$/
      .test(redirect)
  ) return null;
  return { client, secret, redirect, provider };
}
export function authorizationUrl(config, state) {
  const ig = config.provider === "instagram";
  const url = new URL(
    ig
      ? "https://www.instagram.com/oauth/authorize"
      : "https://www.facebook.com/v24.0/dialog/oauth",
  );
  for (
    const [key, value] of Object.entries({
      client_id: config.client,
      redirect_uri: config.redirect,
      state,
      response_type: "code",
      scope: ig ? "instagram_business_basic" : "public_profile",
    })
  ) url.searchParams.set(key, value);
  return url.href;
}
export async function providerIdentity(config, code, fetcher = fetch) {
  const ig = config.provider === "instagram";
  const tokenUrl = ig
    ? "https://api.instagram.com/oauth/access_token"
    : "https://graph.facebook.com/v24.0/oauth/access_token";
  const response = await fetcher(tokenUrl, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: config.client,
      client_secret: config.secret,
      redirect_uri: config.redirect,
      code,
      grant_type: "authorization_code",
    }),
    signal: AbortSignal.timeout(15000),
  });
  if (!response.ok) throw new Error("provider_rejected");
  const token = await response.json();
  if (typeof token.access_token !== "string" || !token.access_token) {
    throw new Error("invalid_provider_response");
  }
  // Fetch authoritative identity with this app-issued code; never trust browser IDs/labels.
  const url = new URL(
    ig
      ? "https://graph.instagram.com/v24.0/me"
      : "https://graph.facebook.com/v24.0/me",
  );
  url.searchParams.set(
    "fields",
    ig ? "user_id,username,account_type" : "id,name",
  );
  const identityResponse = await fetcher(url, {
    headers: { Authorization: `Bearer ${token.access_token}` },
    signal: AbortSignal.timeout(15000),
  });
  if (!identityResponse.ok) throw new Error("provider_rejected");
  const identity = await identityResponse.json();
  const subject = ig ? identity.user_id : identity.id,
    label = ig ? identity.username : identity.name;
  if (
    typeof subject !== "string" || !/^\d{1,255}$/.test(subject) ||
    typeof label !== "string" || !label.trim() || label.length > 200 ||
    /[\u0000-\u001f\u007f-\u009f\u202a-\u202e\u2066-\u2069]/u.test(label)
  ) throw new Error("invalid_provider_identity");
  if (ig && !["BUSINESS", "MEDIA_CREATOR"].includes(identity.account_type)) {
    throw new Error("professional_required");
  }
  return { subject, label: label.trim() };
}
export function socialHandler(runtime) {
  const json = (body, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: {
        "Content-Type": "application/json",
        "Cache-Control": "no-store",
      },
    });
  return async (request) => {
    if (request.method !== "POST") {
      return json({ error: "method_not_allowed" }, 405);
    }
    const token = request.headers.get("authorization")?.match(/^Bearer (.+)$/i)
      ?.[1];
    const actor = token ? await runtime.authenticate(token) : null;
    if (!actor?.id || !actor.session_id) {
      return json({ error: "unauthorized" }, 401);
    }
    let input;
    try {
      input = await request.json();
    } catch {
      return json({ error: "invalid_request" }, 400);
    }
    try {
      if (input.operation === "list") {
        return json({
          accounts: await runtime.list(actor.id),
          available_providers: [...providers].filter((p) =>
            socialConfig(runtime.env, p)
          ),
        });
      }
      if (input.operation === "status") {
        if (typeof input.attempt_id !== "string") {
          return json({ error: "invalid_request" }, 400);
        }
        const attempt = await runtime.status(
          actor.id,
          actor.session_id,
          input.attempt_id,
        );
        if (!attempt) return json({ error: "not_found" }, 404);
        return json({
          provider: attempt.provider,
          status: new Date(attempt.expires_at) <= new Date() &&
              attempt.status !== "verified"
            ? "expired"
            : attempt.status === "processing"
            ? "pending"
            : attempt.status,
          label: attempt.label ?? undefined,
        });
      }
      if (input.operation === "disconnect" && providers.has(input.provider)) {
        await runtime.disconnect(actor.id, input.provider);
        return json({ disconnected: true });
      }
      if (
        input.operation === "cancel" && typeof input.attempt_id === "string"
      ) {
        await runtime.cancel(actor.id, actor.session_id, input.attempt_id);
        return json({ cancelled: true });
      }
      if (input.operation !== "start" || !providers.has(input.provider)) {
        return json({ error: "invalid_request" }, 400);
      }
      const config = socialConfig(runtime.env, input.provider);
      if (!config) return json({ error: "provider_unavailable" }, 503);
      const state = crypto.randomUUID() + crypto.randomUUID();
      const attempt = await runtime.start(
        actor.id,
        actor.session_id,
        input.provider,
        await stateHash(state),
      );
      return json({
        attempt_id: attempt.id,
        authorization_url: authorizationUrl(config, state),
      });
    } catch {
      return json({ error: "social_verification_failed" }, 400);
    }
  };
}
export function socialCallback(runtime) {
  return async (request) => {
    const reply = () =>
      new Response("Vuelve a Dopmi y pulsa «Ya autoricé, comprobar».", {
        headers: {
          "Content-Type": "text/plain; charset=utf-8",
          "Cache-Control": "no-store",
          "Referrer-Policy": "no-referrer",
          "Content-Security-Policy":
            "default-src 'none'; frame-ancestors 'none'",
        },
      });
    if (request.method !== "GET") return new Response("", { status: 405 });
    const url = new URL(request.url), state = url.searchParams.get("state");
    if (!state || state.length > 200) {
      return new Response("Solicitud inválida.", { status: 400 });
    }
    let attempt;
    try {
      attempt = await runtime.consume(await stateHash(state));
      if (!attempt) {
        return new Response("Solicitud vencida o utilizada.", { status: 400 });
      }
      if (url.searchParams.has("error")) {
        await runtime.fail(attempt.id, "denied");
        return reply();
      }
      const config = socialConfig(runtime.env, attempt.provider),
        code = url.searchParams.get("code");
      if (!config || !code || code.length > 4096) {
        throw new Error("invalid_callback");
      }
      const identity = await providerIdentity(config, code, runtime.fetcher);
      await runtime.finish(attempt.id, identity.subject, identity.label);
    } catch {
      if (attempt) await runtime.fail(attempt.id, "failed").catch(() => {});
      return new Response(
        "No se pudo verificar. Vuelve a Dopmi e intenta de nuevo.",
        { status: 400, headers: { "Cache-Control": "no-store" } },
      );
    }
    return reply();
  };
}

function unbase64(value) {
  if (!/^[A-Za-z0-9_-]+$/.test(value)) {
    throw new Error("invalid_signed_request");
  }
  return Uint8Array.from(
    atob(
      value.replace(/-/g, "+").replace(/_/g, "/") +
        "=".repeat((4 - value.length % 4) % 4),
    ),
    (c) => c.charCodeAt(0),
  );
}
export async function verifyMetaRequest(
  signed,
  secret,
  client,
  now = Date.now(),
) {
  if (typeof signed !== "string" || signed.length > 8192) {
    throw new Error("invalid_signed_request");
  }
  const parts = signed.split(".");
  if (parts.length !== 2) throw new Error("invalid_signed_request");
  const signature = unbase64(parts[0]);
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["verify"],
  );
  if (
    !await crypto.subtle.verify(
      "HMAC",
      key,
      signature,
      new TextEncoder().encode(parts[1]),
    )
  ) throw new Error("invalid_signature");
  const payload = JSON.parse(new TextDecoder().decode(unbase64(parts[1])));
  if (
    payload.algorithm !== "HMAC-SHA256" ||
    typeof payload.user_id !== "string" ||
    !/^\d{1,255}$/.test(payload.user_id) ||
    !Number.isInteger(payload.issued_at) ||
    Math.abs(now / 1000 - payload.issued_at) > 300 ||
    payload.application_id !== undefined &&
      String(payload.application_id) !== client
  ) throw new Error("invalid_payload");
  return payload.user_id;
}
export function socialMetaHandler(runtime) {
  return async (request) => {
    const url = new URL(request.url),
      parts = url.pathname.split("/"),
      operation = parts.at(-1),
      provider = parts.at(-2);
    const headers = {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
      "Referrer-Policy": "no-referrer",
    };
    const response = (body, status = 200) =>
      new Response(JSON.stringify(body), { status, headers });
    if (operation === "status" && request.method === "GET") {
      const id = url.searchParams.get("code");
      if (!id || !/^[0-9a-f-]{36}$/i.test(id)) {
        return response({ error: "not_found" }, 404);
      }
      return await runtime.deletionStatus(id)
        ? response({
          status: "completed",
          description:
            "Se retiró la evidencia de verificación social de Dopmi.",
        })
        : response({ error: "not_found" }, 404);
    }
    if (
      request.method !== "POST" || !providers.has(provider) ||
      !["deauthorize", "delete"].includes(operation)
    ) return response({ error: "invalid_request" }, 400);
    const prefix = provider === "facebook"
      ? "SOCIAL_FACEBOOK"
      : "SOCIAL_INSTAGRAM";
    const secret = runtime.env(`${prefix}_CLIENT_SECRET`),
      client = runtime.env(`${prefix}_CLIENT_ID`);
    if (!secret || !client) {
      return response({ error: "provider_unavailable" }, 503);
    }
    try {
      const body = await request.formData(),
        signed = body.get("signed_request"),
        subject = await verifyMetaRequest(signed, secret, client);
      const receipt = await runtime.providerRemove(
        provider,
        subject,
        operation === "delete",
        await stateHash(provider + ":" + operation + ":" + signed),
      );
      if (operation === "deauthorize") return response({ removed: true });
      const status = new URL(
        url.origin + "/functions/v1/social-verification-meta/status",
      );
      status.searchParams.set("code", receipt);
      return response({ url: status.href, confirmation_code: receipt });
    } catch {
      return response({ error: "invalid_signed_request" }, 400);
    }
  };
}
