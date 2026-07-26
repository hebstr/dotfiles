---
name: "Quarto theming changes: always render and scan output to verify"
description: For any SCSS/CSS/theme edit in a Quarto project or extension, render and inspect the compiled CSS before claiming the change is applied
metadata:
  type: feedback
---

For any theming change in a Quarto project or extension (SCSS, CSS, `_brand.yml`, theme variables, custom selectors), do not stop at writing the rule. Render the target document and inspect the compiled output to confirm the rule lands and wins specificity against Quarto/Bootstrap defaults.

**Why:** User caught me writing a `.quarto-title-meta` flex override that compiled fine but lost to Quarto's higher-specificity default `#title-block-header.quarto-title-block.default .quarto-title-meta { display:grid; grid-template-columns:repeat(2, 1fr) }`. SCSS that compiles is not the same as SCSS that takes effect. Quarto's default theme rules often have higher specificity than naive overrides.

**How to apply:**
0. Run the CSS/SCSS gate first (`rules/css.md`, auto-loaded on `**/*.{css,scss}`): it catches syntax and deprecation defects, and nothing about specificity. Passing the gate says nothing about whether the rule takes effect, so the render check below stays mandatory.
1. Render the relevant target (e.g. `quarto render example.qmd --to <format>`).
2. Locate the compiled CSS. Quarto often inlines it as a `<link href="data:text/css,...">` data URI (URL-encoded, not base64). A plain `<style>` tag search will miss it. Decode with `urllib.parse.unquote` (or base64) before grepping.
3. Verify both: (a) the rule is present in the compiled CSS, (b) no Quarto/Bootstrap default with higher or equal-and-later specificity overrides it.
4. Quarto title-block defaults use selectors like `#title-block-header.quarto-title-block.default …` : match that structure when overriding nested theme rules. Bootstrap defaults often need `:root` or component-scoped selectors.
5. If the rule is overridden, fix specificity. Never reach for `!important` as the first lever.
