---
name: reference-quarto-page-title-fallback
description: An empty or absent `title:` on a Quarto website page sends the filename into `<title>`; only the home page escapes it
metadata:
  type: reference
---

On a Quarto website page, `title: ""` and no `title:` key at all behave identically for the HTML `<title>`: both emit `<basename> – <site title>`, the basename taken from the source filename. Measured 2026-10-23 on Quarto 1.10.19 in site-alisp, with a throwaway `tmp-title-probe.qmd` carrying no `title:` key, which rendered as `<title>tmp-title-probe – ALiSP - Association Lilloise des Internes de Santé Publique</title>`.

What differs is the visible title block: both forms suppress the `<h1 class="title">`, so emptying the key is a working way to hide the heading, and a costly one for the tab and for search results.

The home page is the exception. `index.qmd` carries no `title:` and its `<title>` is the site title alone, which comes from its status as the website's home page rather than from the missing key. Reading that page as the general case is what makes the filename fallback surprising.

To hide the heading while keeping a real `<title>`, keep the `title:` and hide `#title-block-header` with a page-scoped CSS rule; `body:has(#listing-blog-posts) #title-block-header` in site-alisp's `theme-base.scss` is the existing shape for that.

One trap on the probe itself: a file whose name starts with `_` is skipped by the render even when the project's `render:` list is `**/*.qmd`, so a probe page must be named without that prefix or it produces no output at all.

Related: [[reference_quarto_file_outside_render_list]], [[feedback_verify_quarto_theming]].
