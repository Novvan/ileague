# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repo state

The services-first skeleton exists (`services/*/README.md`, `contracts/*/README.md`, `docs/adr/`, `scripts/`), but there is still no actual application code — no `package.json`, no build tooling, nothing to build/lint/test yet. Do not invent build/test commands; there are none. Each `services/<name>/README.md` states that service's scope and non-scope — read it before starting work in that directory. This notice should be removed once real app code and its build/test commands land.

`git config claude.mode` is set to `solo` in this repo (single-developer project) — branch locally, merge your own work, no worktree/PR ritual required, per the global CLAUDE.md's "Branching" section. Remote: `git@github.com:Novvan/ileague.git`.

## Source of truth

- **`ILEAGUE_PRD.md`** — the product spec. Problem statement, personas, success metrics, full acceptance criteria (with exact numeric thresholds — e.g. `<10s` for a 64-player/3-venue bracket, `<1.5s` TTI, `≤2` taps to next-match), tech stack decisions, pricing tiers, budget/infra posture, and technical risks. Read this before touching any product-behavior question.
- **`implementationPlan/`** — the dependency-ordered epic/task breakdown for building what the PRD describes. Start at `implementationPlan/00-INDEX.md`. Each task has an ID (`E<epic>-T<task>`, e.g. `E4-T3`) — use that ID as the git branch name when picking up work. `implementationPlan/RISK-MAP.md` cross-references the PRD's 6 technical risks to the exact tasks that own their mitigation.

## Intended architecture (not yet built)

Services-first, per the global CLAUDE.md's architecture rules — each service in its own directory, contracts at the boundary, independent test suites, no business logic at repo root:

```
services/
  supabase-infra/     # Postgres schema, RLS policies, Auth, seed data (Supabase, sa-east-1 region)
  scheduling-engine/  # deterministic bracket/pairing algorithm, Deno-compatible (runs as a Supabase Edge Function)
  back-office/        # Nuxt 3 app — organizer-facing web dashboard, Nitro server routes colocated
  player-app/         # Flutter app — read-only, login-free competitor client
contracts/
  domain/ api/ realtime/ scheduling/ fixtures/   # shared types both back-office and player-app code against
docs/adr/             # architecture decision records
```

Full task-level detail for each service lives in its corresponding `implementationPlan/0N-*.md` file — don't duplicate that detail here, read the file.

## Decisions already made (don't re-litigate these)

These resolve ambiguities the PRD itself left open. Full rationale is in `implementationPlan/00-INDEX.md`'s "Decisions made during planning" section and the epic file where each first applies.

1. **`matches` table uses a single `status` enum** (`draft`/`published`) + `published_at` timestamp — not separate tables, not a version log.
2. **Scheduling engine is its own service** (`services/scheduling-engine/`), not embedded in Back Office.
3. **Bracket generation runs as a Supabase Edge Function, not a Vercel function** — Vercel Hobby's 10s execution cap has zero margin against the PRD's own `<10s` benchmark; Supabase Edge Functions give 150s on the free tier. The engine package must be Deno-compatible.
4. **Organizer billing (Stripe or similar) is deferred past the testing phase.** Tier limits are defined and enforced now; payment collection is a named future task (`E7-T7`), not built in MVP.
5. **Free-tier historical results: archived after 90 days, never deleted.** Archived data is excluded from the public read API but the rows persist; upgrading a league's tier un-archives them.
