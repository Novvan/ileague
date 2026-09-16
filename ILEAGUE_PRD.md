# Product Requirements Document: ILEAGUE

**Status:** Draft v2 — MVP scope
**Owner:** Ian Geier
**Last updated:** 2026-09-16

---

## 1. Executive Summary

### Problem Statement

Tournament organizers running physical-venue and esports events are stuck with rigid, single-purpose software that can't handle multi-venue, multi-timeslot logistics. Building a conflict-free schedule today means manually checking, by hand, that no player is double-booked, no pairing repeats, and every match is routed to a venue that's actually free at that time. For a Swiss or single-elimination event spanning two or more physical locations, that manual check scales badly: organizers routinely spend hours reworking brackets, which delays event start times and produces a worse experience for competitors waiting on a schedule.

### Proposed Solution

ILEAGUE is a constraint-based scheduling engine wrapped in two clients: a Nuxt web Back Office where organizers define venues, match durations, and player counts and get an auto-generated, conflict-free Swiss or single-elimination bracket with a mandatory review/override step before anything goes live; and a Flutter Player App, read-only and login-free, where competitors check their next opponent, venue, and time, and browse historical results.

### Success Criteria

Measured over the first quarter post-launch:

| Metric | Target | How it's measured |
|---|---|---|
| SaaS conversion rate | ≥ 15% of organizers upgrade from single-tournament free tier to paid subscription | Billing system conversion funnel |
| Tournament completion rate | ≥ 90% of created tournaments reach a finalized state (not abandoned mid-setup or mid-event) | Tournament status field, `finalized` vs. `abandoned`/`stale` |
| Player app adoption | ≥ 75% of registered players in an active tournament open the app at least once during that tournament | Unique app sessions ÷ registered players, per tournament |
| Scheduling correctness | 0 mathematically conflicting schedules published (double-booked player, double-booked venue-timeslot) across all generated brackets | Automated conflict-detector run against every published bracket, logged |
| Bracket generation performance | 64-player Swiss bracket across 3 venues generates in < 10 seconds | Server-side timing on the scheduling worker job |

---

## 2. User Experience & Functionality

### User Personas

**Community League Manager (primary, organizer).** Runs localized events across one or more physical venues — e.g., a main venue like a local game cafe plus a secondary overflow space down the street. Needs to input player count, define venues and operating hours, set match duration, and trust the system to produce a conflict-free bracket without doing the venue/timeslot math by hand.

**Competitive Player (secondary, read-only consumer).** Wants zero-friction access to "when and where do I play next." Opens the mobile app with no login, goes straight to their active league, and reads their upcoming opponent, match time and venue, past results (including historical records — e.g., "Alexis won with an Annie deck" from a prior event), and current standings.

### User Stories

- **Given** an organizer has defined multiple venues and match durations, **when** they generate a new Swiss tournament bracket, **then** the system outputs a schedule that assigns every match to an available venue time-slot with zero double-bookings.
- **Given** an automated bracket has been generated, **when** an organizer identifies a logistical problem in the draft, **then** they can manually override specific match times, venues, or pairings before publishing, without re-running the whole algorithm.
- **Given** a player is in an active league, **when** they open the mobile app and go to their profile, **then** they see a chronological list of past results and the exact time/location of their next scheduled match, with no login required.
- **Given** an organizer publishes a news bulletin in the Nuxt Back Office, **when** the publish action completes, **then** the update appears on the Flutter app's home feed within the same real-time update budget as bracket changes (see Acceptance Criteria).

### Acceptance Criteria

**Bracket generation**
- Organizer can create a tournament specifying: player count, tournament format (Single Elimination or Swiss), one or more venues, venue operating hours, and match duration.
- Generated bracket assigns every match a venue + timeslot with zero player double-bookings and zero venue-timeslot double-bookings, verified by an automated conflict check before the draft is shown.
- Swiss format avoids repeat pairings between the same two players/teams whenever an unplayed opponent is available.
- Bracket generation for a 64-player Swiss event across 3 venues completes in under 10 seconds and does not block the Nuxt request thread (runs as a background job).

