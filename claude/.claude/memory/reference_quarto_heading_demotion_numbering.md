---
name: reference_quarto_heading_demotion_numbering
description: "Quarto section numbering tolerates one level of implicit promotion, not two: a document topped at `###` numbers 0.1, and `shift-heading-level-by` moves the tags without moving the numbers"
metadata:
  type: reference
---

Measured 2026-10-28 on a throwaway Quarto project under the `hebstr-doc` format, HTML and docx, while splitting a document into a standalone plus an includable fragment ([[reference_quarto_include_path_resolution]], [[project_quarto_extensions_need_project_root]]).

`number-sections` numbers from the shallowest heading level present, but only one level deep:

```
| Shallowest heading in the document | Numbering rendered   |
|------------------------------------|----------------------|
| `#`                                | 1, 2, 2.1, 3         |
| `##`                               | 1, 2, 2.1, 3         |
| `###`                              | 0.1, 0.2, 0.2.1, 0.3 |
```

So a fragment shared between a standalone sheet and a host document can be demoted one level for free and not two. A `quarto pandoc --number-sections` probe does not catch this: the divergence is in Quarto's own numbering filter, not in pandoc.

`shift-heading-level-by` is not the repair. It is document-wide, so it cannot target one include, and it moves the heading tags without moving the numbers: `-1` over a `##`-topped document restores `h1` in the HTML and `Heading1` in the docx, the numbers having been right already; `-2` over a `###`-topped one restores `h1` and leaves the numbers at `0.1`. The only way out of a two-level demotion is `number-sections: false`, which drops the numbering rather than fixing it.

Two side facts from the same probe. A heading inside a `::: callout-*` div is consumed as the callout title whatever its level and whatever the shift, so it never costs a depth. And duplicate heading text across a host and its include suffixes the later one: the first occurrence keeps the clean anchor, the second gets `-1`.

Read a format extension's `toc-depth` and `number-depth` before pricing a demotion against them rather than assuming Quarto's defaults of 3: `hebstr-doc` declares 4 for both, emits a Word TOC field of `TOC \o "1-4"`, and sets `number-sections: false` for its docx format, so Word numbers no section at all.
