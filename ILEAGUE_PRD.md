# Product Requirements Document: ILEAGUE

**Status:** Draft v4 — MVP scope, infra/budget finalized for testing phase
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
- Multi-organizer / multi-admin back-office access — MVP ships with a single organizer account per league. Multiple "league admin" seats with realtime concurrent editing are planned for v1.1, not MVP (see Post-MVP Roadmap, §6).
- Native push notifications (real-time in-app updates via Supabase Realtime are in scope; OS-level push is not).

---

## 3. AI System Requirements

**Not applicable to this MVP.** The scheduling and matchmaking engine is deterministic constraint-solving logic, not a generative or agentic system, and dispute resolution during live events is explicitly handled by the organizer via the manual-override UI, not by an AI or autonomous agent. This is an intentional exclusion, not an oversight: a hallucinated or non-reproducible scheduling decision is unacceptable given the ≥99%-correctness bar in §2, so the engine stays fully deterministic and testable with standard unit/integration tests rather than evals.

---

## 4. Technical Specifications

### Architecture Overview

- **Back Office client:** Nuxt (Vue 3) web application — organizer-facing dashboard, tournament creation wizard, venue management, draft review UI.
- **Server layer:** Nuxt Nitro server routes, colocated with the Nuxt app, exposing the API the Back Office and (read-only) Player App consume. Long-running bracket generation runs as a background worker job rather than inline in a request handler, so a large Swiss field never blocks or times out the HTTP request (see Risk: scheduling complexity, §6).
- **Data layer:** Supabase (managed PostgreSQL), project hosted in the **São Paulo (`sa-east-1`)** region. Chosen for the deeply relational entity model this product needs — Leagues, Tournaments, Venues, Teams, Players, Matches — plus built-in Realtime (Postgres change-data-capture over websockets) to push bracket and news-bulletin updates to the Player App without polling, and built-in Auth for the organizer side.
- **State/versioning model:** Bracket generation writes to a `draft` state distinct from the `published` state. An organizer's manual overrides mutate the draft; publish is a single transactional commit that promotes the draft to the live, player-visible schedule. This is a data-model concern (a `status` column plus a `draft_matches` vs. `matches` distinction, or an append-only `bracket_versions` table), not a separate service.
- **Player App client:** Flutter, consuming the Nitro read-only API and subscribing to Supabase Realtime channels for live bracket/news updates. Codebase targets iOS + Android from day one; **tester distribution starts Android-only** (see Budget & Infra Tier below) with iOS added once the team is ready to pay for Apple Developer Program membership.
- **Hosting (testing phase):** Nuxt Back Office deploys to **Vercel's Hobby (free) tier**. Hobby's terms restrict it to non-commercial use — acceptable now since no payment or ad revenue is actually being collected yet, but this is a real trigger, not a formality: the moment a paid tier or live AdMob revenue goes live, this must move to Vercel Pro ($20/seat/mo). Flagged here so it isn't missed at launch.

### Budget & Infra Tier (testing phase)

Everything free-tier where a free tier genuinely exists, per Ian's call to defer cost decisions until there are real testers:

| Component | Plan | Cost | Real constraint to know about |
|---|---|---|---|
| Supabase (data layer, São Paulo) | Free | $0 | 500MB DB, 1GB file storage, 5GB egress/mo, **no automatic backups or point-in-time recovery**, project **auto-pauses after 7 days with no API traffic** |
| Nuxt Back Office hosting | Vercel Hobby | $0 | 100GB bandwidth/mo, 10s max function execution, **non-commercial use only per ToS** — upgrade to Pro at first real payment/ad revenue |
| Android tester distribution | Google Play Console | $25 one-time | Google's 2026 policy requires a 14-day closed test with 12+ active testers before a production release is allowed — factor into Phase 3 timing |
| iOS tester distribution | — | Deferred | Requires Apple Developer Program, $99/year — not started until the team decides to spend on it |
| Google AdMob | Free to integrate | $0 | No cost to add the SDK; only becomes revenue (not cost) once live |

The auto-pause and no-PITR facts above directly affect the Security & Privacy retention policy below — read together, not independently.

### Integration Points

