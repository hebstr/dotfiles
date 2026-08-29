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
6. When the render check is not conclusive, or when a rule is present and the result still looks wrong, **measure the computed styles instead of iterating on screenshots**. Copy the rendered HTML to `probe.html`, inject before `</body>` a script that writes `getComputedStyle(el)` of the target element into a `<pre>` prepended to `body`, then `chromium --headless=new --no-sandbox --disable-gpu --dump-dom "file://$PWD/probe.html"`. To see the result, `--screenshot` with `--window-size`, cloning the target element to the top of `body`: in headless, programmatic scrolling does not move the viewport and the capture comes back blank. The snap `chromium` cannot read dot-directories under `$HOME`, so put the probe inside the project.

**Why step 6 exists.** A screenshot shows the result, never the cause: it cannot separate "the rule does not apply" from "it applies and the look is wrong", and it never names the winning rule. The case that established it: half a rule applied (`color`, `font-size`) and half did not (`background-color`, `padding`), because the competing theme rule carried `!important` on those two properties only. Three turns were spent guessing; one measurement settled it.

**The specificity trap behind that case.** `code:not(.sourceCode)` scores `(0,1,1)`, `:not()` counting its class argument, so `h3 code` at `(0,0,2)` loses on any property the theme marks `!important` while winning on the ones it does not. Count `:not()` arguments when comparing specificity, and beat such a rule with `h3 code:not(.sourceCode)` at `(0,1,2)` rather than piling on `!important`.

**Do not accuse a tool without testing it.** In the same episode I blamed `panache` twice, for stripping a CSS comment and for mangling a hex colour inside a `{=html}` block. Both were false: the user was editing the same block in parallel. A ten-second test (write the construct, run the formatter, diff) would have prevented both claims. See [[feedback_verify_before_claiming]].
