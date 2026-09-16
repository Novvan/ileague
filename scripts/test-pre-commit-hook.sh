#!/usr/bin/env bash
#
# scripts/test-pre-commit-hook.sh
#
# Gate test for .githooks/pre-commit -- deterministic, local, free, no
# network, well under 2 seconds. Run it directly or wire it into CI:
#
#   bash scripts/test-pre-commit-hook.sh
#
# Each case builds a throwaway sandbox git repo (mktemp -d), copies the real
# hook script into it, stages files, runs the hook, and asserts on its
# stdout and exit code. npm and flutter are mocked with fake executables on
# PATH so this test never depends on -- or is slowed down by -- whatever
# toolchains happen to be installed on the machine running it (this
# environment, for instance, has no `flutter` at all).

set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
HOOK_SRC="$REPO_ROOT/.githooks/pre-commit"

if [ ! -f "$HOOK_SRC" ]; then
  echo "FATAL: $HOOK_SRC not found"
  exit 1
fi

PASS=0
FAIL=0
SANDBOXES=()

cleanup() {
  local dir
  for dir in "${SANDBOXES[@]}"; do
    rm -rf "$dir"
  done
}
trap cleanup EXIT

# --- assertion helpers ------------------------------------------------

assert_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $desc"
    echo "  expected output to contain: $needle"
    echo "  actual output:"
    echo "$haystack" | sed 's/^/    /'
  fi
}

assert_not_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $desc"
    echo "  expected output NOT to contain: $needle"
    echo "  actual output:"
    echo "$haystack" | sed 's/^/    /'
  fi
}

assert_eq() {
  local desc="$1" actual="$2" expected="$3"
  if [ "$actual" = "$expected" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $desc (expected '$expected', got '$actual')"
  fi
}

# --- sandbox + mock-tool setup -----------------------------------------

# new_sandbox: creates an isolated git repo with the four known service
# dirs + contracts/, a copy of the real hook, and mock `npm`/`flutter`
# executables at the front of PATH.
new_sandbox() {
  local dir
  dir=$(mktemp -d)
  SANDBOXES+=("$dir")

  git -C "$dir" init -q -b main
  git -C "$dir" config user.email "test@example.com"
  git -C "$dir" config user.name "Test"

  mkdir -p "$dir/services/supabase-infra" "$dir/services/scheduling-engine" \
    "$dir/services/back-office" "$dir/services/player-app" "$dir/contracts/domain" \
    "$dir/bin"

  cp "$HOOK_SRC" "$dir/hook-under-test"
  chmod +x "$dir/hook-under-test"

  cat >"$dir/bin/npm" <<'MOCK'
#!/usr/bin/env bash
# Mock npm: prints which script it was asked to run, exits $MOCK_EXIT_CODE.
script=""
for a in "$@"; do
  case "$a" in
    run|--silent) ;;
    *) script="$a" ;;
  esac
done
echo "MOCK_NPM_RAN:$script"
exit "${MOCK_EXIT_CODE:-0}"
MOCK
  chmod +x "$dir/bin/npm"

  cat >"$dir/bin/flutter" <<'MOCK'
#!/usr/bin/env bash
echo "MOCK_FLUTTER_RAN:$*"
exit "${MOCK_EXIT_CODE:-0}"
MOCK
  chmod +x "$dir/bin/flutter"

  echo "$dir"
}

# run_hook <sandbox-dir> -> stdout+stderr combined on stdout, sets
# LAST_EXIT to the hook's exit code.
run_hook() {
  local dir="$1"
  set +e
  OUTPUT=$(cd "$dir" && PATH="$dir/bin:$PATH" bash ./hook-under-test 2>&1)
  LAST_EXIT=$?
  set -e
}

git_add() {
  local dir="$1"
  shift
  git -C "$dir" add "$@"
}

# =========================================================================
# Test 1: staged file in an area with no tooling -> skip message, exit 0
# =========================================================================
d=$(new_sandbox)
echo "hello" >"$d/services/back-office/note.txt"
git_add "$d" services/back-office/note.txt
run_hook "$d"
assert_contains "no-tooling area prints skip message" "$OUTPUT" \
  "services/back-office: staged changes, no lint tooling configured yet -- skipping"
assert_eq "no-tooling area exits 0" "$LAST_EXIT" "0"

# =========================================================================
# Test 2: multiple touched areas each get their own message
# =========================================================================
d=$(new_sandbox)
echo "a" >"$d/services/back-office/note.txt"
echo "b" >"$d/contracts/domain/note.txt"
git_add "$d" services/back-office/note.txt contracts/domain/note.txt
run_hook "$d"
assert_contains "back-office reported" "$OUTPUT" "services/back-office: staged changes, no lint tooling configured yet -- skipping"
assert_contains "contracts reported" "$OUTPUT" "contracts: staged changes, no lint tooling configured yet -- skipping"
assert_not_contains "untouched area not reported" "$OUTPUT" "services/player-app:"
assert_eq "multi-area no-tooling exits 0" "$LAST_EXIT" "0"

# =========================================================================
# Test 3: file outside all known areas -> "other" bucket, still reported
# =========================================================================
d=$(new_sandbox)
mkdir -p "$d/docs"
echo "readme" >"$d/docs/NOTE.md"
git_add "$d" docs/NOTE.md
run_hook "$d"
assert_contains "other bucket reported" "$OUTPUT" "other (repo root / outside services & contracts): staged changes, no lint tooling configured yet -- skipping"
assert_eq "other bucket exits 0" "$LAST_EXIT" "0"

