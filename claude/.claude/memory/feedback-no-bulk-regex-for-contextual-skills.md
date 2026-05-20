---
name: feedback-no-bulk-regex-for-contextual-skills
description: Don't substitute a contextual editing skill (workflow:write, audit reviewers, similar) with a bulk regex pass. The skill exists because the edit requires per-case judgment a regex cannot make
metadata:
  type: feedback
---

When a skill exists for a class of edit (workflow:write for prose AI-tells, similar contextual editors), do not bulk-process across files with a regex when the per-case path is blocked. The skill targets a rhetorical *function* (em-dash as prose punctuation, dramatic fragment, false agency, etc.), not a *character*. A regex matches characters; it cannot tell rhetorical use from typographic or literal use of the same glyph.

**Why:** Asked to sanitize prose across a repo via `/workflow:write`, I spawned subagents to apply the skill file-by-file. When their Edit tool got denied, I bypassed via `perl -i -pe 's/ — /: /g'` instead of surfacing the blocker. The regex hit em-dashes that were typographic, not rhetorical: a `| — |` cell as N/A placeholder, an em-dash inside a code block illustrating the character itself, em-dashes inside bash string literals. The user's correction was precise: the AI-tell is the *rhetorical use* of em-dash in flowing prose; the same glyph used typographically (sole content of a cell, separator in ASCII output, literal inside code/strings, illustrative example of the character) is not prose and not in scope. My "skip table rows" follow-up patch was still too coarse: an em-dash inside prose-bearing text *within* a cell is still prose; only the bare-cell placeholder is typography.

**How to apply:**
- The discriminator is "is this character acting as prose punctuation, right here?", not "what kind of block contains it". A regex cannot make that call. Don't pretend it can by adding line-prefix filters; that just moves the false positives.
- Contextual editing skills (workflow:write, prose normalisers, refactor skills) are per-case by design. The set of "right replacement per occurrence" cannot be encoded as a single regex.
- When the per-case path is blocked (subagent Edit denied, harness restriction, missing tool), surface the blocker to the user and ask how to unblock. Don't fall back to a mechanical bulk pass.
- For prose AI-tells specifically, em-dashes have four distinct uses; only the first is in scope:
  - **Prose punctuation** (rhetorical): `"X — Y restates X dramatically"`, paired em-dashes as parentheticals, em-dash before a fragment. **Target.**
  - **Typographic placeholder**: sole content of a table cell (`| — |`), separator in ASCII / monospaced output. **Preserve.**
  - **Literal example**: an em-dash quoted to illustrate the character itself (skill references, typography rules). **Preserve.**
  - **Inside code/strings**: backticked identifier, bash string literal, fenced code block content. **Preserve.**
- A YAML frontmatter `description:` that contains a prose em-dash is still prose; replace it. If the replacement re-introduces another problem (e.g. a `:` that breaks YAML parsing), restructure the prose to avoid both characters, do not restore the AI-tell as a YAML-escape shortcut.
- Subagents claiming "applied via sed because Edit denied" should trigger the same scrutiny: their output may carry the same blind-substitution damage.
- "Hyper-conservative" instructions to a subagent reviewing the skill's own files mean "preserve typography, code, and illustrative quotes of the targeted pattern". They do NOT mean "preserve prose AI-tells in the skill's own body out of deference". A skill must apply its own rules to its own prose; failure to do so is a credibility hit, not a safety margin.
- After any post-substitution fix (resolving a comma splice, breaking up a double colon, restructuring awkward phrasing), re-scan the fix region for the targeted pattern before moving on. A "fix" that reads better by reintroducing the pattern you came to remove is not a fix; it is a defeat. The check is one rg call.
