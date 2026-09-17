# Agent context — start here

This directory exists so that a fresh Claude Code (or any other agent) session starting work in one of ILEAGUE's *satellite* repos — the ones that don't exist yet, `ileague-back-office` and `ileague-player-app` — can get oriented without needing to open this hub repo (`ileague`) first.

**This hub repo (`ileague`, `git@github.com:Novvan/ileague.git`) is the source of truth.** Nothing in this directory overrides `ILEAGUE_PRD.md` or `implementationPlan/` at this repo's root — it's a condensed digest of them, written to be useful stand-alone. If something here and the PRD/plan disagree, the PRD/plan wins; treat that as a bug in this digest and fix it here.

## Files in this directory

- **`PROJECT_OVERVIEW.md`** — the product in ~1 page: problem, solution, personas, success metrics, pricing, tech stack. Digest of `ILEAGUE_PRD.md`.
- **`REPO_TOPOLOGY.md`** — which repo owns what, and the honest state of what's still unresolved about splitting a shared-contracts monorepo design across repo boundaries (read this before assuming anything about how the satellite repos talk to each other).
- **`DECISIONS.md`** — the standing architectural decisions that must not be re-litigated by a fresh agent working in a satellite repo. Supersedes the equivalent list in this hub repo's own root `CLAUDE.md` (kept in sync, but this is the canonical copy going forward since it's the one meant to travel).

## How to use this when a satellite repo is created

Each satellite repo (`ileague-back-office`, `ileague-player-app`) should get its own `CLAUDE.md` at its root. That file should:
1. Say plainly that it's one piece of the ILEAGUE product, and link to `github.com/Novvan/ileague` (this hub) for the full PRD and implementation plan.
2. Copy in (not just link to) `PROJECT_OVERVIEW.md` and `DECISIONS.md`'s content, or the parts relevant to that repo — a fresh agent shouldn't have to clone a second repo just to learn it can't re-litigate the draft/published data model.
3. Describe that repo's own real architecture once it exists (build/lint/test commands, actual file structure) — the thing this hub repo's own `CLAUDE.md` says it can't do yet, because there's no code here to describe.

## Status of this pivot

As of 2026-09-17, this is a documentation-only change. Neither `ileague-back-office` nor `ileague-player-app` exists yet. The 4 open PRs against this repo (`#1`-`#4`) scaffolded CI/tooling for a single-repo `services/*` layout that this split is replacing — they're being left open rather than merged, pending a redesign of `implementationPlan/`'s epic breakdown for the new topology (not done as part of this directory — see `REPO_TOPOLOGY.md`'s "What's not resolved yet" section for why that redesign isn't trivial).
