# contracts

Shared typed interfaces at the boundary between services, per the repo's services-first architecture rules. Services import from here — they never reach into another service's internals to infer a shape. See `implementationPlan/02-contracts-domain-model.md` for the full task breakdown (E2-T1 through E2-T5).

- **`domain/`** — core entity types: League, Tournament, Venue, Team, Player, Match (including the draft/published state model).
- **`api/`** — Nitro route request/response schemas, one group per route family.
- **`realtime/`** — Supabase Realtime channel naming + payload schemas, and the poll-fallback endpoint contract.
- **`scheduling/`** — the `ConflictReport` type and the `services/scheduling-engine` invocation contract (input: tournament config, output: draft `Match[]` + `ConflictReport`).
- **`fixtures/`** — golden JSON fixtures exercised by both the TypeScript (Nitro) side and the Dart (Flutter) side, so the two languages can't silently drift on what a shared type means.

A change under `contracts/` is the one case that legitimately crosses service boundaries — CI runs every consumer's contract-compliance tests when this directory changes (see `implementationPlan/01-repo-bootstrap.md`, E1-T2).
