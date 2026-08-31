#!/usr/bin/env bash
# Test runner for bin/wrap-status.sh. Plain bash assertions, no framework.
# Seam under test: CLI only. Env in (WRAP_DIR, HERMES_DB, WRAP_HOURS,
# HERMES_SESSION_ID), stdout text + exit code + filesystem side effects out.
set -uo pipefail
cd "$(dirname "$0")/.."
source tests/fixtures.sh
DETECTOR=bin/wrap-status.sh
PASS=0; FAIL=0

assert_contains() { # desc haystack needle
  if grep -qF -- "$3" <<<"$2"; then PASS=$((PASS+1));
  else FAIL=$((FAIL+1)); echo "FAIL: $1"; echo "  missing: $3"; fi
}
assert_not_contains() {
  if grep -qF -- "$3" <<<"$2"; then FAIL=$((FAIL+1)); echo "FAIL: $1"; echo "  unexpected: $3";
  else PASS=$((PASS+1)); fi
}
assert_exit() { # desc actual expected
  if [ "$2" -eq "$3" ]; then PASS=$((PASS+1));
  else FAIL=$((FAIL+1)); echo "FAIL: $1 (exit $2, expected $3)"; fi
}
assert_exists() { # desc path
  if [ -e "$2" ]; then PASS=$((PASS+1));
  else FAIL=$((FAIL+1)); echo "FAIL: $1"; echo "  expected to exist: $2"; fi
}
assert_not_exists() { # desc path
  if [ -e "$2" ]; then FAIL=$((FAIL+1)); echo "FAIL: $1"; echo "  expected absent: $2";
  else PASS=$((PASS+1)); fi
}

# ── read-only before init: no dir, no baseline, hint printed, exit 0 ──────
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mkdb "$T/state.db"
add_work_session "$T/state.db" "sess-plain"
out=$(WRAP_DIR="$T/wrap" HERMES_DB="$T/state.db" $DETECTOR); rc=$?

assert_exit       "report before init exits 0"        "$rc" 0
assert_not_exists "report does not create wrap dir"   "$T/wrap"
assert_contains   "report prints init hint"           "$out" "wrap-status.sh init"
assert_contains   "report header"                     "$out" "WRAP (48h)"

# ── init: explicit first-run setup, idempotent ────────────────────────────
iout=$(WRAP_DIR="$T/wrap" HERMES_DB="$T/state.db" $DETECTOR init); irc=$?
assert_exit    "init exits 0"                 "$irc" 0
assert_exists  "init creates wrap dir"        "$T/wrap"
assert_exists  "init creates baseline marker" "$T/wrap/.enabled-at"
first_baseline=$(cat "$T/wrap/.enabled-at")
iout2=$(WRAP_DIR="$T/wrap" HERMES_DB="$T/state.db" $DETECTOR init)
assert_contains "second init says already initialized" "$iout2" "already initialized"
if [ "$(cat "$T/wrap/.enabled-at")" = "$first_baseline" ]; then PASS=$((PASS+1));
else FAIL=$((FAIL+1)); echo "FAIL: init overwrote existing baseline"; fi

# ── baseline newer than HOURS window: rollout label, no hint ──────────────
out=$(WRAP_DIR="$T/wrap" HERMES_DB="$T/state.db" WRAP_HOURS=1 $DETECTOR); rc=$?
assert_exit        "report after init exits 0"        "$rc" 0
assert_contains    "rollout window label"             "$out" "since wrap rollout"
assert_not_contains "no init hint after init"         "$out" "wrap-status.sh init"

# ── wrapped vs unwrapped standalone sessions ───────────────────────────────
W=$(mktemp -d)
mkdb "$W/state.db"
make_receipt "$W/wrap" "sess-wrapped" "pick up the parser refactor"
add_work_session "$W/state.db" "sess-wrapped"     # has receipt: not flagged
add_work_session "$W/state.db" "sess-hanging"     # real work, no receipt: flagged
add_chitchat_session "$W/state.db" "sess-chitchat"
WRAP_DIR="$W/wrap" HERMES_DB="$W/state.db" $DETECTOR init >/dev/null
backdate_baseline "$W/wrap" 72
out=$(WRAP_DIR="$W/wrap" HERMES_DB="$W/state.db" $DETECTOR); rc=$?
rm -rf "$W"

assert_exit        "mixed run exits 0"                "$rc" 0
assert_contains    "wrapped session in WRAPPED"       "$out" "sess-wrapped"
assert_contains    "receipt next line shown"          "$out" "pick up the parser refactor"
assert_contains    "hanging session flagged"          "$out" "sess-hanging"
assert_contains    "hanging tip quoted"               "$out" "real task message 1"
assert_not_contains "wrapped session not flagged"     "$out" "· sess-wrapped ·"
assert_not_contains "chitchat not flagged"            "$out" "sess-chitchat"

