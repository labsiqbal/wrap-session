# wrap-session

Type: coding · Ownership: tool · Delivery mode: local-only

Harness-neutral skill: clean session exit. Owner gate on persist and Git actions,
then receipt at `~/.local/state/session-wrap/`. Receipt present means clean
close; missing after real work means likely missed wrap.

Optional Hermes detector: `bin/wrap-status.sh`. Read-only over receipts and
Hermes state DB. Explicit `bin/wrap-status.sh init` creates receipt directory
and `.enabled-at` baseline. Subagent and tool sessions are excluded.

Tests: `bash tests/run-tests.sh` (plain Bash, no framework).

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.
