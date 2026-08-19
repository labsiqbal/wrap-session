# wrap

Type: coding · Ownership: tool · Delivery mode: local-only

Lab-born skill: clean session exit. Owner gate on persist/git decisions,
then a wrap receipt at `~/.local/state/session-wrap/`. Receipt present =
closed; missing after real work = forgot `/wrap`. Source of truth here;
installed copies in `~/.claude/skills`, `~/.hermes/skills`, `~/.codex/skills`.
Follow the Standards: `~/workspace/.standards/`.

Detector lives here: `bin/wrap-status.sh`. Read-only over receipts; the only
write is the `.enabled-at` baseline via explicit `bin/wrap-status.sh init`.
Scope: standalone human-agent sessions across harnesses; subagents, scouts,
and validators are excluded.

Tests: `bash tests/run-tests.sh` (plain bash, no framework).

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.
