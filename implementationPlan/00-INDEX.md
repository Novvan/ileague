# ILEAGUE Implementation Plan — Index

Source of truth for scope: `ILEAGUE_PRD.md` (repo root, Draft v4). This directory turns that PRD into a dependency-ordered, task-level build plan. Read the PRD first if you haven't — this index assumes it.

## How to use this plan

- Each epic file (`0N-*.md`) is self-contained: scope, non-scope, cross-epic dependencies, and a task table.
- Task IDs are `E<epic>-T<task>` (e.g. `E4-T3`). Use the task ID as the git branch/worktree name when picking up work (e.g. branch `e4-t3-swiss-pairing`), per the repo's CLAUDE.md branching rules.
- Every task lists a size (`medium` or `large`) per the CLAUDE.md triage system. `large` tasks are flagged with a one-line reason and should get the fan-out/critic-loop treatment that size calls for; `medium` tasks are solo work with one cold critic pass on bug fixes.
- `RISK-MAP.md` cross-references the PRD's 6 Technical Risks to the exact task(s) that own their mitigation — check it before marking a risk "handled."
- Decisions made during planning (things the PRD left open) are recorded inline in the epic file where they matter, not centralized — each epic is meant to be readable on its own by a fresh Claude Code session with no other context loaded.

## Epic order and dependency graph

```
E1 Repo & Tooling Bootstrap
  └─> E2 Contracts & Domain Data Model
        ├─> E3 Supabase Infra
        │     └─> E7 Billing / Tier Enforcement ──┐
        ├─> E4 Scheduling Engine (also needs E3's fixtures)
        │     └─> E5 Back Office Web App ──────────┤
        │           └─> E6 Player App               │
        └───────────────────────────────────────────┘
E8 Post-MVP Backlog (v1.1, v2.0) — depends on all of the above, scoped only, not task-broken-down
```

| # | Epic | File | Maps to | Depends on |
|---|------|------|---------|------------|
| E1 | Repo & Tooling Bootstrap | `01-repo-bootstrap.md` | repo root glue | — |
| E2 | Contracts & Domain Data Model | `02-contracts-domain-model.md` | `contracts/` | E1 |
| E3 | Supabase Infra | `03-supabase-infra.md` | `services/supabase-infra/` | E2 |
| E4 | Scheduling Engine | `04-scheduling-engine.md` | `services/scheduling-engine/` | E2, E3 (fixtures) |
| E5 | Back Office Web App | `05-back-office.md` | `services/back-office/` | E2, E3, E4 |
| E6 | Player App | `06-player-app.md` | `services/player-app/` | E2, E5 |
| E7 | Billing / Tier Enforcement | `07-billing-tier-enforcement.md` | `services/supabase-infra/` + `services/back-office/` | E3, E5 |
| E8 | Post-MVP Backlog | `08-post-mvp-backlog.md` | scoped only | all MVP epics |

## Target repo skeleton

This plan is designed to produce, epic by epic:

```
services/
  supabase-infra/     # migrations, RLS policies, seed scripts, own README
  scheduling-engine/  # pure TS algorithm (Deno-compatible) + Edge Function wrapper, own tests
  back-office/         # Nuxt 3 app (Nitro server routes colocated)
  player-app/          # Flutter app
contracts/
  domain/     # League, Tournament, Venue, Team, Player, Match, draft/published state
  api/        # Nitro route request/response schemas
  realtime/   # Supabase Realtime channel + payload schemas, poll-fallback contract
  scheduling/ # ConflictReport type, engine invocation contract
  fixtures/   # golden JSON fixtures shared by TS + Dart contract tests
docs/adr/     # architecture decision records
.github/workflows/  # CI (path-filtered per service) + health-check cron
scripts/      # glue only — orchestration, never business logic
```

Per the repo's CLAUDE.md architecture rules: one concern per `services/<name>/` directory, contracts live at the boundary and are imported (never reached-into), each service has its own test suite, and the repo root holds nothing but glue.

## Decisions made during planning (resolving PRD ambiguities)

These were open questions the PRD itself left unresolved; each is now decided so no task below has to re-litigate it. Full reasoning lives in the epic file where the decision first applies — this is the index.

1. **Draft/published data model** (`02-contracts-domain-model.md`, E2-T1): single `matches` table, `status` enum (`draft`/`published`), `published_at` timestamp. Not separate tables.
2. **Scheduling engine is its own service** (`services/scheduling-engine/`), not folded into Back Office — see `04-scheduling-engine.md`.
3. **Bracket generation runs as a Supabase Edge Function**, not a Vercel serverless function — Vercel Hobby's 10s execution cap has zero margin against the PRD's own <10s benchmark; Supabase Edge Functions give 150s on the free tier. See `04-scheduling-engine.md`, E4-T5/E4-T6. Real implication: the engine package must be Deno-compatible, not Node-only.
4. **Organizer SaaS billing (Stripe or similar) is deferred past the testing phase.** Tier definition/enforcement ships now; payment collection is a named future epic (E7-T7), not built in MVP. See `07-billing-tier-enforcement.md`.
5. **"Concurrent active tournaments" = `draft` or `published`-but-not-`finalized`.** Reaching `finalized` frees the tier slot. See `07-billing-tier-enforcement.md`, E7-T2.
6. **Free-tier 90-day retention: archive, don't delete.** At day 90 post-completion, a Free-tier tournament's results are hidden from the public read API but rows are never deleted. Resolves a real contradiction between the pricing table's "90 days" and the PRD's "queryable indefinitely, never hard-deleted" promise. See `07-billing-tier-enforcement.md`, E7-T4, and `06-player-app.md`, E6-T3. **`ILEAGUE_PRD.md` §2 has been amended with the tier caveat** to keep the PRD and this plan in sync.
7. **News bulletins, tier limits, and admin seats are scoped exactly as the PRD states** — minimal create+publish only, per-tournament-only caps, single-seat access until v1.1. Not gaps, just documented MVP scope.

## Verification

A task in this plan is "done" per the repo's own Completion Status Protocol (CLAUDE.md) — DONE only when tests/evals are in the diff, acceptance criteria are met with evidence, and the self-rating loop (for medium/large tasks) came back proud. This index itself is verified by: every task ID referenced in `RISK-MAP.md` resolving to a real task in its epic file, and every task's stated dependency resolving to a real epic/task ID — no dangling references.
