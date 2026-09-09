#!/usr/bin/env bash
# wrap-status.sh - hang-status report for /wrap receipts.
#
#   wrap-status.sh [HOURS]   read-only report (default HOURS=48)
#   wrap-status.sh init      explicit first-run init (see below)
#
# Valid receipt exists = session has a structurally complete closure record.
# No receipt after real Hermes work (post-rollout) = likely forgot /wrap.
#
# Scope: standalone human Hermes sessions.
# The UNWRAPPED check never flags:
#   - Hermes subagent/tool sessions (scouts, validators, spawned workers)
#   - the current Hermes session (it can be wrapped later)
#
# Read-only contract: the report never writes anything. Receipts are only
# read. The single file this tool ever creates is the baseline marker
# $WRAP_DIR/.enabled-at, and only through the explicit `init` subcommand.
# The marker anchors the rollout window so pre-rollout sessions are not
# flagged as hangs.
#
# Env overrides: WRAP_DIR, WRAP_HOURS, HERMES_DB, HERMES_SESSION_ID.
set -uo pipefail

WRAP_DIR="${WRAP_DIR:-$HOME/.local/state/session-wrap}"
HERMES_DB="${HERMES_DB:-$HOME/.hermes/state.db}"
BASELINE="$WRAP_DIR/.enabled-at"

usage() {
  cat >&2 <<'EOF'
usage: wrap-status.sh [HOURS]   read-only Hermes wrap-status report (default 48h)
       wrap-status.sh init      first-run init: create receipt dir + baseline marker
EOF
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  init)
    mkdir -p "$WRAP_DIR"
    if [ -e "$BASELINE" ]; then
      echo "wrap-status: already initialized (baseline $(cat "$BASELINE" 2>/dev/null) at $BASELINE)"
    else
      date +%s > "$BASELINE"
      echo "wrap-status: initialized $WRAP_DIR (baseline $(cat "$BASELINE") at $BASELINE)"
    fi
    exit 0
    ;;
esac

HOURS="${1:-${WRAP_HOURS:-48}}"
case "$HOURS" in
  ''|*[!0-9.]*)
    usage
    exit 2
    ;;
esac

CUTOFF=$(date -d "$HOURS hours ago" +%s 2>/dev/null || python3 -c "import time; print(int(time.time()-$HOURS*3600))")

BASELINE_TS=0
if [ -e "$BASELINE" ]; then
  BASELINE_TS=$(cat "$BASELINE" 2>/dev/null || echo 0)
fi
WINDOW_LABEL="${HOURS}h"
if [ "$BASELINE_TS" -gt "$CUTOFF" ] 2>/dev/null; then
  CUTOFF="$BASELINE_TS"
  WINDOW_LABEL="${HOURS}h, since wrap rollout"
fi

python3 - "$WRAP_DIR" "$HERMES_DB" "$CUTOFF" "$WINDOW_LABEL" "${HERMES_SESSION_ID:-}" "$BASELINE_TS" <<'PY'
import re, sqlite3, sys, time
from datetime import datetime
from pathlib import Path

wrap_dir = Path(sys.argv[1])
db = Path(sys.argv[2])
cutoff = float(sys.argv[3])
hours = sys.argv[4]
active_session = sys.argv[5]
baseline_ts = float(sys.argv[6] or 0)

def parse_front(text: str) -> dict:
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not m:
        return {}
    out = {}
    for line in m.group(1).splitlines():
        if ":" not in line:
            continue
        k, v = line.split(":", 1)
        out[k.strip()] = v.strip().strip('"').strip("'")
    return out

def receipt_error(meta, text):
    required = ("session_id", "harness", "source", "cwd", "project", "wrapped_at", "next")
    missing = [key for key in required if not meta.get(key) or meta[key].lower() in ("null", "~")]
    if missing:
        return "missing fields: " + ", ".join(missing)
    if not Path(meta["cwd"]).is_absolute():
        return "cwd must be absolute"
    try:
        if not re.search(r"[Tt ]\d{2}:\d{2}", meta["wrapped_at"]):
            return "wrapped_at must include a time"
        datetime.fromisoformat(meta["wrapped_at"].replace("Z", "+00:00"))
    except ValueError:
        return "wrapped_at must be an ISO timestamp"
    for heading in ("Done", "Decisions", "Written", "Git", "Deferred", "Next"):
        section = re.search(r"^## " + heading + r"\s*\n(.*?)(?=^## |\Z)", text, re.M | re.S)
        if not section or not section.group(1).strip():
            return "missing or empty section: " + heading
    return None

