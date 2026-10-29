import { cors, failure, json, paymentActor, runtime } from '../_shared/runtime.ts';
import { paymentRequestHandler } from '../_shared/payment-handler.mjs';

Deno.serve(paymentRequestHandler({
  authenticate: paymentActor,
  createRuntime: runtime,
  json,
  failure,
  cors,
}));
