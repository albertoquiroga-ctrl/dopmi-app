# Campaign placement attribution and pilot implementation plan

> **For agentic workers:** Use subagent-driven-development for the independent server, client and landing scopes; root owns integration, the single Flutter queue, releases and the Facebook pilot.

**Goal:** Carry an automatic placement token from a rescuer comment through Play installation to the eligible account's submitted pets, then start the60-person MTY pilot only after the new public client is available.

**Architecture:** A private registry maps opaque tokens to experiment/arm/legacy variant. The Android acquisition row remains the sole first-source authority and gains an optional registry reference. Existing lifecycle/message observers and legacy links remain compatible. Landing carries a registered token in a new four-UTM campaign; no social identity enters the app/server registry.

**Tech Stack:** Flutter/Dart, existing Play Install Referrer bridge, PostgreSQL/Supabase, Vercel Node download handler and existing Codemagic/Play signing.

**Spec:** ../specs/2026-11-21-rescuer-acquisition-experiment-design.md

## Authorization and frozen base

User21nov explicitly authorizes implementing the labels on the latest version, verification and then starting the60-rescuer pilot. This supersedes the documentation-only state of the spec, not the privacy/financial gates. Latest audited product af0e2274 and metadata fda91c1f (425/426) merged with our campaign docs at f0e6521a. Product diff against fda is zero. Preserve favorites, photos/carousel, HTTPS shares, Amazon and explicit Analytics choice. iPad426 explicitOFF is not a QA authorization.

## Frozen interfaces

- Registry manifest: tools/campaigns/rescuer-pilot-60-v1.json; schemaVersion1; experimentId resc_mty_20261121_p60_v1; utmCampaign dopmi_rescatistas_mty_p60_v1.60 non-QA placements,15 per arm, plus one distinct QA placement. Seed21112026 produces balanced blocks of4; tokens are128-bit random lowercase32hex, public context rather than credentials.
- Arm mapping R1/personal-a, R2/personal-b, R3/pagina-a, R4/pagina-b. Message×identity; CTA/link transport constant. A token identifies a planned comment/placement; private ledger adds the actual social post/comment, never a claimed identity join to the converter.
- New HTTPS route /descargar/piloto/{token}, finite manifest allowlist. Unknown tokens404. Legacy routes unchanged. Same Android gesture/intent/fallback behavior and security headers.
- Android referrer exactly four keys: utm_source=facebook, utm_medium=organic_comment, utm_campaign=dopmi_rescatistas_mty_p60_v1, utm_content={token}. New client distinguishes this grammar from legacy4variants; unknown/malformed/duplicated keys rejected without leaking token/raw inputs in diagnostics.
- Registry private.dopmi_campaign_placements: token PK, experiment_id, arm_id, variant, is_qa and enabled; immutable token/assignment by operator convention. No client/service-role CRUD. RLS enabled. Seed non-QA disabled until public release and pilot activation; QA enabled for verification. No social PII.
- Existing private.dopmi_android_rescuer_acquisition gains nullable placement_token FK. Do not create another per-actor acquisition authority or enrich a legacy source after the fact.
- New authenticated RPC public.dopmi_record_android_experiment_acquisition(p_placement_token text,p_clicked_at timestamptz,p_expected_consent_revision bigint) returns status recorded/already_recorded/ineligible/consent_changed/invalid_placement. Derive variant/experiment/arm from enabled registry; expected revision is SERVER revision under the existing lock order. Existing source wins unchanged. Unknown tokens never fall back to an arbitrary legacy claim.
- Keep336h from valid Play click, first-source/owner and processed flags, profile/account eligibility, CAS and opt-out/deletion. Explicit OFF never resets toON or becomes eligible just to run a test. Preserve existing iOS personal-a contract without generalizing it to per-comment installs.
- Report exact first_adoption_id and registry labels. Since adoption.submitted_at is mutable during corrections, add private.dopmi_campaign_adoption_submissions with post_id PK/FKadoptions, actor_id FKsource and placement_token FKregistry, first_submitted_at serverclock. One additional private trigger captures the first original submission for each post inside336h; INSERTONCONFLICT preserves the immutable receipt through redraft/corrections. Consent→source lock order; no history backfill. Post deletion, source opt-out and account deletion cascade receipts. Later pets inherit the acquisition source, not a new last-click claim; primary acquisition still counts the account once. No attribution for drafts or later out-of-window submissions. No public exposure of post/user IDs.
- iOS new routes keep direct App Store download with separate aggregate ct for this pilot/arm; do not silently reuse historicalct or claim per-comment post-install attribution. iOS labels remain unknown at individual level until a compatible transport is verified. Report coverage, not zero conversions.

