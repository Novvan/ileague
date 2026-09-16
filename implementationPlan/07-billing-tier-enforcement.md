# Epic 7 — Billing / Tier Enforcement

**Maps to:** `services/supabase-infra/` (schema) + `services/back-office/` (enforcement logic + UI)
**Depends on:** E3 (schema to attach tier data to), E5 (Back Office surfaces limits to organizers).
**Blocks:** nothing else in MVP — E8's v1.1 multi-admin work builds on this epic's tier/seat data model.

## Scope

Make the PRD §5 pricing table real: tier definitions, per-tier limits actually enforced (not just displayed), the Free-tier retention archival job, and the two tier-gated perks (export, branding). Payment collection itself is explicitly out of scope this phase — see Decision below.

## Non-scope

No Stripe/payment-provider integration (E7-T7, deferred). No multi-seat access control (that's v1.1, `08-post-mvp-backlog.md` — Free tier's single-seat limit just... is the limit, for every tier, until v1.1 ships).

## Decisions this epic implements

1. **Organizer SaaS billing (e.g. Stripe) is deferred past the testing phase.** Consistent with the project's own stated approach — free tier everywhere until there are real testers, revisit cost/billing decisions after. During testing, an organizer's tier is assigned manually (an admin/support action), not purchased. Tier *definition and limit enforcement* still ship now, because Free-tier limits (1 concurrent tournament, 2 venues, 32 players) need enforcing regardless of whether anyone's paying — a free tier with no enforced ceiling isn't actually a tier. Real payment collection is tracked as **E7-T7**, a named future epic, not silently built or silently skipped.
2. **"Concurrent active tournaments" = any tournament in `draft` or `published`-but-not-`finalized` state.** Reaching `finalized` (the same status PRD §1's completion-rate metric uses) frees the tier slot.
3. **Free-tier 90-day retention: archive, don't delete.** At day 90 post-completion (`finalized` + 90 days), a Free-tier tournament's results are hidden from the public read API, but the underlying rows are never deleted. This resolves a real contradiction between the pricing table's "90 days" line and the PRD's separate promise that historical results are "queryable indefinitely, never hard-deleted" — nothing is deleted (that promise holds literally), but Free-tier results specifically stop being *queryable* past 90 days, which is a real, user-visible limitation the Player App UI (E6-T3) should state honestly. `ILEAGUE_PRD.md` §2 has been amended with this tier caveat so the PRD stays accurate.

## Tasks

### E7-T1 — Tier definition data model
**Acceptance:** encodes PRD §5's table exactly:

| | Free | Organizer ($20/mo) | League/Pro ($50/mo) |
|---|---|---|---|
| Concurrent active tournaments | 1 | 3 | Unlimited |
| Venues per tournament | 2 | 5 | Unlimited |
| Players per tournament | Up to 32 | Up to 128 | Unlimited |
| Admin seats | 1 (owner only) | Up to 3 (v1.1) | Unlimited (v2.0) |
| Historical retention | 90 days (archive, per Decision 3) | Indefinite | Indefinite + export |
| Branding | ILEAGUE shown | ILEAGUE shown | Custom logo |

Every `League` references a tier. A `payment_status` field defaults to `manually_assigned` during the testing phase (Decision 1) — this field exists specifically so E7-T7, whenever it's built, has a clean place to record "actually paid via Stripe" without a schema migration fight later.
**Depends on:** E3-T1. **Size:** medium.

### E7-T2 — Concurrent-active-tournament cap enforcement
**Acceptance:** enforced server-side (in the Nitro API layer, not client-UI-only — consistent with the project's "not application-layer checks alone" security philosophy already applied to RLS in E3-T2, applied here at the API boundary instead since this is a business-logic limit, not a data-access boundary). Uses Decision 2's definition of "active." A test creates tournaments up to the cap, asserts the next creation attempt is rejected with a clear tier-limit error (not a generic 500), and asserts finalizing a tournament frees the slot for a new one.
**Depends on:** E7-T1, E3-T1. **Size:** medium.

### E7-T3 — Venues-per-tournament / players-per-tournament caps
**Acceptance:** enforced server-side at the venue-add and player-registration points respectively (per-tournament only, per PRD §5's own column headers — no aggregate per-organizer/per-league cap, since the PRD doesn't specify one and inventing one would be scope creep). Wizard/venue-management UI (E5-T2, E5-T3) mirror these limits for UX, but this task's server-side check is the actual enforcement point.
**Depends on:** E7-T1. **Size:** medium.

### E7-T4 — Free-tier 90-day archival job
**Acceptance:** implements Decision 3. A scheduled job identifies Free-tier tournaments where `finalized_at` is more than 90 days in the past and flags them archived; the public-read API layer (working with E3-T2's RLS) excludes archived-and-Free-tier results from responses; **rows are never deleted** — the job only ever flips a visibility flag, there is no delete statement anywhere in this task's implementation. A test proves: a Free-tier tournament at day 91 is excluded from public read but still present in the database; the same tournament on Organizer/League tier at day 91 is still fully queryable; upgrading a league's tier un-archives its previously-archived results (since the limitation is tier-attached, not permanent).
**Depends on:** E7-T1, E3-T1, E3-T2. **Size:** medium.

### E7-T5 — CSV/data export (League/Pro only)
**Acceptance:** a League/Pro-tier organizer can export their tournament/league history as CSV; the export endpoint is tier-gated (returns a clear upgrade-prompt error on Free/Organizer tiers, not a silent empty file).
**Depends on:** E7-T1. **Size:** medium.

### E7-T6 — Custom branding (League/Pro only)
**Acceptance:** League/Pro organizer can configure a custom league logo/branding shown in the Player App in place of default ILEAGUE branding; Free/Organizer tiers show ILEAGUE branding per §5, with no UI path to disable it on those tiers.
**Depends on:** E7-T1, E5-T1. **Size:** medium.

### E7-T7 — Organizer SaaS payment collection *(not built in MVP)*
Tracked here deliberately so it isn't forgotten, not scoped as an MVP task. Build once organizer conversion is actually being tested post-launch (real testers exist, tier upgrades are being requested), per Decision 1. Likely shape when it's picked up: a payment-provider integration (e.g. Stripe Billing) with webhook-driven `payment_status` updates into E7-T1's schema, replacing the `manually_assigned` default with real subscription state. **Size when built: large** (new external integration + webhook handling + subscription-state sync — not a small addition).
**Depends on:** a product decision to start charging, not a technical dependency.

## Verification

`services/supabase-infra/` and `services/back-office/` both get tier-enforcement test coverage in their respective CI jobs. Done when: every limit in the PRD §5 table has a corresponding enforced check with a passing test proving both "at the limit, allowed" and "over the limit, rejected"; the archival job's "archived but never deleted" invariant is proven, not assumed; and E7-T5/T6's tier-gating is proven negative-tested (Free/Organizer tier genuinely cannot access League/Pro-only features, not just "the button is hidden").
