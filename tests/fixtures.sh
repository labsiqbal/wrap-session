# Test fixtures for bin/wrap-status.sh. Sourced by run-tests.sh.
# Fake receipt dirs and fake Hermes state.db files, all under mktemp -d roots.
# The detector itself requires python3, so fixtures build SQLite dbs with it.

now() { python3 -c 'import time; print(int(time.time()))'; }

hours_ago() { # hours_ago N -> epoch N hours in the past
  python3 -c "import time; print(int(time.time()-$1*3600))"
}

# backdate_baseline WRAP_DIR HOURS - pretend the rollout started HOURS ago,
# so fixture sessions (2h old) land after the rollout and can be flagged.
backdate_baseline() { hours_ago "$2" > "$1/.enabled-at"; }

# make_receipt DIR SESSION_ID [NEXT] - a minimal valid wrap receipt
make_receipt() {
  local dir=$1 sid=$2 next=${3:-}
  mkdir -p "$dir"
  {
    printf -- '---\n'
    printf 'session_id: %s\n' "$sid"
    printf 'harness: hermes\n'
    printf 'source: cli\n'
    printf 'cwd: /tmp/fake\n'
    printf 'project: fakeproj\n'
    printf 'wrapped_at: 2026-08-17T00:00:00\n'
    printf 'next: %s\n' "$next"
    printf -- '---\n\n'
    printf '# Wrap - fakeproj\n'
  } > "$dir/$sid.md"
}

# mkdb DB_PATH - empty Hermes-shaped db (messages + sessions, minimal columns)
mkdb() {
  python3 - "$1" <<'PY'
import sqlite3, sys
con = sqlite3.connect(sys.argv[1])
con.execute("CREATE TABLE sessions (id TEXT PRIMARY KEY, source TEXT NOT NULL DEFAULT 'cli', cwd TEXT)")
con.execute("""CREATE TABLE messages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id TEXT NOT NULL,
  role TEXT NOT NULL,
  content TEXT,
  timestamp REAL NOT NULL)""")
con.commit(); con.close()
PY
}

# mkdb_no_sessions DB_PATH - legacy db without the sessions table
mkdb_no_sessions() {
  python3 - "$1" <<'PY'
import sqlite3, sys
con = sqlite3.connect(sys.argv[1])
con.execute("""CREATE TABLE messages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id TEXT NOT NULL,
  role TEXT NOT NULL,
  content TEXT,
  timestamp REAL NOT NULL)""")
con.commit(); con.close()
PY
}

# add_sess DB SID SOURCE CWD
add_sess() {
  python3 - "$1" "$2" "$3" "$4" <<'PY'
import sqlite3, sys
db, sid, source, cwd = sys.argv[1:5]
con = sqlite3.connect(db)
con.execute("INSERT OR REPLACE INTO sessions (id, source, cwd) VALUES (?,?,?)",
            (sid, source, cwd or None))
con.commit(); con.close()
PY
}

# add_msg DB SID ROLE CONTENT TIMESTAMP
add_msg() {
  python3 - "$1" "$2" "$3" "$4" "$5" <<'PY'
import sqlite3, sys
db, sid, role, content, ts = sys.argv[1:6]
con = sqlite3.connect(db)
con.execute("INSERT INTO messages (session_id, role, content, timestamp) VALUES (?,?,?,?)",
            (sid, role, content, float(ts)))
con.commit(); con.close()
PY
}

# add_work_session DB SID - a session with real user work (6+ substantial msgs)
# Timestamps increase per message so ORDER BY timestamp is deterministic.
add_work_session() {
  local db=$1 sid=$2 ts i
  ts=$(hours_ago 2)
  for i in 1 2 3 4 5 6; do
    add_msg "$db" "$sid" user "real task message $i: please refactor the parser module now" "$((ts + i * 2))"
    add_msg "$db" "$sid" assistant "working on it, step $i" "$((ts + i * 2 + 1))"
  done
}

# add_chitchat_session DB SID - tiny chitchat, below the real-work bar
add_chitchat_session() {
  local db=$1 sid=$2 ts
  ts=$(hours_ago 2)
  add_msg "$db" "$sid" user "hi" "$ts"
  add_msg "$db" "$sid" assistant "hello" "$((ts + 1))"
  add_msg "$db" "$sid" user "thanks" "$((ts + 2))"
}
