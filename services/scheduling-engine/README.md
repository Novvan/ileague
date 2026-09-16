# services/scheduling-engine

## Scope

The product's core differentiator: deterministic bracket/pairing generation and constraint solving, with zero tolerance for scheduling conflicts. See `implementationPlan/04-scheduling-engine.md`.

Owns:
- Single-Elimination bracket generator.
- Swiss pairing algorithm (avoids repeat pairings whenever an unplayed opponent exists).
- Venue/timeslot constraint solver (zero player double-bookings, zero venue-timeslot double-bookings — the PRD's own bar is "0, ever").
- Conflict detector — a standalone re-verification pass used both at generation time and after every manual organizer edit.
- The job wrapper that runs all of the above as a **Supabase Edge Function**, not a Vercel function (Vercel Hobby's 10s execution cap has zero margin against the PRD's own `<10s`/64-player benchmark; Edge Functions give 150s on the free tier).

**This package must be Deno-compatible**, not just Node — it runs inside a Supabase Edge Function. Check Deno support before adding any dependency here.

## Non-scope

- No persistence — this is a pure function plus a thin job wrapper. It does not talk to the database directly; `services/back-office`'s Nitro routes own reading tournament config in and writing the resulting `Match[]` out.
- No UI. No HTTP/Nitro-specific code — consumed via the documented invocation contract in `contracts/scheduling/`, nothing reaches into this package's internals.

## Where to start

`implementationPlan/04-scheduling-engine.md` for the full task breakdown (E4-T1 through E4-T6). This is the highest-scrutiny epic in the plan — several tasks here are sized `large` and call for a harsh-critic pass, not a single implementation attempt.
