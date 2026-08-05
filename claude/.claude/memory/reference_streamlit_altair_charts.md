---
name: Altair charts inside Streamlit, layout and tooltip traps
description: "st.altair_chart applies autosize fit so properties(height=) sets the TOTAL svg height and a legend can starve the plot area to 0 px; a scalar Vega padding crashes the component; the tooltip is one shared #vg-tooltip-element on document.body with no per-datum hook; st.html takes unsafe_allow_javascript and components.v1.html is deprecated for st.iframe"
metadata:
  type: reference
---

Verified 2026-08-02 against Streamlit 1.60.0 and Altair 6.2.2, by dumping the rendered SVG out of the DOM rather than by reading docs. All of it cost a debugging cycle each.

**`properties(height=)` is the total, not the plot area.** Streamlit sets `autosize: {type: fit, contains: padding}`, so the value covers legend + plot + axis. At `height=80` with a top legend the plot area was `v0`, literally 0 px: marks landed on a degenerate line and the axis labels rendered *outside* the viewBox, invisible with no error anywhere. Dropping the legend (`legend=None`) returned 53 px to the plot. Suspect this whenever an axis silently fails to appear.

**A scalar Vega `padding` crashes the chart.** Streamlit writes `spec.padding.bottom` for its own purposes, so `properties(padding=10)` throws `TypeError: Cannot create property 'bottom' on number '10'` and the traceback replaces the chart. Pass an object: `{"left": …, "right": …, "top": …, "bottom": …}`.

**Scale padding vs view padding.** `alt.Scale(padding=N)` expands the *domain*, and if `nice` is also set the padded domain is niced, so 10 px became a whole extra year on each side of a 12-year axis. `properties(padding=…)` reserves SVG margin and leaves the domain alone. For "marks at the domain bounds must not be clipped", view padding is the one.

**Marks with no `y` encoding land at the plot centre**, and a `mark_rule` given `x`/`x2` but no `y` does *not*: give both layers the same `alt.YDatum(0, scale=alt.Scale(domain=[-1, 1]), axis=None)` to put a baseline rule and its points on one line.

**`order` channel z-ordering is a stable sort**, so a binary order field raises one mark to the front and leaves every tie in source row order.

**The tooltip cannot be styled per datum.** It is a single `<div id="vg-tooltip-element" class="vg-tooltip visible …-theme">` created lazily on first hover and appended to `document.body`, reused for every mark, holding escaped HTML with no `data-*` hook. Consequences: a selector scoped under `.stApp` never matches it, and CSS alone can never index it on the hovered mark's colour. Streamlit's own rule (`static/js/styled-components.*.js`, search `#vg-tooltip-element`) also pins `max-width` on `td.key` / `td.value` off `maxChartTooltipWidth`, so enlarging the font without overriding those truncates values with an ellipsis.

**Injecting JS into the Streamlit document**: `st.html(body, unsafe_allow_javascript=True)` executes it in the main document. `st.components.v1.html` is deprecated (removal 2026-06-01) in favour of `st.iframe`, which embeds a non-URL string as `srcdoc` with documented same-origin access to the parent, so `window.parent.document` from inside it is supported rather than a hack. Do not reach for the iframe when `st.html` suffices.

See [[feedback_browser_layout_probe]] for how to inspect any of this without the user's browser, and [[project_prise_timeline_fixture]] for the app this came from.
