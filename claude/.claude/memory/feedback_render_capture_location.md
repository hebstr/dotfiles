---
name: Rendered-output screenshots go under the project's .claude/, never the repo root
description: Verify a rendered document or page by capturing it with headless chromium, and write the PNG to a `.claude/shots/` directory in the project rather than the repo root, even transiently
metadata:
  type: feedback
---

When checking how a document or page actually renders, capture it and look at it rather than asserting from the source. The tool is the chromium snap, headless:

```
chromium --headless=new --disable-gpu --hide-scrollbars \
  --window-size=1400,4200 --screenshot=.claude/shots/<name>.png "file://$PWD/<file>.html"
```

`--window-size` sets the captured height, so a tall value captures the whole page in one pass; crop with PIL to read a specific region. The `--hide-scrollbars` flag keeps the scrollbar out of the measured width.

**Write the PNG under the project's `.claude/` (e.g. `.claude/shots/`), never the repo root, even for a file deleted seconds later.** The user stated this preference on 2026-08-31 (eds-prise) after seeing `_shot.png` appear at the root of a working tree they were actively editing.

**Why:** a repo root is the user's workspace and their `git status` view; a transient artefact there is noise in a diff they are reading, and the window during which it exists is not under their control. A project `.claude/` is already gitignored in these projects, so nothing leaks into a commit.

**How to apply:** `mkdir -p .claude/shots` and point `--screenshot` straight at it. The chromium snap writes there without trouble: `.claude/` inside a project under `~/Documents` is not blocked, unlike a dot-directory sitting directly under `$HOME` (the caveat `rules/environment.md` records for the probe-file case). Do not route through `/tmp`: a snap gets a private `/tmp`, so the file lands somewhere unreadable. Delete the captures when the check is done, or leave them under `.claude/` if they document something.

Related: [[feedback_verify_quarto_theming.md]] covers the stronger case where a screenshot is not enough and computed styles must be measured; [[feedback_verify_before_claiming]] is the general rule this serves.
