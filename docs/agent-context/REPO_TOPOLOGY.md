# Repo topology

Decided 2026-09-17 (Ian): ILEAGUE splits across three repositories instead of the single-repo `services/*` layout `implementationPlan/00-INDEX.md` originally described. That plan document has not been rewritten for this split yet — this file is the interim source of truth for "what goes where" until it is.

## The three repos

### `ileague` (this repo) — documentation hub

No application code. Holds:
- `ILEAGUE_PRD.md` — the product spec.
- `implementationPlan/` — the epic/task breakdown (currently still describes the old single-repo layout — see "What's not resolved yet" below).
- `docs/agent-context/` (this directory) — the portable digest for agents working in the satellite repos.
- `docs/adr/` — architecture decision records.

Also, as of 2026-09-17, still physically contains a `services/*` README skeleton and four open, unmerged PRs (`#1`-`#4`) built for the old single-repo layout. These are intentionally left alone pending the `implementationPlan/` redesign — don't assume they represent current intent, and don't build on top of them as if the monorepo layout were still the plan.

### `ileague-back-office` (not yet created) — backend + organizer web app

Everything server-side and organizer-facing, bundled into one repo because it's all tightly coupled to the same Supabase project and deploys together:
- **Nuxt 3 Back Office** — organizer dashboard, tournament wizard, venue management, draft review/override, publish flow, news bulletins, tier-limit enforcement. Nitro server routes colocated (was `services/back-office/` — see `implementationPlan/05-back-office.md` for the full task-level detail, written for the old layout but the task *content* still applies, just re-homed).
- **Scheduling engine** — the deterministic bracket/pairing algorithm, Deno-compatible, deployed as a Supabase Edge Function (was `services/scheduling-engine/` — see `implementationPlan/04-scheduling-engine.md`). Bundled here rather than split out further because it's invoked directly by Back Office's job trigger and shares the same Supabase project; the original single-repo design's reasoning for giving it a *separate service directory* (independent test suite, parallel-session safety) still applies at the repo level here — it should live in its own subdirectory within this repo with its own test runner, not get smeared into the Nuxt app's code.
- **Supabase infra** — schema migrations, RLS policies, Auth config, seed data, region config (`sa-east-1`) (was `services/supabase-infra/` — see `implementationPlan/03-supabase-infra.md`). Bundled here because the migrations this repo's own backend code depends on need to move in lockstep with it.

Suggested repo name: `ileague-back-office` (not yet registered — confirm before creating).

### `ileague-player-app` (not yet created) — Flutter client

The read-only, login-free competitor app (was `services/player-app/` — see `implementationPlan/06-player-app.md`). Nothing else lives here; it's genuinely standalone once it has the API/Realtime contract it needs to code against (see below).

Suggested repo name: `ileague-player-app` (not yet registered — confirm before creating).

## What's not resolved yet

**How `contracts/` crosses the repo boundary.** The original single-repo design put `League`/`Tournament`/`Venue`/`Team`/`Player`/`Match` domain types, the API schema, the Realtime channel/payload schema, and the `ConflictReport` type in one shared `contracts/` directory that both the (TypeScript) backend and the (Dart) Player App imported directly, with a golden-fixture test suite (`implementationPlan/02-contracts-domain-model.md`, E2-T5) proving both languages agreed on what a fixture meant.

Splitting into two repos changes this in one genuinely good way and leaves one real problem open:

- **Good news:** the domain model, API schema, and `ConflictReport` type (`contracts/domain/`, `contracts/api/`, `contracts/scheduling/`) are now consumed *only* by TypeScript code (Back Office's Nitro routes and the bundled scheduling engine) — they can live entirely inside `ileague-back-office` as a normal internal package, no cross-repo/cross-language concern at all for those three.
- **Open problem:** the Player App still needs to agree with the backend on the **public API response shapes** and the **Realtime channel/payload schemas** (`contracts/api`'s public-read subset, and all of `contracts/realtime`) — and it's in a different repo, in a different language, with no shared filesystem. The original design's answer to "how do TS and Dart agree on a shared type" (golden JSON fixtures both sides test against, E2-T5) assumed both sides could read the same files from the same repo. That assumption is gone.

Real options for whoever picks this up (not decided — this needs its own design pass, likely as a redesigned E2, before `ileague-back-office`'s public API is built):
1. **Published contract package**: `ileague-back-office` publishes a versioned OpenAPI/JSON-Schema spec (as a GitHub Release artifact or an npm package) that `ileague-player-app`'s CI pulls down and either codegens Dart models from or validates fixtures against.
2. **Git submodule / subtree**: `ileague-player-app` pulls a `contracts/` subset from `ileague-back-office` (or from this hub repo, if the public-facing contracts move here instead) as a submodule, checked out at a pinned commit, bumped deliberately.
3. **Shared third repo just for the public contract**: overkill for two consumers, probably not worth it, but not ruled out.

Whoever redesigns the E2 epic should pick one of these (or something better) and write it up as an ADR before `ileague-player-app`'s networking layer is built against an assumption that later turns out wrong.
