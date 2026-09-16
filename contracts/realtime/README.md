# contracts/realtime

Supabase Realtime channel naming convention and versioned payload schemas for match updates and news bulletins, plus the documented poll-fallback endpoint contract `services/player-app` falls back to when its Realtime subscription drops (PRD Technical Risk #3's mitigation, owned by `services/player-app`'s E6-T5).

The poll-fallback payload shape is kept close enough to the Realtime payload shape that the Flutter client shares one mapping layer for both. See `implementationPlan/02-contracts-domain-model.md`, E2-T3.
