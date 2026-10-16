---
paths:
  - "**/.claude/rules/memory.md"
---

# Writing memory

Injected by `inject-rules.sh` once per session, on the first write to the memory store, whether at its resolved path or through the `~/.claude/memory` link; it refuses every write through the link.

## One store

- Every memory file, auto-memory included, lives in `~/.claude/memory/`, a stow-managed link to `~/dotfiles/claude/.claude/memory/`, and is written at that resolved path. Its index is `MEMORY.md` in the same directory: update it whenever a file is added, renamed or removed. The harness loads that index at launch, `autoMemoryDirectory` in `settings.json` naming the store, and cuts it past 200 lines or 25,000 bytes. Two carriers bind earlier, at one line ceiling set below the harness's own compaction nudge: the memory branch of `inject-rules.sh`, which refuses a new entry at the write, and the `instructions-budget` prek check at a commit touching the index. Four sites hold that number, the hook, the `prek.toml` args and two `inject-rules.bats` cases, so a re-set touches all four; the pruning pass the ceiling exists to call for is what re-sets it.
- Each index line is `- <file>.md: <description>`, one line, under the section of the file's category, at or under 130 bytes including the `- <file>.md: ` prefix: that is where the two harness caps bind together (200 lines at 130 bytes is about 26,000 against the 25,000-byte cap), and the line says when to open the file, the long form staying in the file's own frontmatter `description`, which is what the recall selector reads. Decided 2026-10-04 with the pass that brought the index back to 14,839 bytes; the rationale and the standing refusals are in `~/dotfiles/.claude/TRIAGE-MEMORY.md`, section "Index lines too long". The harness's memory prompt prescribes `- [Title](file.md) — hook`: this rule governs, the link repeating the filename for about 4 KB across the index.
- A new file's name follows the store's `<category>_<slug>.md` convention (`feedback_`, `reference_`, `project_`, `user_`) and must not collide with one the index lists: `Write` replaces an existing file with no warning and no merge, so a collision destroys the memory it lands on.
- The store is ignored by pattern rather than by location, so a slug matching any glob of the dotfiles `.gitignore` is silently never versioned, existing on one machine while `MEMORY.md` indexes it. Settle it with `git check-ignore -v --no-index <path>`, where `--no-index` is load-bearing: without it git skips a path already tracked and exits 1 with no output, which reads as "not ignored" on the very file whose history is at stake (measured 2026-09-30 on `claude/.claude/rules/secrets.md`, exit 1 bare against a `**/*secret*` hit with the flag, that glob having been removed from `.gitignore` the same day). Rename the memory rather than weaken a pattern. The two globs that used to make this bite, `**/*token*` and `**/*secret*`, were removed by the user on 2026-09-30 for having no true positive in this repository, so no current glob reaches the store; the check stays because the next added pattern could.
- Memory is written in English, French only when the user explicitly asks for it.
- `[[links]]` resolve to the target's filename without `.md`; the `name:` frontmatter is a human-readable title, not necessarily a slug, so link by filename.

## What goes where

- "Global or project" is a relevance tag, never a destination: both live in the one store, told apart by their `description`. Before saving, ask whether the fact would apply in a different project. Feedback on behavior or workflow almost always would.
- Before saving anything, the admission test, in order, one test for the four categories and no separate bar per category:
  1. **Does the mechanism that fires already produce the behaviour?** A permission prompt, a `PreToolUse` deny or ask, a `Stop` gate, a hook's injected text, a rules file, a skill, a linter: if its firing already gets the behaviour right, write nothing, and say so. What carries the decision is then the changed parameter, its commit and `git blame`, per "Content" of `rules/claude-files.md`. The question is about the behaviour and never about the fact: a note that states something the mechanism does not state is still redundant when the mechanism firing produces the same action.
  2. **Is it an absolute behavioral correction, with no exception and no context dependence?** Then it is not a feedback memory: route it by the test in `rules/claude-files.md`, which admits a new line in `CLAUDE.md` only once the user has corrected the same behavior twice.
  3. **Otherwise write the memory**, under its category.
- Writing nothing is one of the three outcomes, as ordinary as the other two, and it is where an unsure case that step 1 closes lands. Unsure between step 2 and step 3, write the memory: a memory can be promoted later, while a misplaced root rule reaches every session.