# =========================================================================
# Test 4: no staged files at all -> exits 0, nothing printed
# =========================================================================
d=$(new_sandbox)
run_hook "$d"
assert_eq "empty diff exits 0" "$LAST_EXIT" "0"
assert_eq "empty diff prints nothing" "$OUTPUT" ""

# =========================================================================
# Test 5: package.json with a "lint" script -> hook detects and runs it
# =========================================================================
d=$(new_sandbox)
cat >"$d/services/back-office/package.json" <<'EOF'
{
  "name": "back-office",
  "scripts": {
    "lint": "eslint ."
  }
}
EOF
echo "x" >"$d/services/back-office/app.ts"
git_add "$d" services/back-office/package.json services/back-office/app.ts
run_hook "$d"
assert_contains "detects configured lint script" "$OUTPUT" "services/back-office: running npm run lint"
assert_contains "mock npm actually invoked with 'lint'" "$OUTPUT" "MOCK_NPM_RAN:lint"
assert_not_contains "no skip message once tooling exists" "$OUTPUT" "no lint tooling configured yet"
assert_eq "passing lint script exits 0" "$LAST_EXIT" "0"

# =========================================================================
# Test 6: package.json with a "typecheck" script -> also detected and run
# =========================================================================
d=$(new_sandbox)
cat >"$d/services/back-office/package.json" <<'EOF'
{
  "name": "back-office",
  "scripts": {
    "typecheck": "tsc --noEmit"
  }
}
EOF
echo "x" >"$d/services/back-office/app.ts"
git_add "$d" services/back-office/package.json services/back-office/app.ts
run_hook "$d"
assert_contains "detects configured typecheck script" "$OUTPUT" "services/back-office: running npm run typecheck"
assert_eq "passing typecheck script exits 0" "$LAST_EXIT" "0"

# =========================================================================
# Test 7: a failing lint script blocks the commit (non-zero exit)
# =========================================================================
d=$(new_sandbox)
cat >"$d/services/back-office/package.json" <<'EOF'
{
  "name": "back-office",
  "scripts": {
    "lint": "eslint ."
  }
}
EOF
echo "x" >"$d/services/back-office/app.ts"
git_add "$d" services/back-office/package.json services/back-office/app.ts
MOCK_EXIT_CODE=1 run_hook "$d"
assert_contains "failing lint is reported" "$OUTPUT" "services/back-office: npm run lint FAILED"
assert_eq "failing lint script exits non-zero (blocks commit)" "$LAST_EXIT" "1"

# =========================================================================
# Test 8: pubspec.yaml -> flutter analyze detected and run
# =========================================================================
d=$(new_sandbox)
echo "name: player_app" >"$d/services/player-app/pubspec.yaml"
echo "x" >"$d/services/player-app/main.dart"
git_add "$d" services/player-app/pubspec.yaml services/player-app/main.dart
run_hook "$d"
assert_contains "detects pubspec.yaml" "$OUTPUT" "services/player-app: running flutter analyze"
assert_contains "mock flutter actually invoked" "$OUTPUT" "MOCK_FLUTTER_RAN:analyze"
assert_eq "passing flutter analyze exits 0" "$LAST_EXIT" "0"

# =========================================================================
# Test 9: a failing flutter analyze blocks the commit
# =========================================================================
d=$(new_sandbox)
echo "name: player_app" >"$d/services/player-app/pubspec.yaml"
echo "x" >"$d/services/player-app/main.dart"
git_add "$d" services/player-app/pubspec.yaml services/player-app/main.dart
MOCK_EXIT_CODE=1 run_hook "$d"
assert_contains "failing flutter analyze is reported" "$OUTPUT" "services/player-app: flutter analyze FAILED"
assert_eq "failing flutter analyze exits non-zero (blocks commit)" "$LAST_EXIT" "1"

# =========================================================================
# Test 10: untouched areas with tooling configured are never run
# (proves the hook is scoped to staged files, not a blanket lint-everything)
# =========================================================================
d=$(new_sandbox)
cat >"$d/services/player-app/pubspec.yaml" <<'EOF'
name: player_app
EOF
echo "b" >"$d/services/back-office/note.txt"
# Only stage the back-office file; player-app's pubspec.yaml is untracked/unstaged.
git_add "$d" services/back-office/note.txt
run_hook "$d"
assert_not_contains "unstaged area with tooling is not run" "$OUTPUT" "flutter analyze"
assert_eq "unrelated area exits 0" "$LAST_EXIT" "0"

# =========================================================================
# Test 11: performance -- must complete well under 5s on a small diff
# =========================================================================
d=$(new_sandbox)
echo "x" >"$d/services/back-office/note.txt"
git_add "$d" services/back-office/note.txt
start=$(date +%s%N)
run_hook "$d"
end=$(date +%s%N)
elapsed_ms=$(( (end - start) / 1000000 ))
if [ "$elapsed_ms" -lt 5000 ]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "FAIL: hook took ${elapsed_ms}ms on a trivial diff, budget is <5000ms"
fi

# --- summary -------------------------------------------------------------

echo ""
echo "pre-commit hook gate test: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
