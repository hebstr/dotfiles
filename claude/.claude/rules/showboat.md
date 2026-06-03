# showboat trace documents

On-demand reference for using showboat to record reproducible traces. Load when bootstrapping tools, installing packages, or making persistent env/system changes (see trigger in CLAUDE.md).

## Qualities of a good trace

- **Minimal**: every entry earns its place. Capture the commands that change system state and their output, not exploratory dead ends or noise.
- **Replayable**: each `exec` block must re-run cleanly from the document alone (`showboat extract` then replay, or `showboat verify` to re-run and diff). No reliance on un-recorded prior state.
- **Self-explaining**: a `note` before each step states the why (what the step is for), so a reader reproducing it later understands intent, not just keystrokes.

## Output path

- `<project>/_meta/notes/<task-name>.md` for project-scoped tasks
- `~/dotfiles/_meta/notes/` for system-level tasks

## Key commands

Run `showboat --help` for the full surface.

- `showboat init <file> <title>`: create document
- `showboat note <file> <text>`: add prose (accepts stdin)
- `showboat exec <file> <lang> <code>`: run code and capture output
- `showboat image <file> <path>`: embed an image
- `showboat extract <file>`: extract code blocks for replay
- `showboat pop <file>`: remove last entry
- `showboat verify <file>`: re-run all exec blocks and diff outputs
