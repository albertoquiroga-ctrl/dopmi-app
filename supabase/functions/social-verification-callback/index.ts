import { socialCallback } from "../_shared/social-verification.mjs";
import { socialRuntime } from "../_shared/social-verification-runtime.ts";
Deno.serve(socialCallback(socialRuntime()));