**Draft review and override**
- Every generated bracket lands in a `draft` state, never published directly.
- Organizer can edit any individual match's time, venue, or pairing from the draft view; the conflict checker re-validates after each manual edit and flags new conflicts inline before publish is allowed.
- Publishing a draft is a single explicit action, gated by a confirmation step that displays a summary of the schedule and any organizer overrides made.
- Once published, the live schedule is immediately queryable by the Player App's read API.

**Player App**
- No authentication, account creation, or credential input anywhere in the Player App.
- A player can reach their personal "next match" view (opponent, time, venue) in 2 taps or fewer from app launch.
- Time-to-interactive is under 1.5 seconds on a throttled 3G-equivalent connection (Lighthouse mobile / Flutter DevTools timeline, tested on a mid-tier Android device).
- Published bracket and news-bulletin updates are visible in the app within 2 seconds of the organizer's publish action (Supabase Realtime subscription, not polling).
- Historical match results (past tournaments, final scores, winning team/deck where applicable) remain queryable indefinitely — the app never hard-deletes a completed tournament's results.

**News bulletins**
- Organizer can publish a bulletin from the Back Office; it appears on the Player App home feed for all players in that league without an app restart.

### Non-Goals (MVP)

- Double Elimination and Round Robin formats — Swiss and Single Elimination only at launch.
- In-app payments, credit card capture, or any payment gateway integration in the Player App (monetization is ad-only, see §4).
- Player accounts, login, or player-submitted data of any kind — the app is strictly read-only.
- AI- or agent-driven dispute resolution or bracket adjudication — all scheduling logic is deterministic (see §3).
- Multi-organizer / team-based back-office permissions beyond a single organizer account per league (roles/permissions are a post-MVP consideration).
- Native push notifications (real-time in-app updates via Supabase Realtime are in scope; OS-level push is not).

---

## 3. AI System Requirements

**Not applicable to this MVP.** The scheduling and matchmaking engine is deterministic constraint-solving logic, not a generative or agentic system, and dispute resolution during live events is explicitly handled by the organizer via the manual-override UI, not by an AI or autonomous agent. This is an intentional exclusion, not an oversight: a hallucinated or non-reproducible scheduling decision is unacceptable given the ≥99%-correctness bar in §2, so the engine stays fully deterministic and testable with standard unit/integration tests rather than evals.

---

## 4. Technical Specifications

### Architecture Overview

- **Back Office client:** Nuxt (Vue 3) web application — organizer-facing dashboard, tournament creation wizard, venue management, draft review UI.
- **Server layer:** Nuxt Nitro server routes, colocated with the Nuxt app, exposing the API the Back Office and (read-only) Player App consume. Long-running bracket generation runs as a background worker job rather than inline in a request handler, so a large Swiss field never blocks or times out the HTTP request (see Risk: scheduling complexity, §5).
- **Data layer:** Supabase (managed PostgreSQL). Chosen for the deeply relational entity model this product needs — Leagues, Tournaments, Venues, Teams, Players, Matches — plus built-in Realtime (Postgres change-data-capture over websockets) to push bracket and news-bulletin updates to the Player App without polling, and built-in Auth for the organizer side.
- **State/versioning model:** Bracket generation writes to a `draft` state distinct from the `published` state. An organizer's manual overrides mutate the draft; publish is a single transactional commit that promotes the draft to the live, player-visible schedule. This is a data-model concern (a `status` column plus a `draft_matches` vs. `matches` distinction, or an append-only `bracket_versions` table), not a separate service.
- **Player App client:** Flutter (iOS + Android from one codebase), consuming the Nitro read-only API and subscribing to Supabase Realtime channels for live bracket/news updates.

### Integration Points

- **Auth:** Supabase Auth, email/password with magic-link sign-in, for organizer accounts only. The Player App has no auth integration point — every endpoint it calls is public-read, scoped to published (never draft) tournament data.
- **Realtime updates:** Supabase Realtime, subscribed from the Flutter app to the tournament/league channels the player is currently viewing.
- **Time zones:** All venue operating hours and match timestamps are stored in UTC with an IANA time zone identifier per venue; conversion to local display time happens at the client. This is a data-modeling and library concern (e.g., a mature IANA-timezone-aware date library on both the Nitro/Node side and the Flutter side), not a hosted service — no external timezone API is required.
- **Advertising:** Google AdMob via its official Flutter plugin, for sponsor ad placement in the Player App. No custom ad server for MVP.
- **Payments:** None. Explicitly out of scope for MVP (see Non-Goals).