## Tasks and ownership

- [x] Server owner: CLI-generated additive migration, registry/nullableFK/newRPC, registry seed, operator aggregate and exact-publication reports, focused static and actual-PostgreSQL regressions. RED before implementation. Preserve old functions/triggers unless proof requires a change. Root alone applies hosted migration after history preflight/review.
- [x] Client owner: new referrer grammar and claim result/retry integration using the actual server consent revision, backward compatibility and privacy tests. Root alone runs Flutter queue; agent may edit tests but must not start a Flutter process. No app UX changes except truthful existing privacy copy if necessary.
- [x] Landing owner: copy exact safe manifest, route/generator and HTTP tests proving registered placement survives native/fallback Play URL, no legacy regression and unknownclosed. No deployment before integration/review; root owns publication coordination.
- [x] Root: reconcile impact and independent security/code review, focused tests then full repository gates/CI, history72 baseline and latest schema before a single hosted apply. CI44966371479 has fourSUCCESS; migration PROD20261122004520 and31postflight checks passed, preserving339old functions and old source/event hashes. Exact artifact runtime remains in the release task below. Do not replay analytics or iOS migrations.
- [ ] Root: build signed PROD candidate from integrated newest source, verify clean install through QA placement→first private submission and exact registry/source/post join with consent personally accepted. Use a fresh QA account, never reset old fixtures. Confirm Play publication separately and promote verified client publicly before any pilot comment uses the new grammar. Retain recentApple features; no CPP activation is implied by this Android extension.
- [ ] Root/operator: inventory eligible newMTY posts and page permissions,60unique authors/one relevant comment each,15per arm subject to both identities allowed; record failures/visibility/time and actual comment link privately. Freeze copy and blocks. Activate non-QA registry only after public client confirmation. Start pilot and report actual counts, never fabricated60 or significance.

## Verification gates and stopping conditions

Meaningful regressions: legacy+new sources contend on same actor; consent revision race/OFF; token spoof/disabled/mismatch; first source cannot be reattributed; no client reads of registry/analytics; reinstall/account switching do not reset processed/owner; source→first pet exact; additional pets only within window; opt-out removes joined reporting; fallback carries same token; crawlers do not count as clicks/conversions.

Required checks: Flutter analyze/test (one queue), admin npm test/build, tools/verification npm test and actual PostgreSQL where available, scripts/test_mobile_config.py; existing fullCI when platform tools unavailable. Record exactSHA/runs. Production public availability and clean device path are distinct from compilation/internal upload. If Play blocks download or review is pending, finish independent code/deployment/preparation and hold actual pilot comments; do not burn60 placements on clients that reject the payload.

Rollback: stop new placements/disable their registry rows while preserving old acquisition rows and legacy downloads. No data deletion/backfill, signature changes, opt-in reset, financial activation or provider-ad edits.

Scoped update21nov: after the initial freeze, b08f040f0e685f1097e64f867269590355cc1b5b was separately inventoried and incorporated (three files: app.dart, publication_screens.dart and six regression tests). It fixes acknowledgement navigation to the review list, without lifecycle/consent/SQL changes. Six targeted tests passed; the final integrated CI must include this delta. No further remote scope is silently absorbed.
