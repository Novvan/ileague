# Epic 2 — Contracts & Domain Data Model

**Maps to:** `contracts/{domain,api,realtime,scheduling,fixtures}/`
**Depends on:** E1 (repo skeleton must exist).
**Blocks:** E3 (Supabase schema implements these types), E4 (engine consumes/produces these types), E5, E6 (both clients code against these contracts).

## Scope

The shared vocabulary every service imports and nobody reaches past. This epic makes the foundational judgment calls — get these wrong and every downstream epic inherits the mistake, so treat E2-T1 and E2-T5 with the weight their "large" size implies.

## Non-scope

No database (E3 turns these types into actual SQL/RLS). No algorithm implementation (E4 consumes these types, doesn't define them). No UI.

## Decision this epic implements

**Draft/published data model:** a single `matches` table with a `status` enum (`draft` | `published`) and a `published_at` timestamp — not separate `draft_matches`/`matches` tables, not an append-only `bracket_versions` table. Chosen for simplicity: Row Level Security (E3-T2) filters on one column directly instead of joining across tables or reconstructing state from a version log. Record this as an ADR in `docs/adr/` when E2-T1 lands.

## Tasks

### E2-T1 — Core domain entity types
Define `League`, `Tournament`, `Venue`, `Team`, `Player`, `Match` in `contracts/domain/`, implementing the draft/published decision above.
**Acceptance:**
- `Match` has an explicit, unambiguous `status: 'draft' | 'published'` field and a nullable `published_at`.
- `Tournament.format` is `'single_elim' | 'swiss'` (PRD Non-Goals explicitly excludes Double Elim/Round Robin at MVP — the type should not admit values the product doesn't support yet).
- `Tournament` carries the fields tier-limit enforcement needs to reference later (player count, venue count, admin-seat count) without E7 having to bolt them on afterward.
- `Venue` stores an IANA timezone identifier and operating hours in UTC (PRD §4, owns half of Technical Risk #4 alongside E3-T1 and E4-T3).
- The draft/published decision is written up as an ADR in `docs/adr/0001-match-status-model.md` with the rationale above.
- Round-trip and type-guard tests pass (a value serialized and deserialized through the type stays valid; invalid `status`/`format` values are rejected at the type level).
**Depends on:** E1. **Size: large** — foundational; the schema (E3-T1), the engine's output shape (E4), the draft-review UI (E5-T4), and the public-read contract (E2-T2) all inherit this decision. Treat as judgment-heavy: get a second opinion before locking it in if anything here feels uncertain.

### E2-T2 — API contract (Nitro route surface)
Typed request/response schemas for every Back Office and Player App endpoint: tournament/venue CRUD, bracket-generation trigger, draft edit, publish, and the public-read endpoints (bracket, results, news).
**Acceptance:**
- `contracts/api/` has one schema group per route family.
- Public-read endpoints are typed to *structurally* exclude draft-only fields — e.g. a `PublishedMatch` type that has no `status` field at all (it can only ever be published, by construction), rather than relying on a runtime check to hide draft data from the response shape.
- The historical-results endpoint's contract supports pagination (PRD: results "queryable indefinitely" — an unpaginated endpoint doesn't scale to that promise).
**Depends on:** E2-T1. **Size:** medium.

### E2-T3 — Realtime channel contract
Channel/topic naming convention, payload schema for match updates and news bulletins, and the documented poll-fallback endpoint contract that backs PRD Technical Risk #3's mitigation.
**Acceptance:**
- `contracts/realtime/` documents channel naming (per-tournament and per-league channels).
- Payload schema is versioned (so a future schema change doesn't break an old app build mid-rollout).
- The poll-fallback endpoint's response payload shape matches the Realtime payload closely enough that the Flutter client can share one mapping/deserialization layer for both (owned in full by E6-T5, this task just needs to make that possible).
**Depends on:** E2-T1, E2-T2. **Size:** medium.

### E2-T4 — Conflict/constraint types
The shared `ConflictReport` shape: player double-booking, venue-timeslot double-booking, and avoidable repeat pairing, each with a severity flag distinguishing "blocks publish" from "informational."
**Acceptance:** type lives in `contracts/scheduling/`; the blocking-vs-informational distinction is explicit in the type (not inferred by callers from conflict type); consumed identically by E4-T4 (the engine's detector) and E5-T4 (the draft-review UI's inline re-validation) — one type, two consumers, no drift.
**Depends on:** E2-T1. **Size:** medium.

### E2-T5 — TS↔Dart contract sync mechanism
Flutter (Dart) can't import TypeScript types directly — this task establishes how the domain/API/Realtime contracts above propagate to the Player App without silent drift between the two languages.
**Acceptance:**
- A documented, repeatable process (e.g., a JSON Schema or OpenAPI source-of-truth with codegen to Dart, or hand-maintained Dart models validated against shared golden fixtures — pick one, don't leave both options half-built).
- `contracts/fixtures/` holds golden JSON fixtures exercised by a contract-test suite that runs on *both* the Nitro/TS side and the Flutter/Dart side against the same fixtures.
- CI fails if the two sides disagree on how to interpret a fixture (this is what "sync" actually means here — not just "both exist," but "both parse the same bytes the same way").
**Depends on:** E2-T1, E2-T2, E2-T3. **Size: large** — cross-language contract sync is judgment-heavy and has long-term maintenance stakes; a sloppy choice here creates silent TS/Dart drift bugs for the life of the project.

## Verification

`contracts/` builds/typechecks standalone (no dependency on any `services/` code). The E2-T1 ADR exists and is referenced by name from `03-supabase-infra.md` and `04-scheduling-engine.md`. E2-T5's contract-test suite runs green in CI on an empty scaffold (i.e., it's wired up even before E3–E6 have real implementations to test against).
