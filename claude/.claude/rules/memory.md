---
paths:
  - "**/.claude/rules/memory.md"
---

# Writing memory

Injected by `inject-rules.sh` once per session, on the first write to the memory store, under `~/.claude/projects/*/memory/` or through the `~/.claude/memory` link; it refuses every write to the last two.

## One store

- Every memory file, auto-memory included, lives in `~/.claude/memory/`, a stow-managed link to `~/dotfiles/claude/.claude/memory/`, and is written at that resolved path. Its index is `MEMORY.md` in the same directory: update it whenever a file is added, renamed or removed. The harness loads that index at launch, `autoMemoryDirectory` in `settings.json` naming the store, and cuts it past 200 lines or 25,000 bytes; the `instructions-budget` prek check fails a commit that crosses either.
- Each index line is `- <file>.md: <description>`, one line, under the section of the file's category, at or under 130 bytes including the `- <file>.md: ` prefix: that is where the two harness caps bind together (200 lines at 130 bytes is about 26,000 against the 25,000-byte cap), and the line says when to open the file, the long form staying in the file's own frontmatter `description`, which is what the recall selector reads. Decided 2026-10-04 with the pass that brought the index back to 14,839 bytes; the rationale and the standing refusals are in `~/dotfiles/.claude/TRIAGE-MEMORY.md`, section "Lignes d'index trop longues". The harness's memory prompt prescribes `- [Title](file.md) — hook`: this rule governs, the link repeating the filename for about 4 KB across the index.
- Never write under the harness path `~/.claude/projects/<cwd>/memory/`: what is there is legacy, never cited as current, and a `MEMORY.md` found there beyond the redirect stub is surfaced to the user.
- A new file's name follows the store's `<category>_<slug>.md` convention (`feedback_`, `reference_`, `project_`, `user_`) and must not collide with one the index lists: `Write` replaces an existing file with no warning and no merge, so a collision destroys the memory it lands on.
- The store is ignored by pattern rather than by location, so a slug matching any glob of the dotfiles `.gitignore` is silently never versioned, existing on one machine while `MEMORY.md` indexes it. Settle it with `git check-ignore -v --no-index <path>`, where `--no-index` is load-bearing: without it git skips a path already tracked and exits 1 with no output, which reads as "not ignored" on the very file whose history is at stake (measured 2026-09-30 on `claude/.claude/rules/secrets.md`, exit 1 bare against a `**/*secret*` hit with the flag, that glob having been removed from `.gitignore` the same day). Rename the memory rather than weaken a pattern. The two globs that used to make this bite, `**/*token*` and `**/*secret*`, were removed by the user on 2026-09-30 for having no true positive in this repository, so no current glob reaches the store; the check stays because the next added pattern could.
- Memory is written in English, French only when the user explicitly asks for it.
- `[[links]]` resolve to the target's filename without `.md`; the `name:` frontmatter is a human-readable title, not necessarily a slug, so link by filename.

## What goes where

- "Global or project" is a relevance tag, never a destination: both live in the one store, told apart by their `description`. Before saving, ask whether the fact would apply in a different project. Feedback on behavior or workflow almost always would.
- An absolute behavioral correction, with no exception and no context dependence, is not a feedback memory: route it by the test in `rules/claude-files.md`, which admits a new line in `CLAUDE.md` only once the user has corrected the same behavior twice. When unsure which side of that line a correction falls on, write the feedback memory: a memory can be promoted later, while a misplaced root rule reaches every session.
