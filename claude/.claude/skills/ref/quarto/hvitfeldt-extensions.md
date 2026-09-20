---
domain: quarto
author: hvitfeldt
topic: extensions
sources:
  - kind: repo
    repo: EmilHvitfeldt/quarto-arrows
    url: https://github.com/EmilHvitfeldt/quarto-arrows
    ref: 6795554
    captured: 2026-04-25
    files:
      - _extensions/arrows/_extension.yml
      - _extensions/arrows/arrows.lua
  - kind: repo
    repo: EmilHvitfeldt/quarto-timeline
    url: https://github.com/EmilHvitfeldt/quarto-timeline
    ref: 6a092ac
    captured: 2026-04-25
    files:
      - _extensions/timeline/_extension.yml
      - _extensions/timeline/timeline.lua
  - kind: repo
    repo: EmilHvitfeldt/quarto-tegaki
    url: https://github.com/EmilHvitfeldt/quarto-tegaki
    ref: d2ad97e
    captured: 2026-04-25
    files:
      - _extensions/tegaki/_extension.yml
      - _extensions/tegaki/tegaki.lua
  - kind: repo
    repo: EmilHvitfeldt/quarto-designmode
    url: https://github.com/EmilHvitfeldt/quarto-designmode
    ref: 424cb6a
    captured: 2026-04-25
    files:
      - _extensions/designmode/_extension.yml
      - _extensions/designmode/designmode.lua
  - kind: repo
    repo: EmilHvitfeldt/quarto-snow
    url: https://github.com/EmilHvitfeldt/quarto-snow
    ref: 7a12bc5
    captured: 2026-04-25
    files:
      - _extensions/snow/_extension.yml
      - _extensions/snow/snow.lua
  - kind: repo
    repo: EmilHvitfeldt/quarto-color-classes
    url: https://github.com/EmilHvitfeldt/quarto-color-classes
    ref: v1.0.0
    captured: 2026-04-25
    files:
      - _extensions/color-classes/_extension.yml
      - _extensions/color-classes/color-classes.scss
  - kind: blog
    url: https://emilhvitfeldt.com/blog.xml
    captured: 2026-04-25
---

# Quarto: Hvitfeldt non-revealjs extensions

