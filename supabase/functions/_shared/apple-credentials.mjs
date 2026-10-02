// Credentials stay inside the server. Neither provider responses nor tokens are logged.
export class AppleCredentialError extends Error {
  constructor(code, status = 503) { super(code); this.code = code; this.status = status; }
}
const encode = bytes => btoa(String.fromCharCode(...bytes));
const decode = text => Uint8Array.from(atob(text), c => c.charCodeAt(0));
export function appleIdentityVerifier({ jwtVerify, keys, audience }) {
  return async (token, expected) => {
    const { payload } = await jwtVerify(token, keys, {
      issuer: 'https://appleid.apple.com', audience, algorithms: ['RS256'],
      requiredClaims: ['sub', 'exp', 'iat', 'nonce'],
    });
    if (payload.sub !== expected.subject || payload.nonce !== expected.nonce) {
      throw new AppleCredentialError('apple_identity_required', 403);
    }
  };
}
export async function credentialCipher(base64Key, keyId, cryptoApi = crypto) {
  let raw;
  try { raw = decode(base64Key); } catch { throw new AppleCredentialError('identity_not_configured'); }
  if (raw.length !== 32 || !/^[a-zA-Z0-9_-]{1,40}$/.test(keyId ?? '')) throw new AppleCredentialError('identity_not_configured');
  const key = await cryptoApi.subtle.importKey('raw', raw, 'AES-GCM', false, ['encrypt', 'decrypt']);
  const context = owner => new TextEncoder().encode(`dopmi:apple:${owner}:${keyId}`);
  return {
    async seal(owner, value) {
      const iv = cryptoApi.getRandomValues(new Uint8Array(12));
      const encrypted = await cryptoApi.subtle.encrypt({ name: 'AES-GCM', iv, additionalData: context(owner) }, key, new TextEncoder().encode(value));
      return { key_id: keyId, iv: encode(iv), ciphertext: encode(new Uint8Array(encrypted)) };
    },
    async open(owner, envelope) {
      if (envelope?.key_id !== keyId) throw new AppleCredentialError('credential_key_unavailable');
      try {
        return new TextDecoder().decode(await cryptoApi.subtle.decrypt({ name: 'AES-GCM', iv: decode(envelope.iv), additionalData: context(owner) }, key, decode(envelope.ciphertext)));
      } catch { throw new AppleCredentialError('credential_unavailable'); }
    },
  };
}

export function appleTokenApi({ clientId, clientSecret, fetcher = fetch }) {
  if (!clientId || !clientSecret) throw new AppleCredentialError('identity_not_configured');
  async function post(path, parameters) {
    let response;
    try {
      response = await fetcher(`https://appleid.apple.com/auth/${path}`, {
        method: 'POST', redirect: 'error', signal: AbortSignal.timeout(15000),
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ client_id: clientId, client_secret: await clientSecret(), ...parameters }),
      });
    } catch { throw new AppleCredentialError('apple_unavailable'); }
    if (!response.ok) throw new AppleCredentialError('apple_unavailable');
    return response;
  }
  return {
    async exchange(code) {
      const response = await post('token', { grant_type: 'authorization_code', code });
      let value; try { value = await response.json(); } catch { throw new AppleCredentialError('apple_unavailable'); }
      if (typeof value.refresh_token !== 'string' || !value.refresh_token || typeof value.id_token !== 'string') throw new AppleCredentialError('apple_unavailable');
      return { refreshToken: value.refresh_token, idToken: value.id_token };
    },
    async revoke(token) { await post('revoke', { token, token_type_hint: 'refresh_token' }); },
  };
}

// store is service-role-only; verifyToken must verify signature, issuer, audience,
// expiry, subject and nonce before returning. actor comes from Supabase getUser.
export function appleCredentialService({ store, api, cipher, verifyToken, hash }) {
  return {
    async register(actor, { code, nonce }) {
      if (!actor?.id || !actor.appleSubject) throw new AppleCredentialError('apple_identity_required', 403);
      if (typeof code !== 'string' || !code || code.length > 4096 || typeof nonce !== 'string' || nonce.length < 32 || nonce.length > 256) throw new AppleCredentialError('invalid_request', 400);
      const requestHash = await hash(code);
      await store.requireActive(actor.id, actor.appleSubject);
      const previous = await store.get(actor.id);
      if (previous?.request_hash === requestHash && previous.subject === actor.appleSubject) return { registered: true };
      // Never overwrite a credential needed for deletion after account suspension.
      const tokens = await api.exchange(code);
      let envelope;
      try {
        await verifyToken(tokens.idToken, { subject: actor.appleSubject, nonce: await hash(nonce) });
        envelope = await cipher.seal(actor.id, tokens.refreshToken);
      } catch {
        // A consumed code cannot be exchanged again. Revoke the unpersisted grant;
        // tell the client to authenticate again instead of reporting false success.
        try { await api.revoke(tokens.refreshToken); } catch { /* No secret logging. */ }
        throw new AppleCredentialError('apple_registration_incomplete');
      }
      try {
        await store.save(actor.id, { subject: actor.appleSubject, request_hash: requestHash, envelope });
      } catch {
        // A lost database response does not mean the write failed.
        let persisted;
        try { persisted = await store.get(actor.id); }
        catch { throw new AppleCredentialError('apple_registration_incomplete'); }
        if (persisted?.request_hash !== requestHash) {
          try { await api.revoke(tokens.refreshToken); } catch { /* No secret logging. */ }
          throw new AppleCredentialError('apple_registration_incomplete');
        }
      }
      return { registered: true };
    },
    async revoke(owner) {
      const current = await store.get(owner);
      if (!current) return { revoked: true };
      const token = await cipher.open(owner, current.envelope);
      await api.revoke(token);
      // Compare-and-delete avoids removing a credential registered concurrently.
      await store.remove(owner, current.request_hash);
      return { revoked: true };
    },
  };
}