### Security & Privacy

- Player App collects no PII and requires no account — players are identified only by the display name/roster data the organizer enters in the Back Office, which is intentionally public within the league (this is the product: public brackets and public historical results).
- Organizer accounts (email, auth credentials) are the only PII in the system, held by Supabase Auth; standard practice applies (hashed/managed by Supabase, never stored in plaintext by ILEAGUE's own code).
- Draft-state bracket data is only readable by the authenticated organizer who owns the tournament — the public read API only ever serves `published` data, enforced via Postgres Row Level Security policies, not application-layer checks alone.
- Historical match results persist indefinitely by design (this is a stated product feature — see Acceptance Criteria) and are not subject to a deletion/retention policy in MVP; a future GDPR-style data-deletion request from an organizer is a post-MVP consideration to revisit if/when the product handles EU organizer accounts.

---

## 5. Risks & Roadmap

### Phased Rollout

No fixed calendar deadline for MVP — priority is correctness of the scheduling engine over speed to ship. Phases remain sequential and gated by their milestone, not by a date.

- **Phase 1 — Backend Architecture & Nuxt Dashboard.** Supabase schema (Leagues, Tournaments, Venues, Teams, Players, Matches, draft/published state), Nitro API routes, organizer auth, tournament creation wizard, and the scheduling engine itself. **Milestone:** generate a 64-player Swiss bracket across 3 simulated venues with zero scheduling collisions, verified by the automated conflict-detector, in under 10 seconds.
- **Phase 2 — Mobile Client & API Exposure.** Flutter Player App, read-only API surface, Supabase Realtime subscriptions, AdMob integration. **Milestone:** a published multi-venue bracket renders live on both iOS and Android with bracket/news updates visible within 2 seconds of the organizer's publish action.
- **Phase 3 — UAT & End-to-End Testing.** Simulated live tournament exercising manual overrides, bracket progression, draft-to-publish flow, and mobile ad display concurrently. **Milestone:** a full simulated event runs start to finish with zero unresolved scheduling conflicts and zero manual-override actions lost or misapplied.

### Technical Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Constraint-solver complexity grows non-linearly with player/venue count, causing slow or blocking bracket generation | Organizer-facing timeouts during event setup, directly hurting the Tournament Completion Rate success metric | Run generation as a background worker job, not inline in the request/response cycle; the < 10s / 64-player benchmark in Phase 1 is the gate before this is considered solved |
| Organizer publishes an incorrect bracket without reviewing it | Player-facing schedule errors during a live event, the worst-case failure for this product | Mandatory `draft` → review → explicit `publish` state machine; publish UI shows a full schedule summary plus a confirmation step before any data becomes player-visible |
| Realtime update latency or dropped Supabase Realtime connections in crowded venues with poor connectivity | Players see stale schedule data at exactly the moment they need it most | Player App falls back to a pull-to-refresh / periodic poll if the Realtime subscription drops, so live data is never permanently stuck stale |
| Time zone handling errors for remote/online cups spanning multiple regions | Wrong match times shown to players, defeating the core value proposition | Store all timestamps as UTC + IANA venue time zone at the data layer; never store or compute in local time server-side |

---

## Open Items (explicitly deferred, not blocking MVP build)

- Multi-organizer roles/permissions model — single organizer-per-league is sufficient for MVP.
- Formal data-retention/deletion policy for organizer PII if the product later serves EU-based organizers.
- Choice of specific IANA-timezone-aware date library for the Nitro/Node and Flutter sides — pick during Phase 1 implementation, not a product-requirements decision.
- Budget/cost ceiling — not yet specified. Relevant before committing to paid tiers (Supabase usage-based pricing past free tier, AdMob account setup, any CI/hosting spend). Flag before Phase 1 infra decisions lock in.