# ── scope exclusions: subagents and tools never flag ───────────────────────
S=$(mktemp -d)
mkdb "$S/state.db"
WRAP_DIR="$S/wrap" HERMES_DB="$S/state.db" $DETECTOR init >/dev/null
backdate_baseline "$S/wrap" 72
add_work_session "$S/state.db" "sess-scout";        add_sess "$S/state.db" "sess-scout" "subagent" "$S"
add_work_session "$S/state.db" "sess-validator";    add_sess "$S/state.db" "sess-validator" "tool" ""
add_work_session "$S/state.db" "sess-standalone";   add_sess "$S/state.db" "sess-standalone" "tui" "$S/projects/thing"

out=$(WRAP_DIR="$S/wrap" HERMES_DB="$S/state.db" $DETECTOR); rc=$?
rm -rf "$S"

assert_exit        "scoped run exits 0"                "$rc" 0
assert_not_contains "scout/subagent excluded"          "$out" "sess-scout"
assert_not_contains "validator/tool excluded"          "$out" "sess-validator"
assert_contains    "standalone session still flagged"  "$out" "sess-standalone"
assert_contains    "scope note printed"                "$out" "scope = standalone human Hermes sessions"

# ── live session never flags itself ────────────────────────────────────────
L=$(mktemp -d)
mkdb "$L/state.db"
WRAP_DIR="$L/wrap" HERMES_DB="$L/state.db" $DETECTOR init >/dev/null
backdate_baseline "$L/wrap" 72
add_work_session "$L/state.db" "sess-live"
out=$(WRAP_DIR="$L/wrap" HERMES_DB="$L/state.db" HERMES_SESSION_ID="sess-live" $DETECTOR); rc=$?
rm -rf "$L"

assert_exit        "live-session run exits 0"   "$rc" 0
assert_not_contains "live session not flagged"  "$out" "sess-live"

# ── legacy db without sessions table: standalone work still flags ──────────
G=$(mktemp -d)
mkdb_no_sessions "$G/state.db"
WRAP_DIR="$G/wrap" HERMES_DB="$G/state.db" $DETECTOR init >/dev/null
backdate_baseline "$G/wrap" 72
add_work_session "$G/state.db" "sess-legacy-hang"
out=$(WRAP_DIR="$G/wrap" HERMES_DB="$G/state.db" $DETECTOR); rc=$?
rm -rf "$G"

assert_exit        "legacy db exits 0"                   "$rc" 0
assert_contains    "legacy standalone flagged"           "$out" "sess-legacy-hang"

# ── stale receipts fall out of the recent window ───────────────────────────
R=$(mktemp -d)
mkdb "$R/state.db"
WRAP_DIR="$R/wrap" HERMES_DB="$R/state.db" $DETECTOR init >/dev/null
backdate_baseline "$R/wrap" 72
make_receipt "$R/wrap" "sess-old"
touch -d "72 hours ago" "$R/wrap/sess-old.md"
out=$(WRAP_DIR="$R/wrap" HERMES_DB="$R/state.db" $DETECTOR); rc=$?
rm -rf "$R"

assert_exit        "stale-receipt run exits 0"      "$rc" 0
assert_contains    "total receipt counted"          "$out" "receipts: 1 total"
assert_contains    "recent count is zero"           "$out" "recent=0"
assert_not_contains "stale receipt not in recent"   "$out" "· fakeproj · sess-old"

# ── receipt-only mode: missing Hermes DB still reports receipts ─────────────
N=$(mktemp -d)
make_receipt "$N/wrap" "sess-receipt-only" "resume receipt-only work"
out=$(WRAP_DIR="$N/wrap" HERMES_DB="$N/nope.db" $DETECTOR); rc=$?
rm -rf "$N"

assert_exit     "receipt-only mode exits 0"       "$rc" 0
assert_contains "receipt-only receipt reported"    "$out" "sess-receipt-only"
assert_contains "receipt-only next shown"          "$out" "resume receipt-only work"
assert_contains "receipt-only unwrapped empty"     "$out" "(none)"

# ── bad args: usage error, exit 2, writes nothing ──────────────────────────
B=$(mktemp -d)
out=$(WRAP_DIR="$B/wrap" $DETECTOR bogus 2>&1); rc=$?
assert_exit        "bogus arg exits 2"        "$rc" 2
assert_contains    "bogus arg prints usage"   "$out" "usage: wrap-status.sh"
assert_not_exists  "bogus arg writes nothing" "$B/wrap"
rm -rf "$B"

echo; echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
