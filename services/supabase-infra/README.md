# services/supabase-infra

## Scope

The data layer: Postgres schema migrations, Row Level Security policies, Supabase Auth setup (organizer accounts only), seed/fixture data for local dev, and the region/backup posture for the Supabase project (`sa-east-1`, free tier during the testing phase — see `implementationPlan/03-supabase-infra.md`).

Owns:
- Schema migrations for League, Tournament, Venue, Team, Player, Match.
- RLS policies enforcing draft-vs-published visibility (see `../../implementationPlan/03-supabase-infra.md`, E3-T2) — this is the product's actual security boundary, not a formality.
- Supabase Auth configuration.
- Seed scripts, including the 64-player/3-venue benchmark fixture `services/scheduling-engine` depends on.
- Documentation of the free-tier backup/PITR gap and the pre-flight checklist gating real organizer data.

## Non-scope

- No application/business logic — tournament-creation flow, draft-review UI, etc. live in `services/back-office`.
- No UI of any kind.
- Doesn't reach into any other service's code; other services talk to this one only through the Supabase client + the RLS policies defined here, never by assuming internal schema details not captured in `contracts/domain/`.

## Where to start

`implementationPlan/03-supabase-infra.md` for the full task breakdown (E3-T1 through E3-T5).
