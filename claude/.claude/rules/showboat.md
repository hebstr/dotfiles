# showboat trace documents

On-demand reference for using showboat to record reproducible traces. Load when bootstrapping tools, installing packages, or making persistent env/system changes (see trigger in CLAUDE.md).

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
