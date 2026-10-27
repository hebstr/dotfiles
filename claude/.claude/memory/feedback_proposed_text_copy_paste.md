---
name: feedback_proposed_text_copy_paste
description: Present text drafted for the user's own document as plain lines, never inside a blockquote
metadata:
  type: feedback
---

Prose drafted for the user to accept into their own document is shown as plain lines, with no `>` blockquote and no list marker in front of it.

**Why:** the terminal renders `>` as a leading vertical bar, which lands in the clipboard and has to be stripped line by line before the text can go into the document. Stated 2026-10-27 during the external-review reporting pass on `eds-prise`, where every proposal had been quoted in a blockquote.

**How to apply:** draft the sentences flush left, one per line, matching the document's one-sentence-per-line convention so a paste needs no cleanup. A fenced block is acceptable when the content is code or must show its exact indentation. Markers stay allowed in prose that is only for reading, such as quoting a reviewer's comment back to the user. See [[feedback_personal_working_files]] for the write-gate on the user's own files and [[feedback_concision]] for how much narrative goes around a draft.
