#!/usr/bin/env bash
# wrap-status.sh - hang-status report for /wrap receipts.
#
#   wrap-status.sh [HOURS]   read-only report (default HOURS=48)
#   wrap-status.sh init      explicit first-run init (see below)
#
# Receipt exists = session closed cleanly.
# No receipt after real Hermes work (post-rollout) = likely forgot /wrap.
#
# Scope: standalone human-agent sessions outside the private orchestrator.
# The UNWRAPPED check never flags:
#   - the firstmate orchestrator primary (sessions with cwd under FIRSTMATE_HOME)
#   - /firstmate requests forwarded through Hermes (first user message is a
#     /firstmate command; the work runs in firstmate, not in that session)
#   - Hermes subagent/tool sessions (scouts, validators, spawned workers)
#   - Orca workers (sessions with cwd under ORCA_WORK_ROOT)
#
# Read-only contract: the report never writes anything. Receipts are only
# read. The single file this tool ever creates is the baseline marker
# $WRAP_DIR/.enabled-at, and only through the explicit `init` subcommand.
# The marker anchors the rollout window so pre-rollout sessions are not
# flagged as hangs.
#
# Env overrides: WRAP_DIR, WRAP_HOURS, HERMES_DB, FIRSTMATE_HOME,
# ORCA_WORK_ROOT (set FIRSTMATE_HOME/ORCA_WORK_ROOT empty to disable that
# exclusion).
set -uo pipefail

WRAP_DIR="${WRAP_DIR:-$HOME/.local/state/session-wrap}"
HERMES_DB="${HERMES_DB:-$HOME/.hermes/state.db}"
FIRSTMATE_HOME="${FIRSTMATE_HOME:-$HOME/firstmate}"
ORCA_WORK_ROOT="${ORCA_WORK_ROOT:-$HOME/orca/workspaces}"
BASELINE="$WRAP_DIR/.enabled-at"

usage() {
  cat >&2 <<'EOF'
usage: wrap-status.sh [HOURS]   read-only hang-status report (default 48h)
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

python3 - "$WRAP_DIR" "$HERMES_DB" "$CUTOFF" "$WINDOW_LABEL" "${HERMES_SESSION_ID:-}" "$FIRSTMATE_HOME" "$ORCA_WORK_ROOT" "$BASELINE_TS" <<'PY'
import os, re, sqlite3, sys, time
from pathlib import Path

wrap_dir = Path(sys.argv[1])
db = Path(sys.argv[2])
cutoff = float(sys.argv[3])
hours = sys.argv[4]
active_session = sys.argv[5]

def norm_root(raw: str) -> str:
    raw = (raw or "").strip()
    if not raw:
        return ""
    return os.path.normpath(os.path.expanduser(raw))

fm_home = norm_root(sys.argv[6])
orca_root = norm_root(sys.argv[7])
baseline_ts = float(sys.argv[8] or 0)

def under(path: str, root: str) -> bool:
    return bool(root) and (path == root or path.startswith(root + os.sep))

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

receipts = []
if wrap_dir.exists():
    for fp in sorted(wrap_dir.glob("*.md"), key=lambda p: p.stat().st_mtime, reverse=True):
        try:
            text = fp.read_text(errors="replace")
        except Exception:
            continue
        meta = parse_front(text)
        meta["_path"] = str(fp)
        meta["_mtime"] = fp.stat().st_mtime
        meta["session_id"] = meta.get("session_id") or fp.stem
        receipts.append(meta)

known = {r.get("session_id") for r in receipts if r.get("session_id")}
recent = [r for r in receipts if r["_mtime"] >= cutoff]

print(f"WRAP ({hours})")
print(f"  receipts: {len(receipts)} total · recent={len(recent)}")
if baseline_ts <= 0:
    print("  hint: no baseline marker; run 'wrap-status.sh init' to anchor the rollout window")

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
            for sid, source, cwd in con.execute("SELECT id, source, cwd FROM sessions"):
                sess_meta[sid] = (source or "", cwd or "")
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
            source, cwd = sess_meta.get(sid, ("", ""))
            if source in ("subagent", "tool"):
                continue  # spawned subagents / scouts / validators; orchestrated elsewhere
            cw = os.path.normpath(cwd) if cwd else ""
            if under(cw, fm_home):
                continue  # firstmate orchestrator primary; never wraps
            if under(cw, orca_root):
                continue  # Orca workers; managed by the orchestrator
            users = con.execute(
                "SELECT content FROM messages WHERE session_id=? AND role='user' "
                "AND content IS NOT NULL AND content != '' "
                "ORDER BY timestamp LIMIT 3",
                (sid,),
            ).fetchall()
            msgs = [str(u[0]).strip() for u in users if u[0] and not str(u[0]).startswith("{")]
            if not msgs:
                continue  # cron/system only
            if msgs[0].lstrip().lower().startswith("/firstmate"):
                continue  # /firstmate request: forwarded to the orchestrator, not real work here
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
        print("  note: other harnesses need a /wrap receipt to appear; Hermes is auto-checked")
        print("  note: scope = standalone sessions; firstmate primary, /firstmate requests,")
        print("        subagents/scouts/validators, and Orca workers are excluded")
        print("  note: unwrapped = likely forgot /wrap, not intentional hang")
PY
