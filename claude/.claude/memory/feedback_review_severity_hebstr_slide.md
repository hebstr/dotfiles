---
name: Review severity for quarto-hebstr-slide
description: "Calibrate code review of the quarto-hebstr-slide Quarto revealjs theme extension (_extensions/hebstr-slide/theme.scss and its demo deck example.qmd): the standing public-API rejection, the measured non-defects that open a pass already dismissed, and the six revealjs/Quarto cascade facts a reviewer and an external judge both re-derive wrong; supplements feedback_review_severity_personal"
metadata:
  type: feedback
---

One developer, zero consumer projects, no versioning policy, no `CONTRIBUTING.md`. Calibrate as a personal package per [[feedback_review_severity_personal]], and treat the theme's own `.claude/DESIGN-EXTENSION.md` as governing: it holds the palette rulings and the cascade mechanics, so a review that contradicts it is re-opening a decision rather than finding a defect.

**Why:** the 2026-11-09 audit of `theme.scss` (`/audit:walkthrough … --reviewer posit-dev:critical-code-reviewer --auto`, 14 findings, 11 accepted and fixed, 2 noted, 1 deferred, one half rejected) found no wrong colour value and four declarations that never reached the screen, three of them colours. Every mechanism claim in that pass was wrong somewhere, the external judge's included, and only a `getComputedStyle` probe settled them.

**How to apply.**

**Standing rejection, do not re-raise.** That a construct is not `!default`-overridable, or that moving it into `scss:defaults` would let a consumer retarget it, is a public-API argument, and there are no consumers. `$slide-grounds` stays in `scss:rules` beside the loop that consumes it; only the one ground colour that lacked a palette name took one. Same shape as the no-public-API rule of [[feedback_review_severity_hebstr_doc]].

**The six facts a reviewer will otherwise re-derive wrong.**

1. **reveal copies a slide's whole class list onto its `.slide-background` element.** A bare ground-class rule therefore paints that element too, reveal's `getContrastClass` reads its computed background, and `has-dark-background` lands on the section. A reviewer will attribute the class to the section's own computed background, and an external judge will deny the mechanism outright on the ground that reveal reads a separate background element (`openai/gpt-6.1-sol` returned `invalid` on exactly that, 2026-11-09). Both miss the duplication. Measure the `classList`, never argue it.
2. **A ground-scoped colour needs `!important` or Quarto wins.** `section.has-dark-background code{color:#ffa07a}` sits at (0,1,2) against `.green-centered code` at (0,1,1), and `section.has-dark-background,…h1…h6{color:#fff}` reaches every heading level. Both are in the compiled CSS.
3. **An `!important` on the section does not reach a child that declares the property itself.** The ground loop's `h1-h6 { color: … !important }` does not colour a `code` nested in a heading; only a declaration on `code` does.
4. **An identical selector later in document order beats the theme at equal specificity.** Quarto emits `.reveal div.sourceCode { margin: 0; overflow: auto }` in a `<style>` block near the end of the document, against the theme's compiled stylesheet near the start, both (0,2,1). Enumerate the stylesheets in true document order: data-URI links and `<style>` blocks interleave, so extracting one kind then the other reverses the cascade and names the wrong winner.
5. **`inherit` on a custom property is invalid at computed-value time.** `$selection-color: inherit` compiled to `--r-selection-color: inherit`, which computes empty, so `::selection` fell back to the inherited colour. The compiled text and the computed value disagree, which is the trap of this whole file.
6. **Slide headings are WCAG large text.** They compute to 46.8 px at weight 600, so 3:1 is the applicable floor rather than 4.5:1. Inline code is 31.5 px in the body and 40.95 px in a heading, also large; the line-number gutter is 21.6 px, under the 24 px threshold, so 4.5:1 applies there.

**Measured non-defects: a pass opens with these already dismissed.**

- The compiled stylesheet carries both `.reveal .footer{color:#e8e8e8}` and Quarto's `color:rgb(102.5,102.5,102.5)`. The computed value is `#e8e8e8` on `#161616`, 14.77:1. The theme wins and there is no footer defect.
- `example.qmd` exercises no content link, so the link colour and its underline appear nowhere in the rendered deck.
- The card panel overflows the slide bottom at the demo's content length. Pre-existing and unrelated to colour.
- The two remaining `#fff` literals (code text inside the dark window, the COPY button's hover) are not palette duplicates: `$body-bg` is the light page ground, a different thing semantically.
- The region markers and the ban on `@import` and `@use` in a theme layer: `rules/css.md` carries both, and a finding against either is answered there.
- The `DEFERRED.md` row of 2026-09-20 on the line-number gutter covers **restyling** it, not recolouring it; the recolouring landed 2026-11-09 and the row records it.

**Verification that actually decides.** Passing the CSS gate says nothing about whether a rule wins, and a rule's presence in the compiled CSS says nothing either. Render, then read computed styles through a probe page per [[feedback_verify_quarto_theming]] and `rules/chromium.md`. reveal needs a few seconds of virtual time before the contrast classes exist, and a slide that is not `.present` still answers `getComputedStyle`, so one probe reads all five grounds at once by injecting elements into each section.
