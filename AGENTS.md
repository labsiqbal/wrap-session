# wrap-session

Read ~/workspace/AGENTS.md for shared rules. For a specialist method or
delegation, read ~/workspace/.standards/agent-operations.md; load only the
selected role guide. Project scope, queue and delivery rules remain local.

Type: coding · Ownership: tool · Delivery mode: direct-PR

Start with [MAP.md](MAP.md), [context.md](context.md) and current task. /wrap is optional explicit close, not mandatory approval for ordinary persistence.

Harness-neutral skill: clean session exit. Owner gate on persist and Git actions,
then receipt at `~/.local/state/session-wrap/`. A structurally valid receipt marks a recorded close; missing or invalid after
real work means likely missed wrap.

Optional Hermes detector: `bin/wrap-status.sh`. Read-only over receipts and
Hermes state DB. Explicit `bin/wrap-status.sh init` creates receipt directory
and `.enabled-at` baseline. Subagent and tool sessions are excluded.

Tests: `bash tests/run-tests.sh` (plain Bash, no framework).

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.
