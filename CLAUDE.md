# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repo state

**This repo is now a documentation hub, not a monorepo.** As of 2026-09-17, ILEAGUE splits across three repositories — see `docs/agent-context/REPO_TOPOLOGY.md` for the full picture and `docs/agent-context/DECISIONS.md` #6. This repo holds product/planning documentation only; application code lives in `ileague-back-office` and `ileague-player-app` (not created yet).

This repo still physically contains a `services/*/README.md` skeleton and 4 open, unmerged PRs (`#1`-`#4`) built for the earlier single-repo layout. They're intentionally left alone pending a redesign of `implementationPlan/`'s epic breakdown for the new topology — don't build on top of them, don't treat them as current intent, and don't invent build/test commands here regardless (there's no application code in this repo, by design, going forward).

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
- **`docs/agent-context/`** — a portable digest of the above, written for an agent working in `ileague-back-office` or `ileague-player-app` who doesn't want to clone this whole repo just to get oriented. Start at `docs/agent-context/README.md`.

## Architecture

Three repos, not one — see `docs/agent-context/REPO_TOPOLOGY.md` for the full breakdown (what goes where, suggested repo names, and the explicitly-still-open question of how the API/Realtime contract crosses into `ileague-player-app`). Summary:

- **`ileague`** (this repo) — docs only: `ILEAGUE_PRD.md`, `implementationPlan/`, `docs/agent-context/`, `docs/adr/`.
- **`ileague-back-office`** (not created yet) — Nuxt 3 + Nitro organizer app, the scheduling engine (own subdirectory, own test runner, Deno-compatible, deploys as a Supabase Edge Function), and Supabase infra (migrations/RLS/Auth/seed data).
- **`ileague-player-app`** (not created yet) — Flutter, standalone.

The `implementationPlan/0N-*.md` files still describe task-level detail written for the old single-repo `services/*` layout — the task *content* mostly still applies, just re-homed per the topology above; the epic breakdown itself hasn't been rewritten for the split yet.

## Decisions already made (don't re-litigate these)

`docs/agent-context/DECISIONS.md` is now the canonical list (it's the one meant to travel into the satellite repos once they exist) — read it there. Full rationale for the product/technical decisions is in `implementationPlan/00-INDEX.md`'s "Decisions made during planning" section and the epic file where each first applies.
