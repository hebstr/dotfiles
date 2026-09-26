---
paths:
  - "**/.claude/rules/showboat.md"
---

# showboat trace documents

On-demand reference for using showboat to record reproducible traces, injected by `inject-rules.sh` with `install.md` on an install, `stow` or `systemctl` command. It applies to installing packages (`apt`, `uv tool install`, `pip install` outside a project venv), bootstrapping tools (`stow`, `claude plugin install`, MCP registration), persistent environment changes (shell rc edits, systemd units) and system upgrades; not to source-code edits, tests, ad-hoc analysis or narrative documentation.

## Qualities of a good trace

- **Minimal**: every entry earns its place. Capture the commands that change system state and their output, not exploratory dead ends or noise.
- **Replayable**: each `exec` block must re-run cleanly from the document alone (`showboat extract` then replay, or `showboat verify` to re-run and diff). No reliance on un-recorded prior state.
- **Self-explaining**: a `note` before each step states the why (what the step is for), so a reader reproducing it later understands intent, not just keystrokes.

## Non-replayable steps

A step that must never re-run on `verify` (destructive, `sudo`, hardware-dependent) goes inside a `note` as a tilde fence (`~~~text`), with the observed output pasted beneath the command.
Never use a backtick fence for it, with or without a language tag: showboat 0.6.1 parses every backtick fence as an exec block, including one written inside a `note`, and `verify` runs it.
Measured 2026-09-13 on a disk reformatting trace, where `verify` launched the recorded `wipefs` and `mkfs` calls and only a missing `sudo` password stopped them; tilde fences and indented blocks are ignored by the parser.
Before any `verify`, count the exec blocks with `showboat extract <file> | rg -c '^showboat exec'` and run `verify` only when the count matches the `exec` calls made.

## Output path

- `<project>/_meta/notes/<task-name>.md` for project-scoped tasks
- `~/dotfiles/_meta/notes/` for system-level tasks

## Key commands

Run `showboat --help` for the full surface.

- `showboat init <file> <title>`: create document
- `showboat note <file> <text>`: add prose (accepts stdin)
- `showboat exec <file> <lang> <code>`: run code and capture output
- `showboat image <file> <path>`: embed an image
- `showboat extract <file>`: print the sequence of showboat commands that rebuilds the document
- `showboat pop <file>`: remove last entry
- `showboat verify <file>`: re-run every backtick-fenced code block, notes included, and diff outputs
