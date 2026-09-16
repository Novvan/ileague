# Epic 4 — Scheduling Engine

**Maps to:** `services/scheduling-engine/`
**Depends on:** E2 (domain/conflict types), E3 (the E3-T4 benchmark fixture).
**Blocks:** E5 (Back Office triggers this engine's job and consumes its output).

## Scope

The product's core differentiator: deterministic constraint-solving that turns organizer inputs into a conflict-free bracket, verified against its own re-check pass, running fast enough and in the right execution environment to actually ship. Per PRD §3, this is explicitly **not** an AI/generative system — standard unit/integration/property-based tests are the whole verification story here, no evals.

## Non-scope

No UI (E5 owns the draft-review/override screens). No database writes (the engine is a pure function plus a thin job wrapper; E5's Nitro routes own persistence).

## Decisions this epic implements

1. **This is its own service**, not folded into Back Office. Reasoning: the correctness bar here is exceptional (PRD §1: "0 mathematically conflicting published schedules, ever," verified by a conflict-detector run against *every* published bracket, logged) — that demands slow, thorough property-based tests that shouldn't re-run on every unrelated Nuxt UI change, and CLAUDE.md's own tie-breaker is "lean toward more services with sharper boundaries" when in doubt.
2. **Bracket generation runs as a Supabase Edge Function, not a Vercel serverless function.** Vercel Hobby's function execution cap is 10 seconds — the exact same number as the PRD's own `<10s`/64-player benchmark, i.e. zero safety margin, and a near-certain intermittent failure mode under real load. Supabase Edge Functions give 150 seconds wall-clock on the free tier (verified), a 15x margin, with no new vendor since Supabase is already the data layer. **Real implication:** `services/scheduling-engine/` must be written to run in **Deno** (the Edge Functions runtime), not assumed to be Node-only — don't reach for a Node-only dependency without checking Deno compatibility first.

## Tasks

### E4-T1 — Single-Elimination bracket generator
Pure function producing rounds/matches/pairings for N players, handling both power-of-2 and non-power-of-2 counts (byes).
**Acceptance:** no duplicate matches; every player is scheduled until eliminated; unit tests cover 2, 3, 5, 32, and 64 players (the odd counts specifically exercise bye-handling correctness).
**Depends on:** E2-T1, E2-T4. **Size:** medium.

### E4-T2 — Swiss pairing algorithm
Round-by-round pairing that avoids repeat matchups.
**Acceptance (PRD verbatim):** "Swiss avoids repeat pairings between the same two players/teams whenever an unplayed opponent is available." Tests assert no repeat pairing ever occurs when at least one valid unplayed opponent exists for both players; odd-player-count bye handling is covered; a test explicitly covers the boundary case where a repeat pairing becomes *unavoidable* (every other opponent already played) and asserts the algorithm falls back to a repeat only then, not earlier.
**Depends on:** E2-T1, E2-T4. **Size: large** — genuinely judgment-heavy constraint algorithm and the product's core differentiator; give this the fan-out/variant-tournament/harsh-critic treatment CLAUDE.md calls for on judgment-heavy work, not a single pass.

### E4-T3 — Venue/timeslot constraint solver
Assigns every match a venue and timeslot given the organizer's venue operating hours and match duration.
**Acceptance (PRD verbatim):** given "player count, format, venue(s), venue operating hours, match duration," the output has "zero player double-bookings, zero venue-timeslot double-bookings." Because the PRD's own bar is "0, ever" (not "usually"), this task's tests must be **property-based** (randomized valid input generation asserting the zero-collision invariant holds on every run), not example-based tests alone — a handful of hand-picked examples passing tells you nothing about the input space you didn't think to write. All UTC/timezone arithmetic goes through **Luxon**; this task owns the server-side half of Technical Risk #4 (client-side half is E6-T7) — never compute or store in local time server-side.
**Depends on:** E4-T1, E4-T2. **Size: large** — the primary technical risk in the PRD's own risk table, and the central correctness commitment of the entire product.

### E4-T4 — Conflict detector
A standalone re-verification pass, independent of the generator's own internal logic, used both before a draft is first shown to the organizer and after every subsequent manual edit.
**Acceptance:** given any `Match[]` set, returns a `ConflictReport` (the E2-T4 contract) covering all three conflict types (player double-booking, venue-timeslot double-booking, avoidable repeat pairing). Has its own test suite built from hand-crafted malformed fixtures — it must not simply trust that the generator never produces bad output, since its entire purpose is to catch that case including after a human's manual edit introduces one. The exact same function is invoked identically by the generation pipeline (E4-T5) and by the Back Office's draft-edit re-validation (E5-T4) — one code path, two call sites, no drift.
**Depends on:** E4-T1, E4-T2, E4-T3, E2-T4. **Size:** medium.
**Owns PRD Technical Risk #2's verification-engine half** (the UI half is E5-T4).

### E4-T5 — Edge Function job wrapper + performance benchmark
Wraps the generator + solver + detector as a Supabase Edge Function (per Decision 2 above), invoked asynchronously so it never blocks a Nitro request handler.
**Acceptance (PRD verbatim):** "64-player Swiss bracket, 3 venues, generates in <10 seconds," measured against the E3-T4 fixture. An automated benchmark test **fails the CI build** if this threshold is exceeded — this is not a manual spot-check, it's a hard gate. Architecturally verified: the job never runs synchronously inside an HTTP request/response cycle anywhere in the codebase (a static check or code-review rule, not just a runtime assumption). This is PRD §6 Phase 1's literal milestone.
**Depends on:** E4-T1, E4-T2, E4-T3. **Size: large** — this is the literal Phase-1 milestone gate from the PRD's own roadmap; treat a benchmark regression here as a release blocker, not a follow-up ticket.
**Owns PRD Technical Risk #1's mitigation.**

### E4-T6 — `services/scheduling-engine/` package boundary + Back Office integration contract
Independent `package.json`/test runner for this service, **written Deno-compatible** per Decision 2 (audit every dependency for Deno support before adding it — don't assume Node compatibility implies Deno compatibility), plus the documented invocation contract that Back Office's job-trigger code consumes.
**Acceptance:** the service's test suite runs independently of `services/back-office/` (proving the service boundary is real, not just directory organization); the invocation contract (input: tournament config; output: draft `Match[]` + `ConflictReport`) is documented in `contracts/scheduling/`; an end-to-end smoke test invokes the deployed Edge Function against the E3-T4 fixture and asserts a valid response.
**Depends on:** E4-T1 through E4-T5, E1-T1. **Size:** medium.

## Verification

`services/scheduling-engine/` has its own CI job (path-filtered per E1-T2) that runs unit tests (T1, T2), property-based tests (T3), the malformed-fixture suite (T4), and the CI-enforced performance benchmark (T5) on every change — and nothing outside this directory triggers it. Done when: all three conflict types are provably impossible in the property-based test's search space (within its generation budget), the 64-player/3-venue benchmark passes reliably under 10s in CI (not just once locally), and the Edge Function is confirmed Deno-compatible end-to-end (not just "should work").
