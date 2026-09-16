# Epic 8 — Post-MVP Backlog (v1.1, v2.0)

**Status:** scoped at a high level only — deliberately **not** broken down into tasks yet. Do not start work here until the corresponding MVP epics (E1–E7) are done and the PRD's own Phase 1/2/3 milestones are met; the PRD itself says these are "gated by milestone, not calendar date."

## v1.1 — Multi-admin leagues

Multiple "league admin" seats per league, with realtime concurrent editing of tournament/venue data. This is the feature that upgrades a paying organizer (Organizer tier: up to 3 seats; League/Pro: unlimited) beyond the MVP's single-owner-seat limitation — see `07-billing-tier-enforcement.md`'s E7-T1, which already records the target seat counts per tier but does not enforce or enable multi-seat access in MVP.

Builds on:
- **E3 (Supabase Infra):** admin-seat/role tables and the RLS policy extensions needed to let more than one authenticated user read/write a given league's draft data.
- **E5 (Back Office):** the concurrency-safety UX — each write carries an optimistic-concurrency version check (extends the existing NFR that concurrent bracket updates process in under 2 seconds to prevent data collision), and the UI surfaces a live presence indicator (who else is viewing/editing this tournament right now) so two admins don't blind-overwrite each other's changes.
- **E7-T1:** seat counts are already defined in the tier table; this epic is what actually enforces and enables them.

## v2.0 — Scale and format expansion

Double Elimination and Round Robin tournament formats, extending `04-scheduling-engine.md`'s E4-T3 solver and E4-T4 conflict detector to handle the new bracket shapes (the underlying venue/timeslot constraint-solving and conflict-detection logic generalizes; the pairing/bracket-structure logic does not, and needs its own algorithm work analogous to E4-T1/E4-T2).

Also in scope for v2.0:
- **Role-based admin permissions** (full admin vs. scorekeeper-only), extending E3's RLS policies, E5's UI, and E7-T1's seat/role model beyond v1.1's flat multi-seat access.
- **Evaluate a Player-App-side payment gateway** for in-app tournament entry-fee collection, if real organizer demand emerges. This is explicitly distinct from `07-billing-tier-enforcement.md`'s E7-T7 (which is about *ILEAGUE's own* SaaS subscription revenue) — this would be entry fees organizers collect from *their* players, a different payment flow with different stakes (PRD Non-Goals explicitly excludes this from MVP for the Player App).

## Why this isn't task-broken-down yet

Breaking v1.1/v2.0 into `E<n>-T<n>` tasks now, before any MVP epic has shipped real code, would mean designing against assumptions (E2's contracts, E3's schema shape, E4's algorithm internals) that MVP implementation will very likely revise. Task-break this epic once E1–E7 are actually built and their real shapes are known, not from the PRD's description of what they'll eventually look like.
