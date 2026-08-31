# wrap-session

Hermes-only skill for closing a working session with an owner-approved durable record. It is manually invoked: Hermes does not invoke it on its own.

## Trigger

Use any clear manual request:

- `/wrap-session`
- `wrap session`
- `close session`
- `end session`
- `create a durable handoff before leaving`

Use it after work that leaves code, decisions, documents, operational changes, or unfinished work for a later session. Skip it for chitchat with nothing durable.

## Install

Copy this skill directory into Hermes under its public name:

```bash
cp -R /path/to/wrap-session ~/.hermes/skills/wrap-session
```

Use the directory that contains `SKILL.md`, `bin/`, and `tests/`. No project-specific layout is required after installation.

## Usage contract

`/wrap-session` first inspects session residue and drafts a wrap plan. It does not write persistent files or run Git actions before owner approval.

Owner approves, edits, selects, or cancels proposed:

1. decision, deferred-work, and memory writes;
2. Git action: leave changes, commit, or commit and push;
3. wrap-plan edits.

`all`, selected numbers, free-text edits, and `cancel` are valid responses. `cancel` writes nothing.

After approved actions complete, it writes one receipt per session at:

```text
~/.local/state/session-wrap/<session_id>.md
```

Receipt records completed work, decisions, written artifacts, Git state, deferred work, and one next action. Re-wrapping same session ID replaces that receipt.

## Optional detector

From installed skill directory, check recent receipts and likely unwrapped standalone Hermes sessions:

```bash
bin/wrap-status.sh
```

Initialize its rollout baseline once, explicitly:

```bash
bin/wrap-status.sh init
```

Status is read-only. `init` creates receipt directory and `.enabled-at` baseline marker. Environment overrides are available for `WRAP_DIR`, `WRAP_HOURS`, and `HERMES_DB`.

## Test

```bash
bash tests/run-tests.sh
```

Plain Bash tests; no test framework dependency.

## License

MIT. See [LICENSE](LICENSE).
