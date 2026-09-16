# Epic 6 — Player App

**Maps to:** `services/player-app/` (Flutter)
**Depends on:** E2 (contracts, incl. the TS↔Dart sync mechanism), E5 (needs real published endpoints to consume).
**Blocks:** nothing downstream in MVP — this is the last MVP-scope client.

## Scope

The read-only, login-free competitor experience: next-match view, historical results, news feed, live updates, ads, correct local time display, and getting real testers onto Android. iOS ships code-complete but undistributed this phase (PRD Decision: Android-first, since TestFlight requires the $99/yr Apple Developer Program, not started yet).

## Non-scope

No auth of any kind, anywhere (this is a hard product requirement, not a missing feature). No write access to any data. No iOS distribution this phase.

## Tasks

### E6-T1 — App scaffold, iOS+Android codebase, zero-auth architecture
**Acceptance (PRD verbatim):** "No authentication, account creation, or credential input anywhere in the Player App." Builds for both iOS and Android targets (the codebase is not Android-only, only *distribution* is Android-first). A test/check proves zero calls to any auth-related endpoint anywhere in the app's network layer.
**Depends on:** E2-T2, E2-T5. **Size:** medium.

### E6-T2 — Next-match view
**Acceptance (PRD verbatim):** "A player can reach their personal 'next match' view (opponent, time, venue) in 2 taps or fewer from app launch." "Time-to-interactive is under 1.5 seconds on a throttled 3G-equivalent connection... tested on a mid-tier Android device" — measured with an actual throttled-network perf-test harness (Flutter DevTools timeline or equivalent), not eyeballed on a fast dev machine over wifi.
**Depends on:** E6-T1, E2-T2. **Size: large** — a hard, numeric NFR under throttled network conditions on the app's primary UX path; treat the 1.5s figure as a release gate, not an aspiration, and budget real device-testing time for it.

### E6-T3 — Historical results view
**Acceptance:** paginated per E2-T2's contract. For Organizer/League-tier leagues, results are queryable indefinitely, matching the PRD's Player App acceptance criterion. **For Free-tier leagues, results older than 90 days post-completion are archived out of the public read response** (per the retention decision in `07-billing-tier-enforcement.md`, E7-T4) — the UI should reflect this honestly (e.g., an "older results are archived — ask the organizer to upgrade" state) rather than implying every league's history is always available, since it isn't for Free tier.
**Depends on:** E6-T1, E2-T2. **Size:** medium.

### E6-T4 — News feed on home screen
**Acceptance (PRD verbatim):** bulletins published in the Back Office (E5-T6) "appear on the Player App home feed for all players in that league without an app restart" — subscribes to E2-T3's Realtime channel and updates the feed in place.
**Depends on:** E6-T1, E2-T3, E5-T6. **Size:** medium.

### E6-T5 — Realtime subscription + poll fallback
**Acceptance (PRD verbatim):** "Published bracket and news-bulletin updates are visible in the app within 2 seconds of the organizer's publish action (Supabase Realtime subscription, not polling)" — measured end-to-end from Back Office publish action to Player App UI update. **Owns PRD Technical Risk #3's mitigation, verbatim:** "Player App falls back to a pull-to-refresh / periodic poll if the Realtime subscription drops, so live data is never permanently stuck stale." Implemented as an explicit connection-state-driven fallback (the app knows when its Realtime subscription is down, not just silently stale) — a test simulates a dropped connection and asserts the app switches to polling with a bounded staleness window, not an indefinite one.
**Depends on:** E6-T1, E2-T3. **Size: large** — a hard 2-second latency bar plus deliberate resilience engineering (detecting and recovering from a dropped connection is genuinely harder than the happy path).
**Owns PRD Technical Risk #3's mitigation.**

### E6-T6 — AdMob integration
**Acceptance:** ad units integrated via the official Google AdMob Flutter plugin only, no custom ad server (per PRD §4). The E6-T2 TTI budget (<1.5s) is re-verified *with ads present* — ad SDK initialization is a common, easy-to-miss TTI regression source, so this is a distinct acceptance check, not assumed to be covered by E6-T2 alone.
**Depends on:** E6-T1, E6-T2. **Size:** medium.

### E6-T7 — Client-side timezone handling
**Acceptance (PRD verbatim):** "All venue operating hours and match timestamps are stored in UTC with an IANA time zone identifier per venue; conversion to local display time happens at the client. No external timezone API is required." Uses the Dart `timezone` package + `flutter_timezone` (device timezone detection). Unit tests cover DST-transition boundaries and a cross-hemisphere venue-vs-viewer pairing (e.g. a São Paulo venue's match time displayed correctly to a viewer in a very different timezone/DST regime). Zero network calls anywhere in the timezone-resolution path.
**Depends on:** E6-T1. **Size:** medium.
**Owns PRD Technical Risk #4's client-display half** (server-side math is E4-T3, storage is E2-T1/E3-T1).

### E6-T8 — Android tester distribution setup
**Acceptance (PRD verbatim):** Google Play Console closed testing track configured, one-time $25 registration fee paid; per the 2026 Play Console policy, a 14-day closed test with 12+ active testers is required before a production release is possible — budget that timeline explicitly into the rollout plan, don't discover it at release time. iOS distribution is explicitly out of scope for this task (tracked separately, blocked on Apple Developer Program purchase, not part of MVP).
**Depends on:** E6-T1 through E6-T7. **Size:** medium.

## Verification

`services/player-app/` has its own CI job (path-filtered per E1-T2) including E2-T5's contract tests against the shared fixtures, E6-T2's throttled-network TTI benchmark, and E6-T5's dropped-connection-fallback simulation. Done when: a real device (or emulator with network throttling) demonstrates the full flow — launch → next-match view in ≤2 taps under 1.5s TTI → historical results → live update within 2s of a Back Office publish → graceful fallback when Realtime is killed mid-session — and the Play Console closed-testing track is live with real testers enrolled.
