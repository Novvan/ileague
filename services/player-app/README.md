# services/player-app

## Scope

The read-only, login-free competitor client, built with Flutter. See `implementationPlan/06-player-app.md`.

Owns:
- Next-match view (opponent, time, venue) — reachable in ≤2 taps, TTI <1.5s on throttled 3G-equivalent, mid-tier Android device.
- Historical results view (paginated; Free-tier leagues archive results >90 days old from public view, per `implementationPlan/07-billing-tier-enforcement.md`).
- News feed, subscribed to the Realtime channel `services/back-office` publishes bulletins to.
- Realtime subscription with a pull-to-refresh/periodic-poll fallback if the connection drops.
- Google AdMob integration (official Flutter plugin only, no custom ad server).
- Client-side timezone display (Dart `timezone` + `flutter_timezone`, converting the UTC+IANA data the backend provides — never computes in local time itself beyond display conversion).

Codebase targets iOS + Android from day one; **tester distribution is Android-only** this phase via Google Play Console closed testing (iOS deferred until Apple Developer Program membership is purchased).

## Non-scope

- **Zero authentication, anywhere.** This is a hard product requirement, not a missing feature — no account creation, no credential input, no auth-scoped API calls.
- No write access to any data — this app only ever reads.
- No iOS distribution this phase (code-complete, undistributed).

## Where to start

`implementationPlan/06-player-app.md` for the full task breakdown (E6-T1 through E6-T8).
