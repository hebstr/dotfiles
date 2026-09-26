---
paths:
  - "**/.claude/rules/memory.md"
---

# Writing memory

Injected by `inject-rules.sh` on the session's first write to the memory store, and on any write under `~/.claude/projects/*/memory/`, which it refuses.

## One store

- Every memory file, auto-memory included, is written to `~/.claude/memory/`, a stow-managed link to `~/dotfiles/claude/.claude/memory/`. Its index is `~/.claude/memory/MEMORY.md`: update it whenever a file is added, renamed or removed. The `SessionStart` hook `inject-project-context.sh` injects that index.
- Never write under the harness path `~/.claude/projects/<cwd>/memory/`: what is there is legacy, never cited as current, and a `MEMORY.md` found there beyond the redirect stub is surfaced to the user.
- A new file's name follows the store's `<category>_<slug>.md` convention (`feedback_`, `reference_`, `project_`, `user_`) and must not collide with one the index lists: `Write` replaces an existing file with no warning and no merge, so a collision destroys the memory it lands on.
- Memory is written in English, French only when the user explicitly asks for it.
- `[[links]]` resolve to the target's filename without `.md`; the `name:` frontmatter is a human-readable title, not necessarily a slug, so link by filename.

## What goes where

- "Global or project" is a relevance tag, never a destination: both live in the one store, told apart by their `description`. Before saving, ask whether the fact would apply in a different project. Feedback on behavior or workflow almost always would.
- An absolute behavioral correction, with no exception and no context dependence, is not a feedback memory: route it by the test in `rules/claude-files.md`, which admits a new line in `CLAUDE.md` only once the user has corrected the same behavior twice. When unsure which side of that line a correction falls on, write the feedback memory: a memory can be promoted later, while a misplaced root rule reaches every session.
