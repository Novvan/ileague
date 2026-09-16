# Epic 3 — Supabase Infra

**Maps to:** `services/supabase-infra/`
**Depends on:** E2 (domain types drive the schema).
**Blocks:** E4 (needs the E3-T4 benchmark fixture), E5 (Back Office reads/writes this schema), E7 (tier enforcement needs the schema to exist).

## Scope

The actual database: schema, security policies, auth, seed data, and an honest accounting of what the free tier does and doesn't protect against. Region is fixed: **São Paulo (`sa-east-1`)**, per PRD §4.

## Non-scope

No application logic (that's E5's Nitro routes and E4's engine calling into this schema). No UI.

## Tasks

### E3-T1 — Initial schema migration
SQL migrations for all six entities (League, Tournament, Venue, Team, Player, Match) matching `02-contracts-domain-model.md`'s E2-T1 types, in a Supabase project pinned to `sa-east-1`.
**Acceptance:**
- Migrations create Leagues/Tournaments/Venues/Teams/Players/Matches with correct foreign keys.
- `Tournament.format` is a Postgres enum (`single_elim`, `swiss`) matching E2-T1 exactly.
- `Match` implements the E2-T1 draft/published decision: `status` enum column + nullable `published_at`, single table.
- `Venue` stores an IANA timezone identifier column and UTC operating-hours columns (owns half of Technical Risk #4 alongside E2-T1/E4-T3).
- Project region is confirmed `sa-east-1` in the Supabase dashboard/config, and this is documented in `services/supabase-infra/README.md`.
**Depends on:** E2-T1. **Size:** medium.

### E3-T2 — Row Level Security policies
Enforces PRD §4's security requirement verbatim: draft-state data is readable only by the owning organizer; the public read API only ever serves `published` data; enforced via **Postgres RLS**, not application-layer checks alone.
**Acceptance:**
- A pgTAP (or equivalent) test suite proves: the anonymous role can `SELECT` only `published`-status rows, full stop.
- An organizer role can read/write only draft+published rows belonging to leagues they own — tested against a second organizer's data to prove no cross-tenant leakage.
- A test proves that a direct SQL query attempting to read draft data as the anonymous role returns zero rows, even completely bypassing any Nitro API layer (this is the actual point of RLS — it has to hold at the database level, not just "the API happens not to expose it").
- Tests run in CI against an ephemeral Postgres/Supabase branch, not manually.
**Depends on:** E3-T1. **Size: large** — this is the product's actual security boundary; a mistake here is a data breach, not a bug. Warrants full scrutiny (harsh-critic pass as an attacker trying to read draft data) despite being scoped to one service.

### E3-T3 — Supabase Auth setup
Email/password + magic-link sign-in, organizer accounts only.
**Acceptance:** both auth methods work end-to-end for organizer signup/login; a check proves zero auth-scoped endpoints or Realtime channels are exposed to the anonymous/public role (the Player App has no auth surface to attack, per PRD Non-Goals — verify this as a negative, not just skip building it).
**Depends on:** E3-T1. **Size:** medium.

### E3-T4 — Seed/fixture data + local dev workflow
Idempotent seed script for local/dev use, including a fixture matching the exact 64-player/3-venue Swiss benchmark scenario from PRD §1/§6, for reuse by E4-T5's performance gate.
**Acceptance:** seed script populates a dev/local instance reproducibly (re-running it doesn't duplicate or corrupt data); the 64-player/3-venue fixture exists and is the literal fixture `04-scheduling-engine.md`'s E4-T5 benchmark test consumes (not a re-derived copy — one fixture, one source of truth).
**Depends on:** E3-T1. **Size:** medium.

### E3-T5 — Backup/PITR posture + upgrade-trigger checklist (owns PRD Technical Risk #6)
Formal documentation of the free-tier no-backup gap, wired into a pre-flight checklist that gates real organizer onboarding.
**Acceptance:**
- `services/supabase-infra/README.md` (or a dedicated runbook) states plainly: free-tier Supabase has no automatic backups and no point-in-time recovery; a deletion or bad migration during this phase is unrecoverable.
- A checklist item — "Supabase upgraded to Pro (adds 7-day daily backups + up to 14 days PITR)" — is documented as a hard prerequisite before any real, paying organizer's data goes live, not just a nice-to-have.
- Cross-referenced from `07-billing-tier-enforcement.md` (the upgrade-off-free-tier decision lives there too).
**Depends on:** E3-T1. **Size:** medium.

## Verification

`services/supabase-infra/` has its own migration-apply + RLS-test + seed CI job (per E1-T2's path-filtering), independent of the Nuxt or Flutter services. Done when: schema matches E2-T1 exactly, RLS tests pass including the negative "can an anonymous query see draft data" case, auth works for both methods, the 64-player/3-venue fixture is seedable on demand, and the backup-gap documentation exists and is linked from E7.
