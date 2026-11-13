# Context — session close source and detector

## Inputs

- [Rules](AGENTS.md), [Map](MAP.md), [backlog](backlog.md).
- [Canonical skill](SKILL.md), [detector](bin/wrap-status.sh), [tests](tests/run-tests.sh).
- For use: actual session/task state and owner-approved persistence/Git choices.

## Process

1. Select source maintenance or use of the existing wrap skill. Do not turn this
   contract into automatic wrap execution during unrelated documentation work.
2. Source edits trace receipt fields and close semantics into detector fixtures.
3. A real close follows skill's draft/owner gate/persist/receipt sequence; receiving
   project retains decisions and queue. Receipt is evidence, not a second backlog.
4. Detector reports read-only; `init` creates a baseline and is a separate write.

## Outputs

Approved source/check changes here; real close receipts live at the skill's existing
`~/.local/state/session-wrap/<session_id>.md` location, not in this repository.

## Verification

For source changes run `bash tests/run-tests.sh` in isolated fixture environment.
Check missing/invalid receipts, subagent/tool exclusions and unavailable DB behavior.
A valid receipt is recorded close, not proof of deployment or writer release.

## Human check

Owner chooses persistence and Git actions for each close. Installing the skill or
initializing detector is separate authority; no default commit/push or runtime mutation.
