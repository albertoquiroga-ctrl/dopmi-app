import { createVideoCleanupHandler } from '../_shared/video-cleanup.mjs';
import { videoRuntime } from '../_shared/video-runtime.ts';
Deno.serve(createVideoCleanupHandler({env: (name: string) => Deno.env.get(name), runtime: videoRuntime}));