Reference for Emil Hvitfeldt's Quarto extensions that target HTML/PDF/Typst documents (not revealjs-only).
Source: [github.com/EmilHvitfeldt](https://github.com/EmilHvitfeldt) (captured 2026-04-25).

For his revealjs-only extensions and slide patterns, see [hvitfeldt-revealjs](hvitfeldt-revealjs.md).

## Multi-format extensions

### quarto-arrows

- Repo: <https://github.com/EmilHvitfeldt/quarto-arrows> · demo: <https://emilhvitfeldt.github.io/quarto-arrows/>
- Type: **shortcode** (`arrows.lua`) with TikZ injection for PDF
- Targets: **HTML, PDF (TikZ), Typst (CeTZ), RevealJS**
- What: draws arrows (straight, Bézier, waypoints, styled heads, labels) between two coordinates, with `aria-label`/alt support.
- Verbatim usage:
  ```markdown
  {{< arrow from="50,50" to="250,50" >}}
  {{< arrow from="50,50" to="250,50" curve="0.5" color="blue" >}}
  {{< arrow from="50,50" to="250,50" head="stealth" label="Click here" >}}
  ```
- `_extension.yml`: `quarto-required: ">=1.3.0"`, `shortcodes: arrows.lua` + `formats.pdf.include-in-header` for TikZ.
- Status: active.
- Note: also works in revealjs (where `fragment="true"` adds keypress animation), but designed format-agnostic.

### quarto-timeline

- Repo: <https://github.com/EmilHvitfeldt/quarto-timeline> · demo: <https://emilhvitfeldt.github.io/quarto-timeline/>
- Type: **filter Lua** (`timeline.lua`)
- Targets (per README): **HTML documents and revealjs presentations**
- What: nested divs `.timeline > .event` become chronological timelines (horizontal, vertical, alternating). Fragment-pan modes only in revealjs.
- Verbatim usage:
  ```markdown
  ::: timeline
  ::: {.event data-label="2020"}
  **Project Started**
  Initial concept and planning phase.
  :::
  ::: {.event data-label="2021"}
  **First Release**
  Launched version 1.0 to early users.
  :::
  :::
  ```
- `_extension.yml`: `quarto-required: ">=1.4.0"`, `filters: timeline.lua`.
- Status: active.

### quarto-tegaki

- Repo: <https://github.com/EmilHvitfeldt/quarto-tegaki> · demo: <https://emilhvitfeldt.github.io/quarto-tegaki/>
- Type: **filter Lua** (`tegaki.lua`)
- Targets: **RevealJS and plain HTML documents**
- What: handwriting animation via the [tegaki](https://github.com/KurtGokhan/tegaki) JS lib (bundled 0.11.1, offline). Built-in fonts (Caveat, Italianno, Tangerine, Parisienne) and custom TTF support.
- Verbatim usage:
  ```markdown
  [Hello, World!]{.tegaki}
  ```
- `_extension.yml`: `quarto-required: ">=1.4.0"`, `filters: tegaki.lua`.
- Status: active.

### quarto-designmode

- Repo: <https://github.com/EmilHvitfeldt/quarto-designmode> · demo: <https://emilhvitfeldt.github.io/quarto-designmode/>
- Type: **filter Lua** (`designmode.lua`)
- Targets: **HTML outputs, including revealjs slides**
- What: an `Alt+D` keyboard toggle activating [`document.designMode`](https://developer.mozilla.org/en-US/docs/Web/API/Document/designMode), giving live, non-persistent WYSIWYG editing of the rendered document. Useful for live demos and screenshots.
- Verbatim usage:
  ```yaml
  filters:
    - designmode
  ```
- `_extension.yml`: minimal (no `quarto-required`).
- Status: stable, no recent updates.

### quarto-snow

- Repo: <https://github.com/EmilHvitfeldt/quarto-snow>
- Type: **filter Lua** (`snow.lua`)
- Targets: **HTML outputs, including revealjs slides**
- What: falling-snowflakes background via [hcodes/snowflakes](https://github.com/hcodes/snowflakes/).
- Verbatim usage:
  ```yaml
  filters:
    - snow
  ```
- Status: stable. Seasonal gimmick.

## SCSS helper packaged as extension

### quarto-color-classes

- Repo: <https://github.com/EmilHvitfeldt/quarto-color-classes> · demo: <https://emilhvitfeldt.github.io/quarto-color-classes/>
- Type: **SCSS helper** shipped as extension. Unusual: `_extension.yml` declares `filters: color-classes.scss`, using the `filters` slot to deliver SCSS rather than a Lua filter.
- Targets: any HTML/SCSS-consuming format. README example shows revealjs but the Tailwind-like utility classes (`text-*`, `bg-*`, `border-*`, `fill-*`, `stroke-*`) work for any HTML output that compiles SCSS.
- What: generates utility CSS classes from a `$colors` SCSS map defined under `/*-- scss:uses --*/`.
- Verbatim usage:
  ```yaml
  format:
    revealjs:
      theme:
        - default
        - styles.scss
        - _extensions/emilhvitfeldt/color-classes/color-classes.scss
  ```
  ```scss
  /*-- scss:uses --*/
  $colors: (
    "white": #ffffff,
    "black": #0d0c0c,
    "yellow": #ef9329,
    "red": #920c1a,
    "blue": #043892,
  );
  ```
- `_extension.yml`: `quarto-required: ">=1.8.0"`, `filters: color-classes.scss`.
- Status: active.

## Quarto-related repos that are NOT extensions

These appear under the `quarto-*` prefix but should not be installed as Quarto extensions:

- **quarto-extension-helpers**: VS Code extension, autocomplete for roughnotation, fontawesome, countdown, downloadthis, acronyms, now. <https://github.com/EmilHvitfeldt/quarto-extension-helpers>
- **quarto-helpers**: VS Code extension, autocomplete for Quarto SCSS variables with format-aware detection (RevealJS, HTML, Dashboard). <https://github.com/EmilHvitfeldt/quarto-helpers>
- **quarto-syntax-theme-editor**: playground for editing KDE `.theme` syntax-highlighting files. <https://github.com/EmilHvitfeldt/quarto-syntax-theme-editor>
- **quarto-iframe-examples**: gallery of iframes for revealjs slides. <https://github.com/EmilHvitfeldt/quarto-iframe-examples>

## Non-slides blog posts

From the [blog RSS feed](https://emilhvitfeldt.com/blog.xml), category `quarto` excluding `slidecraft 101`:

- [Better performant Quarto websites](https://emilhvitfeldt.com/post/quarto-performance/): techniques to reduce weight and speed up Quarto site loading.
- [Adding alt text to figures in quarto with Claude Code](https://emilhvitfeldt.com/post/claude-code-alt-text-quarto/): accessibility workflow, alt text generation via an AI agent.
- [Announcing quarto-timeline](https://emilhvitfeldt.com/post/quarto-timeline/): timeline extension announcement.

All other `quarto` posts in the feed are tagged `slidecraft 101` and covered in [hvitfeldt-revealjs](hvitfeldt-revealjs.md).

## Sources

- [Emil Hvitfeldt repos (GitHub API)](https://api.github.com/users/EmilHvitfeldt/repos)
- [Emil Hvitfeldt blog RSS](https://emilhvitfeldt.com/blog.xml)
