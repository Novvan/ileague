# Secrets & environment variables

Traces every environment variable used anywhere in this repo: where it's generated,
where it lives per environment, and which service(s) consume it. Read this before
provisioning a new environment or adding a new variable.

Two categories, not interchangeable:

- **Secret** — grants access or lets someone impersonate the system. Never logged,
  never in a public/client-safe var, never committed, rotated if it leaks.
- **Config** — safe to expose client-side or in a public repo. Naming it here is
  about tracing where it flows, not about hiding it.

Every `services/<name>/.env.example` documents the same variables with placeholder
values. This file is the map of where the *real* values come from and go.

## Local development

Every real value lives in a per-service `.env`, copied from that service's
`.env.example` and filled in by hand. `.env` is gitignored repo-wide (root
`.gitignore`); `.env.example` is explicitly not, and is the only one committed.

## services/supabase-infra

CLI-only credentials — used to run `supabase` CLI commands (migrations, linking,
seeding) against the real project. Not consumed by application code.

| Variable | Secret? | Generated | Stored | Consumed by |
|---|---|---|---|---|
| `SUPABASE_PROJECT_REF` | Config | Supabase dashboard, project URL/Settings > General, at project creation | Local `.env` (gitignored); GitHub Actions secret if migrations run in CI | Supabase CLI (`supabase link`, `supabase db push`) |
| `SUPABASE_ACCESS_TOKEN` | **Secret** (account-level API access) | Supabase dashboard > Account > Access Tokens | Local `.env` (gitignored); GitHub Actions secret if migrations run in CI | Supabase CLI |
| `SUPABASE_DB_PASSWORD` | **Secret** | Set at project creation, Supabase dashboard > Settings > Database | Local `.env` (gitignored); GitHub Actions secret if migrations run in CI | Supabase CLI (direct Postgres connection for `db push`) |

Project region (`sa-east-1`, São Paulo) is set once at project creation in the
Supabase dashboard — it's config, not a secret, and isn't an env var anywhere;
noted in `services/supabase-infra/.env.example` for whoever provisions the project.

## services/scheduling-engine

In production this runs as a Supabase Edge Function, where `SUPABASE_URL` and
`SUPABASE_SERVICE_ROLE_KEY` are **auto-injected by the Supabase runtime** — no env
var is set for them anywhere in our own config for the deployed function. The two
vars below exist only for running/testing the engine locally, outside the Edge
Function environment.

| Variable | Secret? | Generated | Stored | Consumed by |
|---|---|---|---|---|
| `SUPABASE_URL` | Config | Supabase dashboard > Settings > API | Local `.env` (gitignored) for local test runs; auto-injected in the deployed Edge Function, not configured by us | Local test harness; (auto-injected in prod) |
| `SUPABASE_SERVICE_ROLE_KEY` | **Secret** (bypasses RLS) | Supabase dashboard > Settings > API | Local `.env` (gitignored) for local test runs; auto-injected in the deployed Edge Function, not configured by us | Local test harness; (auto-injected in prod) |

## services/back-office

Deploys to Vercel Hobby. Real values are set as Vercel **project environment
variables** (Vercel dashboard > Project > Settings > Environment Variables),
scoped per environment (Development / Preview / Production).

| Variable | Secret? | Generated | Stored | Consumed by |
|---|---|---|---|---|
| `SUPABASE_URL` | Config — safe in the client bundle | Supabase dashboard > Settings > API | Local `.env` (gitignored); Vercel project env var (all environments) | Nuxt client + Nitro server |
| `SUPABASE_ANON_KEY` | Config — safe in the client bundle by design; RLS policies (`services/supabase-infra`) are the real access boundary | Supabase dashboard > Settings > API | Local `.env` (gitignored); Vercel project env var (all environments) | Nuxt client + Nitro server |
| `SUPABASE_SERVICE_ROLE_KEY` | **Secret** — bypasses RLS entirely | Supabase dashboard > Settings > API | Local `.env` (gitignored); Vercel project env var, server-only scope (`runtimeConfig`, never `runtimeConfig.public`) | Nitro server routes only (tier-limit enforcement, any RLS-bypassing write) — **must never reach the client bundle** |
| `NUXT_SESSION_SECRET` | **Secret** | Generated per environment (`openssl rand -base64 32` or equivalent), never reused across Preview/Production | Local `.env` (gitignored); Vercel project env var, server-only scope | Nitro server (Supabase Auth session/cookie signing) |

## services/player-app

No auth of any kind — there is no auth token/secret in this app by design. All
values below are public-safe and ship inside the compiled app binary; wired in via
whatever Flutter env-loading approach is adopted (`--dart-define`,
`flutter_dotenv`, etc.) when real app code lands.

