---
domain: quarto
author: pingfan
topic: scss
sources:
  - kind: repo
    repo: pingfan-hu/website
    url: https://github.com/pingfan-hu/website
    ref: "003a219"
    captured: 2026-09-20
    files:
      - resources/styles/styles.scss
---

# Quarto: Theming SCSS (dark code window)

macOS-style dark code blocks with traffic lights, header bar, line numbers, and a copy button repositioned into the bar.
Source: [pingfan-hu/website, resources/styles/styles.scss](https://github.com/pingfan-hu/website/blob/main/resources/styles/styles.scss) (captured 2026-09-20).

## Header bar with traffic lights

The window is `div.sourceCode { position: relative; ... }`; the bar is a `::before` pseudo-element with three radial gradients placed by `background-position`.
No SVG, no extra DOM.

```scss
div.sourceCode {
  position: relative;
  border-radius: 10px;
  overflow: hidden;
  overflow-x: auto;
  border: 1px solid #383835;
  margin: 1.2em 0;

  &::before {
    content: '';
    display: block;
    height: 36px;
    background-color: #212120;
    background-image:
      radial-gradient(circle, #FF5F57 50%, transparent 50%),
      radial-gradient(circle, #FEBC2E 50%, transparent 50%),
      radial-gradient(circle, #28C840 50%, transparent 50%);
    background-size: 12px 12px, 12px 12px, 12px 12px;
    background-position: 16px center, 34px center, 52px center;
    background-repeat: no-repeat;
    border-bottom: 1px solid #383835;
    flex-shrink: 0;
  }
}
```

## Copy button moved into the bar

Quarto injects `.code-copy-button` inside `div.sourceCode`, so both rules are nested there rather than written at the root.
With `position: absolute` the button sits flush right inside the 36px bar.
The Bootstrap icon is hidden and `::after { content: 'COPY' }` supplies the label; the tooltip is suppressed because the checkmark Quarto swaps in on click is feedback enough.

```scss
div.sourceCode {
  .code-copy-button-tooltip {
    display: none !important;
  }

  .code-copy-button {
    position: absolute !important;
    top: 0 !important;
    right: 8px !important;
    height: 36px !important;
    padding: 0 10px !important;
    background: transparent !important;
    border: none !important;
    color: #938e87 !important;
    font-family: 'Maple Mono', monospace !important;
    font-size: 0.75em !important;
    letter-spacing: 0.06em !important;
    cursor: pointer;
    display: flex !important;
    align-items: center !important;
    transition: color 0.15s ease !important;

    &:hover { color: #e8e4dc !important; }

    i.bi { display: none !important; }

    &::after {
      content: 'COPY';
      font-family: 'Maple Mono', monospace;
      font-size: 0.75em;
      letter-spacing: 0.1em;
    }
  }
}
```

## Line numbers via counter-increment

The gutter is an absolutely positioned `::before` covering the span's left padding, not an `inline-block` pushed around by a negative `text-indent`.

```scss
pre > code.sourceCode > span {
  counter-increment: line;
  position: relative;
  display: block;
  white-space: pre;
  padding-left: 3em;
  min-height: 1lh;

  &::before {
    content: counter(line);
    position: absolute;
    left: 0;
    top: 0;
    bottom: 0;
    width: 3em;
    box-sizing: border-box;
    padding-right: 1.4em;
    text-align: right;
    color: #5a5955;
    background-color: #262624;
    background-image: linear-gradient(#383835, #383835);
    background-repeat: no-repeat;
    background-size: 1px 100%;
    background-position: 2em 0;
    user-select: none;
    -webkit-user-select: none;
    pointer-events: none;
  }
}
```

Each decision in that block fixes a defect the naive version has.

Taking the gutter out of the flow and marking it `user-select: none` is what keeps the selection highlight on the code text alone; `width: 3em` covers the whole left padding so nothing shows in the gutter even on an empty line.
The opaque `background-color`, matching the chunk background, is a safety belt over that: it hides any selection rectangle a browser still paints behind the left padding on a fully selected intermediate line.
The 1px divider is painted as a `linear-gradient` sized `1px 100%` and placed by `background-position`, which puts it at a chosen offset inside the gutter rather than at the edge a `border-right` would force.
`min-height: 1lh` keeps an empty line visible: the `::before` is out of flow, so without it an empty span collapses to zero height.
`display: block` fixes Safari text selection on lines other than the last, and `white-space: pre` preserves the whitespace inside each line.

Collapsing the `\n` text nodes Quarto inserts between line spans is a separate job, done one level up on the `code` element:

```scss
div.sourceCode pre.sourceCode code {
  display: block;
  white-space: normal;
  background-color: transparent !important;
}
```

The `background-color` override belongs to the same rule upstream: Bootstrap's `p code.sourceCode` / `li code.sourceCode` / `td code.sourceCode` rules, meant for inline code, otherwise lay a grey slab over any block nested in a list, a paragraph or a table cell.

## Palette (light mode, token-dark)

```
| Role          | Color     |
|---------------|-----------|
| Window border | `#383835` |
| Header bar    | `#212120` |
| Code bg       | `#262624` |
| Code fg       | `#e8e4dc` |
| Muted         | `#938e87` |
| Line number   | `#5a5955` |
```

Dark mode inverts via `body.quarto-dark div.sourceCode { ... }`; see source.
