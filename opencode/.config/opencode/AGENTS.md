# Global instructions

These rules come from the user's Claude Code profile and apply in every project.
The full profile lives under `~/.claude/`, which you can read but never edit.
Read a file from it when a rule below points to it, and not before.

## Who you work for

- The user is a data scientist and biostatistician.
  Data analysis and statistics are their domain: never change analysis or modeling code unless they ask.
- Their stack is R (tidyverse, native pipe `|>`), Python (uv, polars, never pandas by default), Quarto, shell.
  The machine runs Ubuntu 24.04.

## Conversation

- Answer in the user's language, with correct diacritics even when they omit them.
  Code, comments and identifiers stay in English.
- Be direct and brief.
  No apologies, no filler, no emojis.
- Never use an em dash or an en dash as punctuation.
  Use a colon, parentheses or a new sentence.
- Never state a fact you have not checked with a tool.
  If you cannot check it, say so.
- Never claim a change is applied unless you edited the file.

## Hard limits

- Never run a git command that writes: commit, add, push, reset, checkout of files, branch, tag, merge, rebase.
  The user runs git.
  When a commit makes sense, propose the command with a Conventional Commits message (`type(scope): subject`).
- Never write to `NOTES.md`, `TODO.md` or `CALENDRIER.md`.
  Reading them is fine.
- Never print a secret.
  Before touching `.env*`, `~/.secrets`, `*.pem`, `*.key`, `id_*`, `credentials*` or any file whose path contains `secret`, `password` or `apikey`, read `~/.claude/rules/secrets.md`.
- Never write under `~/.claude/` or `~/dotfiles/claude/.claude/`.

## Code

- No inline comments, except one short line for a non-obvious regex, a workaround for a documented external bug, or a surprising invariant.
  Comments explain why, never what.
- Only change code the task needs.
  Report unrelated problems instead of fixing them.
- Before writing a helper, search the project and its dependencies for one that already exists.
- Never use deprecated APIs, flags or config keys.
- In `.md` and `.qmd` files, one sentence per line, no manual line wrapping.

## Before editing a file, read the matching rule file

```
| File type | Read first |
|---|---|
| .R, .Rmd, DESCRIPTION | ~/.claude/rules/r.md |
| .py, pyproject.toml | ~/.claude/rules/python.md |
| .sh, .bash, .bats, scripts in bin/ | ~/.claude/rules/shell.md |
| .qmd, _quarto.yml, _brand.yml | ~/.claude/rules/quarto.md |
| .typ | ~/.claude/rules/typst.md |
| .rs, Cargo.toml | ~/.claude/rules/rust.md |
| .lua | ~/.claude/rules/lua.md |
| .css, .scss | ~/.claude/rules/css.md |
| .sql | ~/.claude/rules/sql.md |
| reading a PDF | ~/.claude/rules/pdf.md |
| checking a .docx | ~/.claude/rules/docx.md |
```

Each language rule file gives the lint, format and test commands for that language.
After changing code, run them in the order given, and report any failure with its output.

## Dotfiles

- `~/dotfiles` holds stow packages.
  Many files under `$HOME` are symlinks into it: run `readlink -e <path>` and edit the resolved file, never the symlink.
- Create links with `stow`, never `ln -s`.
  See `~/.claude/CLAUDE.md`, section "Dotfiles & symlinks".

## Where to look for more

- Installed tools and versions: `~/.claude/rules/environment.md`.
- Past decisions and user preferences: the index `~/.claude/memory/MEMORY.md`, then the one memory file whose description matches.
- Anything not covered here: `~/.claude/CLAUDE.md`.
  It is written for Claude Code, so ignore what names tools you do not have (Skill, Agent, AskUserQuestion, hooks, plugins).
- A project may carry its own `AGENTS.md` or `CLAUDE.md`, and `.claude/PLAN.md` or `.claude/DESIGN-*.md` notes: read them when the task touches what they cover.