| Variable | Secret? | Generated | Stored | Consumed by |
|---|---|---|---|---|
| `SUPABASE_URL` | Config | Supabase dashboard > Settings > API | Local `.env` (gitignored); baked into the build (dart-define / build config) per environment | Flutter app (public-read API calls only) |
| `SUPABASE_ANON_KEY` | Config — safe in a shipped app binary; RLS is the real access boundary, and this app is read-only besides | Supabase dashboard > Settings > API | Local `.env` (gitignored); baked into the build | Flutter app |
| `ADMOB_APP_ID_ANDROID` | Config | AdMob console > App > App settings, per app registration | Local `.env` (gitignored); baked into `AndroidManifest.xml` at build time | Flutter app (Android) |
| `ADMOB_APP_ID_IOS` | Config | AdMob console > App > App settings, per app registration | Local `.env` (gitignored); baked into `Info.plist` at build time | Flutter app (iOS) — code-complete, undistributed this phase |
| `ADMOB_BANNER_UNIT_ID_ANDROID` | Config | AdMob console > App > Ad units | Local `.env` (gitignored); baked into the build | Flutter app (Android) |
| `ADMOB_BANNER_UNIT_ID_IOS` | Config | AdMob console > App > Ad units | Local `.env` (gitignored); baked into the build | Flutter app (iOS) — code-complete, undistributed this phase |

## CI/CD-only (not in any service's `.env.example` — never touch a developer's machine)

These belong to automation, not to any one service's runtime. They live only as
GitHub Actions repository secrets/variables, and in Vercel's own project settings
for the Vercel integration.

| Variable | Secret? | Generated | Stored | Consumed by |
|---|---|---|---|---|
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | **Secret** (full Play Console API access for this app) | Google Play Console > Setup > API access > create a service account (via Google Cloud Console), grant it release-manager permissions, download the JSON key | GitHub Actions repository secret only — never a local `.env`, never logged | CI/CD workflow for `services/player-app` Android release automation (`implementationPlan/06-player-app.md`, E6-T8) |
| `VERCEL_TOKEN` | **Secret** | Vercel dashboard > Account Settings > Tokens | GitHub Actions repository secret | CI/CD workflow deploying `services/back-office` to Vercel |
| `VERCEL_ORG_ID` | Config (identifier, not a credential, but scoped to CI use) | Vercel CLI (`vercel link`, written to `.vercel/project.json`) or Vercel dashboard project settings | GitHub Actions repository secret (kept alongside `VERCEL_TOKEN` for convenience; not sensitive on its own) | CI/CD workflow deploying `services/back-office` to Vercel |
| `VERCEL_PROJECT_ID` | Config (identifier, not a credential) | Vercel CLI (`vercel link`, written to `.vercel/project.json`) or Vercel dashboard project settings | GitHub Actions repository secret (kept alongside `VERCEL_TOKEN` for convenience) | CI/CD workflow deploying `services/back-office` to Vercel |
| `HEALTH_CHECK_URL` | Config (a URL, not a credential) | The deployed Back Office's `/api/health` route — placeholder/localhost until `implementationPlan/05-back-office.md`'s E5-T1 ships the real endpoint, then the real deployed URL | GitHub Actions **repository variable** (not a secret — it's just a URL) | The health-check cron workflow (`implementationPlan/01-repo-bootstrap.md`, E1-T4) that pings it to prevent Supabase free-tier auto-pause |

## What's NOT here on purpose

- **No external timezone API key.** Per the PRD (§4 Technical Specifications):
  timestamps are stored as UTC + IANA timezone identifier, and conversion to local
  display time happens client-side using **Luxon** (Nitro/Node side, server-side
  scheduling math) and the Dart **`timezone`** + **`flutter_timezone`** packages
  (Flutter side, local-time display only). Both are libraries, not services — no
  secret, no env var, no network call.
- **No Stripe/payment keys.** Organizer billing is explicitly deferred past the
  testing phase (`implementationPlan/07-billing-tier-enforcement.md`, E7-T7).
  Nothing to configure yet.

## Rotation

If a secret above leaks (committed by accident, exposed in a log, a laptop lost):
rotate it at its source (the dashboard/CLI command in the "Generated" column
above), then update every place it's stored (local `.env` files are per-developer
and self-serve; GitHub Actions secrets and Vercel project env vars need updating
by whoever has admin access). `SUPABASE_SERVICE_ROLE_KEY` and
`SUPABASE_DB_PASSWORD` are the highest-blast-radius rotations — they touch every
environment at once.
