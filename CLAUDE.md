# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repo state

The services-first skeleton exists (`services/*/README.md`, `contracts/*/README.md`, `docs/adr/`, `scripts/`), but there is still no actual application code — no `package.json`, no build tooling, nothing to build/lint/test yet. Do not invent build/test commands; there are none. Each `services/<name>/README.md` states that service's scope and non-scope — read it before starting work in that directory. This notice should be removed once real app code and its build/test commands land.

`git config claude.mode` is set to `solo` in this repo (single-developer project, no worktree ritual needed) — **but PRs are used anyway, as an explicit exception to solo mode's default "no PR."** See "Workflow: stacked PRs" below. Remote: `git@github.com:Novvan/ileague.git`.

## Workflow: stacked PRs

Per Ian's instruction (2026-09-16): every task ships as its own branch and its own PR — no more direct-to-main commits, even in solo mode. When a task depends on another task that hasn't merged yet, its branch stacks on top of the dependency's branch instead of `main`, so the PR only shows the diff that task actually adds.

Tooling: plain `git` + `gh` CLI (both already available), no Graphite/git-town — chosen explicitly over Graphite to avoid a new external tool/account for now.

Convention:
1. **Branch naming:** the task ID from `implementationPlan/`, e.g. `e4-t3-constraint-solver`.
2. **Base branch:** `main` if nothing in the stack is still open; otherwise the branch of the still-open task this one depends on (per `implementationPlan/00-INDEX.md`'s dependency graph — check it before branching).
3. **Open the PR** with `gh pr create --base <parent-branch>` — never omit `--base` once stacking, since `gh` defaults to the repo's default branch and would silently produce a non-stacked PR with the wrong diff.
4. **Do not self-merge.** PRs are opened for Ian's review; merging is his call unless he says otherwise for a given PR.
5. **When a lower PR in the stack merges,** retarget each child PR's base to the new bottom of the stack (`gh pr edit <child> --base <new-base>`) and rebase the child branch onto it — done by hand, not automated, since there's no stacking tool doing this for us.

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
