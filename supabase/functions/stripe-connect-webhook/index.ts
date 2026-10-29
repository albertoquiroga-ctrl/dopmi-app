import { connectWebhookRequestHandler } from '../_shared/connect-webhook-handler.mjs';
import { paymentEnvironment } from '../_shared/payment-environment.ts';
import { failure, json, runtime } from '../_shared/runtime.ts';

Deno.serve(connectWebhookRequestHandler({
  loadEnvironment: paymentEnvironment,
  createRuntime: runtime,
  json,
  failure,
}));
