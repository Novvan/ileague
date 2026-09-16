# contracts/scheduling

The `ConflictReport` type (player double-booking, venue-timeslot double-booking, avoidable repeat pairing — each with a blocking-vs-informational severity flag) and the `services/scheduling-engine` invocation contract: input is tournament config, output is draft `Match[]` + a `ConflictReport`.

Consumed identically by `services/scheduling-engine` (the detector that produces it) and `services/back-office` (the draft-review UI's inline re-validation) — one type, two consumers, no drift. See `implementationPlan/02-contracts-domain-model.md`, E2-T4, and `implementationPlan/04-scheduling-engine.md`, E4-T6.
