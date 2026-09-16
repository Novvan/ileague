# contracts/domain

Core entity types: `League`, `Tournament`, `Venue`, `Team`, `Player`, `Match`.

Implements the draft/published data-model decision from `implementationPlan/02-contracts-domain-model.md` (E2-T1): a single `Match` type with a `status: 'draft' | 'published'` field and a nullable `published_at`, not separate types or a version-log shape. The resulting ADR lands in `docs/adr/` alongside this task.

Consumed by every other service — `services/supabase-infra` implements this as the actual Postgres schema, `services/scheduling-engine` produces/consumes these types, `services/back-office` and `services/player-app` both build on top of them (the latter via `contracts/fixtures/`'s TS↔Dart sync mechanism, E2-T5).