- **Auth:** Supabase Auth, email/password with magic-link sign-in, for organizer accounts only. The Player App has no auth integration point — every endpoint it calls is public-read, scoped to published (never draft) tournament data.
- **Realtime updates:** Supabase Realtime, subscribed from the Flutter app to the tournament/league channels the player is currently viewing.
- **Time zones:** All venue operating hours and match timestamps are stored in UTC with an IANA time zone identifier per venue; conversion to local display time happens at the client. No external timezone API is required — this is a library concern on each client: **Luxon** on the Nitro/Node side (the standard IANA-timezone-aware date library in that ecosystem, used for all server-side scheduling math) and the **`timezone`** Dart package paired with **`flutter_timezone`** (device timezone detection) on the Flutter side, for local-time display only.
- **Advertising:** Google AdMob via its official Flutter plugin, for sponsor ad placement in the Player App. No custom ad server for MVP.
- **Payments:** None. Explicitly out of scope for MVP (see Non-Goals).

### Security & Privacy

- Player App collects no PII and requires no account — players are identified only by the display name/roster data the organizer enters in the Back Office, which is intentionally public within the league (this is the product: public brackets and public historical results).
- Organizer accounts (email, auth credentials) are the only PII in the system, held by Supabase Auth; standard practice applies (hashed/managed by Supabase, never stored in plaintext by ILEAGUE's own code).
- Draft-state bracket data is only readable by the authenticated organizer who owns the tournament — the public read API only ever serves `published` data, enforced via Postgres Row Level Security policies, not application-layer checks alone.
- **Data retention policy (formal, in effect from MVP):**
  - **Player/match data** (display names, results, standings, historical bracket data): retained indefinitely by design — this is the product's core value ("preserve historical records"). Not personal data under GDPR in the ordinary case (no account, no contact info, no way to link a display name back to a real identity through ILEAGUE), so it is not subject to erasure-request handling. An organizer can still request removal of a specific league's public data via support; fulfilled within 30 days, same SLA as below.
  - **Organizer account data** (email, auth credentials, billing info once tiers ship): retained for the lifetime of the account. On account deletion request, PII is purged from primary tables within 30 days. The organizer's published league/tournament data is *not* auto-deleted with the account (it stays live per the point above) unless the organizer explicitly requests full league removal in the same request.
  - **Backups:** during the free-tier testing phase (see Budget & Infra Tier above), Supabase provides **no automatic backups and no point-in-time recovery** — a deletion is final immediately, there is no backup copy for it to linger in. This also means there's no disaster-recovery safety net for the project itself until it's upgraded to Pro (which adds a 7-day daily-backup window and up to 14 days of PITR). That upgrade is a prerequisite before the retention/erasure SLA below can be considered fully backstopped — noted as a gap, not glossed over.
  - **Right-to-erasure posture:** built in from MVP even though the product doesn't yet target EU organizers specifically — cheaper to have the 30-day SLA and support-request flow in place now than to retrofit it once the org has EU customers.

---

## 5. Pricing & Monetization

Three tiers: one free, two paid, billed monthly (no per-event option). Tier boundaries are drawn on scale (tournaments/venues/players), collaboration (admin seats — see §6 v1.1), and support, never on the scheduling engine or tournament formats themselves — every tier gets the same format support, because gatekeeping the product's actual differentiator behind a paywall undermines the adoption thesis in §1.

| | **Free — Community** | **Organizer** ($20/mo) | **League / Pro** ($50/mo) |
|---|---|---|---|
| Concurrent active tournaments | 1 | 3 | Unlimited |
| Venues per tournament | 2 | 5 | Unlimited |
| Players per tournament | Up to 32 | Up to 128 | Unlimited |
| Tournament formats | All | All | All |
| League admin seats | 1 (owner only) | Up to 3, realtime concurrent editing (v1.1) | Unlimited, role-based permissions (v2.0) |
| Historical data retention | 90 days post-tournament (see retention policy, §4) | Indefinite | Indefinite + CSV/data export |
| Back Office branding | ILEAGUE branding shown | ILEAGUE branding shown | Custom league logo/branding |
| Player App sponsor ads | Shown (default monetization) | Shown | Shown |
| Support | Community/self-serve | Priority email | Priority email, faster SLA |

*"Tournament formats: All" means every format ILEAGUE supports at the time, currently Single Elimination and Swiss (MVP) — not a promise of Double Elimination/Round Robin ahead of the v2.0 roadmap in §6; formats simply aren't a tier-gating axis.*

Rationale for the free tier's shape: 2 venues at no cost means the free tier already covers the exact scenario in §2's primary persona — a main venue plus an overflow space — so the headline use case this PRD opens with is fully free-tier-eligible, which is what the adoption thesis in §1 depends on. The upgrade trigger for a recurring organizer is scale (more concurrent tournaments, more players, more venues) and collaboration (multiple league admins, v1.1), not access to the core product.

---

## 6. Risks & Roadmap

### Phased Rollout

No fixed calendar deadline for MVP — priority is correctness of the scheduling engine over speed to ship. Phases remain sequential and gated by their milestone, not by a date.

- **Phase 1 — Backend Architecture & Nuxt Dashboard.** Supabase schema (Leagues, Tournaments, Venues, Teams, Players, Matches, draft/published state), Nitro API routes, organizer auth, tournament creation wizard, and the scheduling engine itself. **Milestone:** generate a 64-player Swiss bracket across 3 simulated venues with zero scheduling collisions, verified by the automated conflict-detector, in under 10 seconds.
- **Phase 2 — Mobile Client & API Exposure.** Flutter Player App (codebase targets iOS + Android), read-only API surface, Supabase Realtime subscriptions, AdMob integration. **Milestone:** a published multi-venue bracket renders live on Android with bracket/news updates visible within 2 seconds of the organizer's publish action. iOS build stays code-complete but undistributed until Apple Developer Program membership is purchased (see Budget & Infra Tier, §4).
- **Phase 3 — UAT & End-to-End Testing.** Simulated live tournament exercising manual overrides, bracket progression, draft-to-publish flow, and mobile ad display concurrently. **Milestone:** a full simulated event runs start to finish with zero unresolved scheduling conflicts and zero manual-override actions lost or misapplied. Real-tester rollout on Android goes through Google Play's closed testing track — budget at least 14 days with 12+ active testers before a production release is possible (2026 Play Console policy).

### Post-MVP Roadmap

- **v1.1 — Multi-admin leagues.** Multiple "league admin" seats per league (Organizer/League tiers, §5) with realtime concurrent editing of tournament/venue data. Concurrency safety extends the existing NFR that concurrent bracket updates process in under 2 seconds to prevent data collision (§2): each write carries an optimistic-concurrency version check, and the Back Office surfaces a live presence indicator (who else is viewing/editing this tournament right now) so two admins don't blind-write over each other's changes.
- **v2.0 — Scale and format expansion.** Double Elimination and Round Robin formats; role-based admin permissions (e.g., full admin vs. scorekeeper-only); evaluate payment-gateway integration if organizer demand emerges for in-app entry-fee collection (still explicitly out of MVP scope, §2).

### Technical Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Constraint-solver complexity grows non-linearly with player/venue count, causing slow or blocking bracket generation | Organizer-facing timeouts during event setup, directly hurting the Tournament Completion Rate success metric | Run generation as a background worker job, not inline in the request/response cycle; the < 10s / 64-player benchmark in Phase 1 is the gate before this is considered solved |
| Organizer publishes an incorrect bracket without reviewing it | Player-facing schedule errors during a live event, the worst-case failure for this product | Mandatory `draft` → review → explicit `publish` state machine; publish UI shows a full schedule summary plus a confirmation step before any data becomes player-visible |
| Realtime update latency or dropped Supabase Realtime connections in crowded venues with poor connectivity | Players see stale schedule data at exactly the moment they need it most | Player App falls back to a pull-to-refresh / periodic poll if the Realtime subscription drops, so live data is never permanently stuck stale |
| Time zone handling errors for remote/online cups spanning multiple regions | Wrong match times shown to players, defeating the core value proposition | Store all timestamps as UTC + IANA venue time zone at the data layer; never store or compute in local time server-side |
| Supabase free-tier project auto-pauses after 7 days with no API traffic | Backend (and both apps) go dark for organizers/testers checking in on an inactive project — the exact failure mode a low-traffic testing phase is prone to | Cheapest fix: a scheduled health-check ping (e.g., free GitHub Actions cron hitting a Nitro health endpoint) keeps the project active; accept as a known risk until testing traffic is naturally frequent enough to make it moot, or the project moves to Pro |
| No backups/PITR on Supabase free tier during testing phase | A bad migration or accidental delete during early development has no recovery path | Acceptable risk while the dataset is test data with no real organizers depending on it; this must be resolved (upgrade to Pro) before any real, paying organizer's data goes live |

---

## Open Items (explicitly deferred, not blocking MVP build)

All prior open items are resolved (region, pricing, billing cadence, budget — see Budget & Infra Tier, §4). One new item surfaced by the free-tier decision:

- **When to upgrade off free tier** — no fixed trigger date, but three concrete events force it: (1) a real paying organizer's data goes live (needs Supabase Pro for backups/PITR), (2) a paid tier or live AdMob revenue starts (violates Vercel Hobby's non-commercial ToS), (3) the team is ready to spend on Apple Developer Program to add iOS testers. Revisit this list when any one of the three happens, not on a calendar.
