# MAP · wrap

## What

Clean session-exit skill: owner gate on persist/git, then write a wrap receipt under `~/.local/state/session-wrap/`.

## Open first

| Need | Open |
|---|---|
| Skill procedure | [SKILL.md](SKILL.md) |
| Project rules | [AGENTS.md](AGENTS.md) |
| Hang status (read) | [bin/wrap-status.sh](bin/wrap-status.sh) |
| Detector tests | `tests/run-tests.sh` |

## Layout

```text
SKILL.md            Procedure: gate → persist → receipt; hang semantics; scope
AGENTS.md           Type, ownership, Standards pointer
bin/wrap-status.sh  Detector: read-only hang report; `init` for first-run baseline
tests/              Plain-bash test suite (fixtures.sh, run-tests.sh)
```

## Edges

- Receipt path: `~/.local/state/session-wrap/<session_id>.md` — present = closed; missing after real work = hang.
- Receipts live outside the repo; this tree is skill source of truth only.
- Detector scope: standalone human-agent sessions. Firstmate primary, `/firstmate` requests, Orca workers, subagents/scouts/validators are excluded (see SKILL.md Scope).
- Detector writes nothing except the `.enabled-at` baseline marker, only via `bin/wrap-status.sh init`.
- Installed copies: `~/.claude/skills`, `~/.hermes/skills`, `~/.codex/skills` (re-sync from this repo on install).

## Ignore by default

- `.git/`
