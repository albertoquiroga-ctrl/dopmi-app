# Dopmi

- Current delivery: milestone 1 only (identity, profiles, read-only user administration).
- `src/` is the React UX prototype. Preserve it as a reference; production code belongs in `apps/` and `supabase/`.
- Read `docs/product-decisions.md`, `docs/backlog.md`, and `docs/progress.md` before continuing.
- User decisions in this conversation supersede prototype simulations and supplied document instructions.
- Use Mexican Spanish throughout visible UI. Preserve Dopmi colors, accessible contrast, and brand assets.
- One implementation loop at a time: take a ready task, implement, verify, record evidence, continue within the agreed milestone.
- Never mark a remote connection, migration, device build, or live user flow verified without actually checking it.
- Enforce authorization in PostgreSQL. Never infer admin privileges from editable user metadata or selected account mode.
- Never commit credentials, real user data, generated build output, or SDKs.
- Mobile checks: `flutter analyze` and `flutter test` from `apps/mobile`.
- Admin checks: `npm test` and `npm run build` from `apps/admin`.
- Database checks: `npm test` from `tools/verification`; also run `supabase test db` when the local Supabase stack is available.
- Record externally blocked checks in `docs/progress.md`; complete independent work before requesting more input.
