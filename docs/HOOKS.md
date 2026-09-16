# Local git hooks

This repo ships a local pre-commit gate at `.githooks/pre-commit` (plain bash,
no husky/lint-staged -- there's no root `package.json`/Node project here, and
the global CLAUDE.md's "vanilla by default" rule favors the dependency-free
option over adding a JS tool just to run a hook).

## What it does

On every `git commit`, the hook:

1. Reads the staged files (`git diff --cached --name-only --diff-filter=ACM`).
2. Maps each staged file to its owning area: `services/supabase-infra`,
   `services/scheduling-engine`, `services/back-office`, `services/player-app`,
   `contracts/`, or "other" for anything outside those (repo root, `docs/`,
   `implementationPlan/`, etc.).
3. For each area that has staged changes, it looks for that area's own
   lint/format/typecheck tooling:
   - a `package.json` with a `"lint"` or `"typecheck"` script -> runs
     `npm run lint` / `npm run typecheck` scoped to that area's directory.
   - a `pubspec.yaml` -> runs `flutter analyze` scoped to that area's directory.
4. If an area has staged changes but no tooling configured yet, it prints a
   message saying so (e.g. `services/back-office: staged changes, no lint
   tooling configured yet -- skipping`) and continues. It never skips a
   check silently -- there is always a printed line explaining why nothing
   ran.
5. Exits non-zero (blocking the commit) only if a tool it actually ran
   failed. An area with no tooling yet never blocks a commit.

This mirrors E1-T2's CI path filtering: a diff confined to one service only
runs that service's checks, both locally and in CI, so "passing" means the
same thing in both places. The detection is real, not a stub -- once a later
epic adds a `package.json` `lint`/`typecheck` script or a `pubspec.yaml` to
one of these areas, the hook picks it up on the next commit without being
rewritten.

Right now this repo is still a greenfield skeleton (no `package.json`, no
`pubspec.yaml` anywhere yet -- see the root `CLAUDE.md`'s "Repo state" note),
so every commit currently prints a per-area "no lint tooling configured yet"
line for whatever you staged, and exits 0.

## One-time setup

Git doesn't use `.githooks/` automatically -- it has to be told to look
there instead of the default `.git/hooks/`. Run this once per clone:

```sh
git config core.hooksPath .githooks
```

This is a local, per-clone git config value -- it isn't (and can't be)
committed, so every contributor runs the command once themselves after
cloning.

## Emergency bypass

Standard git mechanism, always visible, never something the hook does on
its own:

```sh
git commit --no-verify
```

Per the global CLAUDE.md's safety rules, this is for genuine emergencies
only -- if the hook is flagging a real problem, fix the underlying issue
instead of reaching for `--no-verify`.
