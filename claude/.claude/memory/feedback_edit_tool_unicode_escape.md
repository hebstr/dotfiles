---
name: Tool parameters decode four-hex-digit \uXXXX escapes into literal characters
description: A `\u` escape with four hex digits written in any tool parameter (Edit, Write, Bash) lands as the decoded character; in R write the braced form `\u{a0}` instead and check bytes with `rg -c $'\xc2\xa0'`
metadata:
  type: feedback
---

A four-hex-digit `\u` escape (the NBSP one, `\u` followed by `00a0`) written in a tool parameter reaches the file as the decoded character, not as the six-character escape. First observed 2026-09-16 on `md-nesrine/lib/out_helpers.R`, `.float_label()`, where an Edit inside a `str_glue()` literal wrote a literal U+00A0; reproduced the same day in the scratchpad with both Write and Edit (`od -c` shows bytes `302 240`, no backslash). The decoding also hits Bash commands, so an `rg -F` search spelled with that escape looks for the NBSP itself and cannot tell the two forms apart. The same session failed to match an `old_string` meant to contain a literal U+00A0.

Measured on the same test: the braced form `\u{a0}`, the `\x` escapes and a doubled backslash all land verbatim. In R `identical("\u{a0}", intToUtf8(160))` is `TRUE`, so `\u{a0}` is a drop-in spelling.

**Why:** the decoded character looks identical in an editor and in `git diff`, and it silently reintroduced the very defect the walkthrough had just fixed (an invisible non-breaking space in source). `air` and `jarl` pass either way and the R string value is the same, so only a byte check catches it.

**How to apply:** in R source, write a non-ASCII escape in braced form (`\u{a0}`) through Edit/Write; no shell substitution is needed, so the Edit/Write rule in CLAUDE.md holds unchanged. After the edit, confirm no raw character landed with `rg -c $'\xc2\xa0' <file>` (zero hits expected). Only R has been verified: Python has no `\u{...}` syntax (`\N{NO-BREAK SPACE}` is its named alternative, untested through the tools), so test the spelling in the scratchpad before relying on it in another language.
