// The database owns identity, rate limits and durable idempotency. A receipt
// means the request was stored, never that an email provider delivered it.
export const supportTopics = Object.freeze([
  'support_rules', 'contribute', 'guardian', 'adopt', 'verification',
  'publish_cases', 'funds_evidence', 'account', 'trust_safety',
]);
export class SupportRequestError extends Error {
  constructor(code, status = 400) { super(code); this.code = code; this.status = status; }
}
export function parseSupportRequest(input) {
  if (!input || typeof input !== 'object' || Array.isArray(input) ||
      Object.keys(input).some(key => !['request_id', 'topic', 'case_name', 'message'].includes(key))) {
    throw new SupportRequestError('invalid_request');
  }
  if (typeof input.request_id !== 'string' ||
      !/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(input.request_id) ||
      !supportTopics.includes(input.topic) || typeof input.message !== 'string' ||
      (input.case_name !== undefined && typeof input.case_name !== 'string')) {
    throw new SupportRequestError('invalid_request');
  }
  const message = input.message.trim(), caseName = (input.case_name ?? '').trim();
  if (!message || message.length > 4000 || caseName.length > 120 ||
      /[\u0000-\u0008\u000b\u000c\u000e-\u001f]/.test(message + caseName)) {
    throw new SupportRequestError('invalid_request');
  }
  return { request_id: input.request_id.toLowerCase(), topic: input.topic,
    case_name: caseName, message };
}
const headers = {
  'Content-Type': 'application/json', 'Cache-Control': 'no-store',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const json = (body, status) => new Response(JSON.stringify(body), {status, headers});
export function supportRequestHandler({ authorize, receive }) {
  return async request => {
    if (request.method === 'OPTIONS') return new Response(null, {status: 204, headers});
    if (request.method !== 'POST') return json({error: 'method_not_allowed'}, 405);
    try {
      // Authenticate before parsing: no anonymous persistence or provider calls.
      const actor = await authorize(request);
      if (!actor) throw new SupportRequestError('sign_in_required', 401);
      const text = await request.text();
      if (new TextEncoder().encode(text).length > 18000) throw new SupportRequestError('invalid_request', 413);
      let input;
      try { input = JSON.parse(text); } catch { throw new SupportRequestError('invalid_request'); }
      const payload = parseSupportRequest(input);
      const receipt = await receive(actor, payload);
      if (!receipt || receipt.request_id !== payload.request_id || receipt.status !== 'received') {
        throw new SupportRequestError('support_unavailable', 503);
      }
      return json({request_id: receipt.request_id, status: 'received'}, 200);
    } catch (error) {
      // Neither request content nor database/provider diagnostics leave this API.
      return json({error: error instanceof SupportRequestError ? error.code : 'support_unavailable'},
        error instanceof SupportRequestError ? error.status : 503);
    }
  };
}
