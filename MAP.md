# Map - wrap

## Purpose

Session close with approved persistence and a durable receipt.

## Routing

| Need | Read |
|---|---|
| Skill procedure | [SKILL.md](SKILL.md) |
| Project rules | [AGENTS.md](AGENTS.md) |
| Hang status (read) | [bin/wrap-status.sh](bin/wrap-status.sh) |
| Detector tests | [tests/run-tests.sh](tests/run-tests.sh) |

## Working artifacts

| Need | Read |
|---|---|
| Work queue | [backlog.md](backlog.md) |

## Layout

```text
SKILL.md            Procedure: gate → persist → receipt; hang semantics; scope
AGENTS.md           Type, ownership, Standards pointer
bin/wrap-status.sh  Detector: read-only hang report; `init` for first-run baseline
tests/              Plain-bash test suite (fixtures.sh, run-tests.sh)
```

## Boundaries

- Receipt path: `~/.local/state/session-wrap/<session_id>.md` - valid structure = recorded close; missing or invalid after real work = likely missed wrap.
- Receipts live outside the repository.
- Skill is harness-neutral. Optional detector reads Hermes sessions and excludes `subagent` and `tool` sources.
- Detector writes nothing except `.enabled-at`, and only via `bin/wrap-status.sh init`.
- Canonical source: this repository. NUC Codex/Claude `wrap` resolve through
  `~/.agents/skills/wrap`; verify links before install maintenance.
- Hermes `wrap-session` uses its existing installed directory.

## Load on demand

- `.git/`
