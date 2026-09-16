# Epic 5 — Back Office Web App

**Maps to:** `services/back-office/` (Nuxt 3 app, Nitro server routes colocated)
**Depends on:** E2 (contracts), E3 (schema/auth), E4 (scheduling engine to call).
**Blocks:** E6 (Player App consumes what Back Office publishes), E7 (tier enforcement plugs into this app's UI and API routes).

## Scope

The organizer-facing product: tournament creation, venue management, the mandatory draft-review/override workflow, publish, news bulletins, and tier-limit visibility. Hosted on Vercel Hobby (free) during the testing phase — see the hosting caveat in `07-billing-tier-enforcement.md`, since Hobby's non-commercial ToS is a real constraint to revisit at the first paid conversion or live ad revenue.

## Non-scope

No scheduling algorithm (E4 owns that; this epic only triggers and consumes it). No payment collection (E7-T7, explicitly deferred).

## Tasks

### E5-T1 — App scaffold, organizer auth, health endpoint
**Acceptance:** organizer can sign up/log in via both email/password and magic-link (E3-T3); unauthenticated access to any organizer route redirects to login; `/api/health` returns 200 unauthenticated and is the real URL `01-repo-bootstrap.md`'s E1-T4 cron points at once this ships.
**Depends on:** E3-T3, E1-T1. **Size:** medium.

### E5-T2 — Tournament creation wizard
**Acceptance (PRD verbatim inputs):** organizer specifies "player count, tournament format (Single Elimination or Swiss), one or more venues, venue operating hours, and match duration." Submission enqueues E4's Edge Function job asynchronously — the request handler returns immediately, never blocks waiting for bracket generation. Wizard enforces tier limits at input time (venue count, player count, concurrent-tournament cap) by reading `07-billing-tier-enforcement.md`'s E7-T1 tier config — client-side enforcement here is a UX nicety, the real gate is server-side (E7-T2/T3).
**Depends on:** E4-T6, E5-T1, E7-T1. **Size:** medium.

### E5-T3 — Venue management UI
**Acceptance:** CRUD for venues (name, location, IANA timezone identifier, operating hours); timezone input validated via Luxon (rejects invalid IANA identifiers at input time, not just at generation time); the per-tournament venue cap (2/5/unlimited by tier) is *enforced* server-side by E7-T3 — this task's job is to reflect that limit in the UI, not to be the enforcement point itself.
**Depends on:** E3-T1, E5-T1. **Size:** medium.

### E5-T4 — Draft review & override UI
**Acceptance (PRD verbatim):** "Every generated bracket lands in a `draft` state, never published directly." Organizer can edit any individual match's time, venue, or pairing from the draft view. "The conflict checker re-validates after each manual edit and flags new conflicts inline before publish is allowed" — this task calls E4-T4's conflict detector, the same function the generation pipeline uses, after every single edit, not just on some edits or on a manual "re-check" button press. Publish is blocked while any blocking-severity conflict (per E2-T4's severity flag) remains unresolved.
**Depends on:** E4-T4, E5-T2. **Size: large** — this is the PRD's own risk table calling out exactly this UI as the mitigation for "organizer publishes an incorrect bracket without reviewing it" (Technical Risk #2); judgment-heavy UX that deserves a critic pass focused specifically on "can I find a path to publish without the conflict checker catching a real conflict."
**Owns PRD Technical Risk #2's UI half** (the detection-engine half is E4-T4).

### E5-T5 — Publish flow with confirmation
**Acceptance (PRD verbatim):** "Publishing a draft is a single explicit action, gated by a confirmation step that displays a summary of the schedule and any organizer overrides made." The publish action is a single transactional commit — there is no intermediate state where the API could return a half-published bracket. "Once published, the live schedule is immediately queryable by the Player App's read API" — verified by an integration test that publishes, then immediately hits the public read endpoint (E2-T2/E3-T2) and asserts the data is there, not eventually-consistent-with-a-delay.
**Depends on:** E5-T4, E3-T2. **Size:** medium.

### E5-T6 — News bulletins (organizer create/publish)
**Acceptance:** organizer authors and publishes a bulletin scoped to a league; publish propagates via E2-T3's Realtime channel; "appears on the Player App's home feed for all players in that league without an app restart" (verified end-to-end once E6-T4 exists). **Scope is intentionally minimal** per the PRD's own language — create and publish only, no edit/unpublish/scheduling. If a richer bulletin CMS turns out to be needed, that's a scope change to raise explicitly, not something to silently build here.
**Depends on:** E5-T1, E2-T3. **Size:** medium.

### E5-T7 — Dashboard with tier-limit visibility
**Acceptance:** dashboard surfaces current tier and live usage against its limits (e.g. "1/1 concurrent tournaments used" on Free); attempting to create a tournament beyond the concurrent-active cap (E7-T2's definition: `draft` or `published`-not-`finalized` counts, `finalized` frees the slot) is blocked with an upgrade prompt rather than a bare error.
**Depends on:** E5-T1, E7-T2. **Size:** medium.

*Note: no task in this epic owns PRD Technical Risk #3 (Realtime latency/drops). That mitigation is entirely a Player App concern at MVP, since multi-admin concurrent editing — the scenario where Back Office-side realtime resilience would matter — is explicitly a v1.1 feature (`08-post-mvp-backlog.md`), not in MVP scope.*

## Verification

`services/back-office/` has its own CI job (path-filtered per E1-T2) covering unit tests for each route/component plus the E5-T5 integration test proving publish→public-read-visible with no delay. Done when: the full organizer flow (create → generate → review/override → publish → bulletin) works end-to-end against a real Supabase instance (not mocked), and E5-T4's conflict-checker-blocks-publish behavior is verified by a test that deliberately introduces a conflict via manual override and asserts publish is refused until it's resolved.
