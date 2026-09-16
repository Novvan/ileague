# Epic 1 — Repo & Tooling Bootstrap

**Maps to:** repo root glue only (`.github/`, `scripts/`, `docs/adr/`, per-service READMEs, root `CLAUDE.md`). No business logic.
**Depends on:** nothing — this is the first epic.
**Blocks:** every other epic (E2 through E7 all assume this skeleton exists).

## Scope

Stand up the services-first repo skeleton and the tooling that keeps it honest: CI that only runs what changed, a pre-commit gate, the health-check cron that prevents Supabase's free-tier project from auto-pausing (PRD Technical Risk #5), and a documented secrets convention. Nothing here touches product logic.

## Non-scope

No domain types (E2), no database (E3), no app code of any kind. If a task in this epic starts writing business logic, it's scope creep — stop and check which later epic it belongs to.

## Tasks

### E1-T1 — Services-first skeleton scaffold
Create `services/`, `contracts/{domain,api,realtime,scheduling,fixtures}/`, `docs/adr/`, `scripts/` at the repo root. Each `services/<name>/` directory (created empty here, populated by its owning epic) gets a `README.md` stating its scope and boundaries. Add a root `CLAUDE.md` (or extend if one exists by the time this runs) that records the services-first rules so a fresh Claude Code session in this repo doesn't need them re-explained.
**Acceptance:** repo root contains only glue files/directories — no `.ts`/`.dart`/`.sql` business-logic files at root. Each `services/<name>/` README states what it owns and explicitly what it does not (i.e., "does not talk to the database directly, only through `contracts/`" for `back-office`, etc.).
**Depends on:** —. **Size:** medium.

### E1-T2 — CI pipeline skeleton, path-filtered per service
GitHub Actions workflows that run a given service's own test suite only when files under its path changed (per CLAUDE.md: "a change in one service must not require running another service's full suite"), plus one additional workflow that runs when anything under `contracts/` changes, triggering every consumer's contract-compliance tests (since a contract change is the one case that legitimately crosses service boundaries).
**Acceptance:** a diff confined to `services/player-app/**` does not trigger `services/scheduling-engine/**`'s job and vice versa; a diff touching `contracts/**` triggers all consumers; CI is green on the empty-scaffold commit produced by E1-T1.
**Depends on:** E1-T1. **Size:** medium.

### E1-T3 — Pre-commit gate
Local lint/format/typecheck hook, scoped to only the staged files' owning service (mirrors E1-T2's CI filtering so local and CI never disagree about what "passing" means).
**Acceptance:** hook completes in under 5 seconds on a small diff; there's a documented emergency-bypass procedure (never a silent skip) consistent with CLAUDE.md's "never skip pre-commit hooks with `--no-verify` unless the user explicitly asks."
**Depends on:** E1-T1. **Size:** medium.

### E1-T4 — Health-check cron (owns PRD Technical Risk #5)
Scheduled GitHub Actions workflow, interval under 7 days (daily is fine), that hits a Nitro `/api/health` endpoint to keep the Supabase free-tier project from auto-pausing after 7 days of no API traffic.
**Acceptance:** workflow scaffolded now at a daily interval; fails loudly (a non-200 response fails the run, doesn't silently pass) if the endpoint is unreachable; the epic's README notes this workflow must stay active until Supabase is upgraded off the free tier (see `03-supabase-infra.md`, E3-T5). Full activation — pointing at the real deployed URL — depends functionally on `05-back-office.md`'s E5-T1 shipping the actual `/api/health` endpoint; scaffold the workflow now with a placeholder/localhost target and wire the real URL in as part of E5-T1's acceptance criteria.
**Depends on:** E1-T1 (functionally also E5-T1). **Size:** medium.

### E1-T5 — Env/secrets convention
`.env.example` per service directory, plus root documentation of how each secret reaches each environment: Vercel project env vars (Back Office), Supabase project keys (anon key, service role key — service role key never shipped to any client), AdMob app/unit IDs (Player App), Google Play Console service account credentials (CI/CD for Android distribution, E6-T8).
**Acceptance:** every `services/<name>/` directory has a complete `.env.example` with every variable it needs, none with real values; root docs trace each secret from where it's generated to where it's consumed.
**Depends on:** E1-T1. **Size:** medium.

## Verification

Run this epic's tasks in order (T1 first, everything else can follow in parallel once T1 lands since they don't touch each other's files). Done when: repo skeleton matches `00-INDEX.md`'s target layout, CI passes on an empty scaffold commit, pre-commit hook is installed and fast, the health-check cron workflow file exists (even if pointing at a placeholder until E5-T1), and `.env.example` files exist for every planned service.