receipts = []
invalid = []
if wrap_dir.exists():
    for fp in sorted(wrap_dir.glob("*.md")):
        try:
            modified = fp.stat().st_mtime
            text = fp.read_text(errors="replace")
        except Exception:
            invalid.append((fp.name, "cannot read receipt"))
            continue
        meta = parse_front(text)
        error = receipt_error(meta, text)
        if error:
            invalid.append((fp.name, error))
            continue
        meta["_path"] = str(fp)
        meta["_mtime"] = modified
        receipts.append(meta)

receipts.sort(key=lambda r: r["_mtime"], reverse=True)
known = {r.get("session_id") for r in receipts if r.get("session_id")}
recent = [r for r in receipts if r["_mtime"] >= cutoff]

print(f"WRAP ({hours})")
print(f"  receipts: {len(receipts)} total · recent={len(recent)}")
if baseline_ts <= 0:
    print("  hint: no baseline marker; run 'wrap-status.sh init' to anchor the rollout window")

if invalid:
    print("INVALID RECEIPTS (not counted as closed)")
    for name, reason in invalid:
        print(f"• {name}: {reason}")

if recent:
    print("WRAPPED (recent)")
    for r in recent[:12]:
        when = time.strftime("%Y-%m-%d %H:%M", time.localtime(r["_mtime"]))
        print(f"• {when} · {r.get('harness','?')} · {r.get('project','?')} · {r.get('session_id')}")
        if r.get("next"):
            print(f"    next: {r['next']}")
else:
    print("WRAPPED (recent)")
    print("(none)")

# Standalone Hermes sessions with real user work and no receipt → likely forgot /wrap
unwrapped = []
if db.exists():
    try:
        con = sqlite3.connect(f"file:{db}?mode=ro", uri=True, timeout=3)
        have_sessions = con.execute(
            "SELECT 1 FROM sqlite_master WHERE type='table' AND name='sessions'"
        ).fetchone() is not None
        sess_meta = {}
        if have_sessions:
            for sid, source in con.execute("SELECT id, source FROM sessions"):
                sess_meta[sid] = source or ""
        rows = con.execute(
            "SELECT session_id, MAX(timestamp) mt, COUNT(*) n FROM messages "
            "WHERE timestamp >= ? GROUP BY session_id",
            (cutoff,),
        ).fetchall()
        for sid, mt, n in rows:
            if sid in known:
                continue
            if active_session and sid == active_session:
                continue  # current live session; wrap later
            source = sess_meta.get(sid, "")
            if source in ("subagent", "tool"):
                continue  # spawned subagents / scouts / validators; orchestrated elsewhere
            users = con.execute(
                "SELECT content FROM messages WHERE session_id=? AND role='user' "
                "AND content IS NOT NULL AND content != '' "
                "ORDER BY timestamp LIMIT 3",
                (sid,),
            ).fetchall()
            msgs = [str(u[0]).strip() for u in users if u[0] and not str(u[0]).startswith("{")]
            if not msgs:
                continue  # cron/system only
            # skip tiny chitchat
            if n < 6 and all(len(m) < 40 for m in msgs):
                continue
            unwrapped.append((mt, sid, n, msgs[0][:70]))
        con.close()
    except Exception as e:
        print(f"UNWRAPPED hermes: error reading state.db ({e})")
        unwrapped = None

if unwrapped is not None:
    print("UNWRAPPED hermes (no receipt after real work)")
    if not unwrapped:
        print("(none)")
    else:
        for mt, sid, n, tip in sorted(unwrapped, key=lambda t: -t[0])[:20]:
            when = time.strftime("%Y-%m-%d %H:%M", time.localtime(mt))
            print(f"• {when} · {sid} · {n} msgs · \"{tip}\"")
        print("  note: Hermes sessions are auto-checked; receipts report completed sessions")
        print("  note: scope = standalone human Hermes sessions; subagents and tools are excluded")
        print("  note: unwrapped = likely forgot /wrap, not intentional hang")

sys.exit(1 if invalid or unwrapped is None else 0)
PY
