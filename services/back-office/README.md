# services/back-office

## Scope

The organizer-facing product: a Nuxt 3 web app with Nitro server routes colocated. See `implementationPlan/05-back-office.md`.

Owns:
- Organizer auth (Supabase Auth: email/password + magic-link).
- Tournament creation wizard, venue management.
- Draft review & override UI, and the publish flow (draft → review → explicit publish, never direct-publish).
- News bulletins (create + publish only, per PRD scope).
- Tier-limit enforcement — both the UI (dashboard usage display, wizard-time limit checks) and the server-side API checks that are the real enforcement point (`services/back-office`'s Nitro routes), per `implementationPlan/07-billing-tier-enforcement.md`.
- `/api/health` — the endpoint the repo-root health-check cron pings to prevent Supabase free-tier auto-pause.

Deployed to Vercel Hobby (free tier) during the testing phase — see the PRD's Budget & Infra Tier table for the non-commercial ToS caveat and upgrade trigger.

## Non-scope

- No scheduling algorithm implementation — calls `services/scheduling-engine` via its documented invocation contract in `contracts/scheduling/`, never reimplements or reaches into its internals.
- No payment collection (Stripe or similar) — explicitly deferred past MVP, tracked as `E7-T7` in `implementationPlan/07-billing-tier-enforcement.md`.
- Does not talk to Postgres directly outside the Supabase client + RLS policies `services/supabase-infra` defines.

## Where to start

`implementationPlan/05-back-office.md` for the full task breakdown (E5-T1 through E5-T7).

## Health-check cron activation (E5-T1 TODO)

`.github/workflows/health-check-cron.yml` (E1-T4) is scaffolded but inert — it
prints an informational message and exits green because no `HEALTH_CHECK_URL`
repository variable is set yet. Once E5-T1 deploys the real `/api/health`
endpoint, set the variable so the cron actually pings it:

```
gh variable set HEALTH_CHECK_URL --body <deployed-url>/api/health
```

(or via the GitHub UI: Settings → Secrets and variables → Actions →
Variables). This is not a secret — use a repository **variable**, not a
secret.
