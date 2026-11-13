# wrap-session

Source of the harness-neutral `wrap-session` skill ([SKILL.md](SKILL.md)) and its
optional read-only Hermes detector (`bin/wrap-status.sh`). Usage, receipt format
and detector exit codes: [README.md](README.md). Queue: [backlog.md](backlog.md).
Shared rules: [Work rules](../../../.standards/work-rules.md).

Delivery: direct-PR to `labsiqbal/wrap-session`.

## Gotchas

- This checkout is live: NUC Codex and Claude load `wrap` through the
  `~/.agents/skills/wrap` symlink. Hermes `wrap-session` resolves to its own
  package under `~/.local/share/agent-skills/packages/hermes/`, which this source
  does not update.
- Receipts live in `~/.local/state/session-wrap/`, outside this repository.
- Installing the skill and running `bin/wrap-status.sh init` (it writes the
  `.enabled-at` baseline) each need owner approval.
- A change to receipt fields or close semantics updates the fixtures in
  `tests/`; check with `bash tests/run-tests.sh`.
