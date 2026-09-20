---
domain: quarto
author: pingfan
topic: scss
sources:
  - kind: repo
    repo: pingfan-hu/website
    url: https://github.com/pingfan-hu/website
    ref: "e20a6d1"
    captured: 2026-04-25
    files:
      - styles/styles.scss
---

# Quarto: Theming SCSS (dark code window)

macOS-style dark code blocks with traffic lights, header bar, line numbers, and a copy button repositioned into the bar.
Source: [pingfan-hu/website, styles/styles.scss](https://github.com/pingfan-hu/website/blob/main/styles/styles.scss) (captured 2026-04-25).

## Header bar with traffic lights

The window is `div.sourceCode { position: relative; ... }`; the bar is a `::before` pseudo-element with three radial gradients placed by `background-position`.
No SVG, no extra DOM.

```scss
div.sourceCode {
  position: relative;
  border-radius: 10px;
  overflow: hidden;
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
  }
}
```

## Copy button moved into the bar

Quarto injects `.code-copy-button` inside `div.sourceCode`.
With `position: absolute` it sits flush right inside the 36px bar.
The Bootstrap icon is hidden, `::after { content: 'COPY' }` provides the label.

```scss
.code-copy-button {
  position: absolute !important;
  top: 0 !important;
  right: 8px !important;
  height: 36px !important;
  padding: 0 10px !important;
  background: transparent !important;
  border: none !important;
  color: #938e87 !important;

  &:hover { color: #e8e4dc !important; }
  i.bi { display: none !important; }
  &::after { content: 'COPY'; letter-spacing: 0.1em; }
}

.code-copy-button-tooltip { display: none !important; }
```

## Line numbers via counter-increment

```scss
pre > code.sourceCode > span {
  counter-increment: line;
  text-indent: -2.8em;
  padding-left: 2.8em;
  display: block;
  white-space: pre;

  &:before {
    content: counter(line) " ";
    color: #5a5955;
    display: inline-block;
    width: 2em;
    text-align: right;
    margin-right: 0.8em;
    padding-right: 0.5em;
    border-right: 1px solid #383835;
  }
}
```

`display: block` and `white-space: pre` are deliberate: they fix Safari text-selection on non-last lines and collapse the `\n` text nodes Quarto inserts between line spans.

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
