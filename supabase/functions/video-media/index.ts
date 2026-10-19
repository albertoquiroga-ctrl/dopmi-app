import { createVideoHandler } from '../_shared/video-media.mjs';
import { videoRuntime } from '../_shared/video-runtime.ts';
Deno.serve(createVideoHandler(videoRuntime()));
