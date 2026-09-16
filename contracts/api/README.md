# contracts/api

Typed request/response schemas for every Nitro route family exposed by `services/back-office`: tournament/venue CRUD, bracket-generation trigger, draft edit, publish, and the public-read endpoints (bracket, results, news).

Public-read types (e.g. `PublishedMatch`) are structurally typed to exclude draft-only fields — the type itself makes it impossible to leak draft data, not just a runtime check. See `implementationPlan/02-contracts-domain-model.md`, E2-T2.
