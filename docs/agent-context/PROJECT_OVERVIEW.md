# ILEAGUE — project overview

Condensed digest of `ILEAGUE_PRD.md` (in the `ileague` hub repo). Read the full PRD before making any product-behavior decision — this is orientation, not a replacement.

## Problem

Tournament organizers running physical-venue and esports events are stuck with rigid, single-purpose software that can't handle multi-venue, multi-timeslot logistics. Manually checking that no player is double-booked, no pairing repeats, and every match is routed to a free venue doesn't scale past a small event.

## Solution

A constraint-based scheduling engine wrapped in two clients:
- **Back Office** (organizer-facing, web): define venues, match durations, player counts → auto-generated conflict-free Swiss or Single-Elimination bracket, with a mandatory draft-review/override step before anything goes live.
- **Player App** (competitor-facing, mobile, read-only, no login): next opponent, venue, time, and historical results.

## Personas

- **Community League Manager** (primary, organizer) — runs events across one or more physical venues, needs the system to handle venue/timeslot conflict math so they don't have to.
- **Competitive Player** (secondary, read-only) — wants zero-friction "when and where do I play next," no account required.

## Success metrics (Q1 post-launch)

| Metric | Target |
|---|---|
| SaaS conversion rate | ≥15% free→paid |
| Tournament completion rate | ≥90% reach finalized state |
| Player app adoption | ≥75% of registered players open the app during an active tournament |
| Scheduling correctness | 0 mathematically conflicting published schedules, ever |
| Bracket generation performance | 64-player Swiss bracket, 3 venues, <10 seconds |

## Pricing (3 tiers, monthly billing, no per-event option)

| | Free | Organizer ($20/mo) | League/Pro ($50/mo) |
|---|---|---|---|
| Concurrent active tournaments | 1 | 3 | Unlimited |
| Venues per tournament | 2 | 5 | Unlimited |
| Players per tournament | Up to 32 | Up to 128 | Unlimited |
| Admin seats | 1 (owner only) | Up to 3 (v1.1 feature) | Unlimited (v2.0 feature) |
| Historical retention | 90 days, then archived from public view — never deleted | Indefinite | Indefinite + CSV export |

Tier boundaries are scale + collaboration + support — **never** the scheduling engine or supported formats. Every tier gets identical format support by design (gatekeeping the product's actual differentiator behind a paywall would undermine adoption).

## Tech stack

- **Back Office**: Nuxt 3 (Vue), Nitro server routes colocated.
- **Scheduling Engine**: deterministic TypeScript, Deno-compatible, runs as a Supabase Edge Function (not a Vercel function — see `DECISIONS.md` #3).
- **Player App**: Flutter, iOS + Android codebase, Android-first tester distribution.
- **Data layer**: Supabase (Postgres), region `sa-east-1` (São Paulo).
- **Hosting (testing phase)**: Back Office on Vercel Hobby (free tier).
- **Monetization (Player App)**: Google AdMob, official Flutter plugin only.

## Non-goals (MVP)

Double Elimination / Round Robin formats (v2.0), in-app payments in the Player App, player accounts/login of any kind, AI/agent-driven dispute resolution (the scheduling engine is fully deterministic, standard tests not evals), multi-admin back office access (v1.1), native push notifications (Realtime in-app updates are in scope, OS push is not).

## Budget posture

Everything on free tier during the testing phase (Ian's explicit call: "start with free tier on everything, revisit costs after there are testers"). Real dollar costs so far: Google Play Console, $25 one-time. iOS distribution deferred (Apple Developer Program, $99/year, not yet purchased) — Android-first testing.
