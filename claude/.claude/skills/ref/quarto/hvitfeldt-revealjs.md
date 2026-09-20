---
domain: quarto
author: hvitfeldt
topic: revealjs
sources:
  - kind: blog
    url: https://emilhvitfeldt.com/project/slidecraft-101/
    captured: 2026-04-25
  - kind: blog
    url: https://slidecrafting-book.com/
    captured: 2026-04-25
  - kind: repo
    repo: EmilHvitfeldt/quarto-revealjs-template
    url: https://github.com/EmilHvitfeldt/quarto-revealjs-template
    ref: 5b870fe
    captured: 2026-04-25
    files:
      - index.qmd
      - all-the-js-code.html
      - styles.scss
---

# Quarto: RevealJS patterns (Hvitfeldt)

Reference patterns for Quarto RevealJS slides drawn from Emil Hvitfeldt's [Slidecraft 101](https://emilhvitfeldt.com/project/slidecraft-101/) series and his ~25 `quarto-revealjs-*` extensions.
Source: [emilhvitfeldt.com](https://emilhvitfeldt.com/) and [github.com/EmilHvitfeldt](https://github.com/EmilHvitfeldt) (captured 2026-04-25).

The Slidecraft posts have been consolidated into the [Slidecrafting book](https://slidecrafting-book.com/), and both remain valid sources.

## Extensions (revealjs-only)

Behavior plugins:

| Repo | Role | Activation |
|---|---|---|
| [revealjs-codewindow](https://github.com/EmilHvitfeldt/quarto-revealjs-codewindow) | IDE-style code blocks with filename tab + language icon | `revealjs-plugins: [codewindow]` + `::: {.codewindow}` |
| [revealjs-highlightword](https://github.com/EmilHvitfeldt/quarto-revealjs-highlightword) | highlight a specific word inside a code chunk | `revealjs-plugins: [highlightword]` |
| [revealjs-more-fragments](https://github.com/EmilHvitfeldt/quarto-revealjs-more-fragments) | exposes Animate.css + Magic.css as `.fragment` classes (`.bounceIn`, `.fadeIn` …), letter-by-letter, header animations, whole-slide | filter `more-fragments` |
| [revealjs-loud](https://github.com/EmilHvitfeldt/quarto-revealjs-loud) | force `.center` + `.r-fit-text` on every slide (Lessig style) | `revealjs-plugins: [loud]` |
| [revealjs-pechakucha](https://github.com/EmilHvitfeldt/quarto-revealjs-pechakucha) | 20×20 template (auto-advance 20s, exactly 20 slides) | `format: pechakucha-revealjs` |
| [revealjs-spotlight](https://github.com/EmilHvitfeldt/quarto-revealjs-spotlight) | positioned spotlight on a slide | `:::: {.spotlight top="20%" left="15%"} :::` |
| [revealjs-chat-bubbles](https://github.com/EmilHvitfeldt/quarto-revealjs-chat-bubbles) | iMessage-style bubbles, emoji reactions, `.typing` indicator | `revealjs-plugins: [chat-bubbles]` |
| [revealjs-editable](https://github.com/EmilHvitfeldt/quarto-revealjs-editable) | resize/move/rotate images & text live in rendered slides | `revealjs-plugins: [editable]` + `filters: [editable]` |
| [revealjs-transitions](https://github.com/EmilHvitfeldt/quarto-revealjs-transitions) | 100+ GL Transitions GPU shaders between slides | `transition: none` then `## Title {gl-transition="crosswarp"}` |
| [revealjs-tldraw](https://github.com/EmilHvitfeldt/quarto-revealjs-tldraw) | tldraw v4 layer over slides (key **T**), per-slide layer, localStorage persistence | `revealjs-plugins: [tldraw]` |
| [roughnotation](https://github.com/EmilHvitfeldt/quarto-roughnotation) | rough-style animated annotations | filter `roughnotation` |

Themes (templates): [letterbox](https://github.com/EmilHvitfeldt/quarto-revealjs-letterbox) (xaringan port), [nes-theme](https://github.com/EmilHvitfeldt/quarto-nes-theme), [blackboard-theme](https://github.com/EmilHvitfeldt/quarto-blackboard-theme), [earth](https://github.com/EmilHvitfeldt/quarto-revealjs-earth), [seasons](https://github.com/EmilHvitfeldt/quarto-revealjs-seasons), [inverse](https://github.com/EmilHvitfeldt/quarto-revealjs-inverse), [revealjs-template](https://github.com/EmilHvitfeldt/quarto-revealjs-template) (his personal starter: 16:9, `code-line-numbers: false`, `styles.scss` + `all-the-js-code.html` pre-wired).

Archived: `quarto-revealjs-imagemover` (replaced by `editable`).

## SCSS skeleton

```yaml
format:
  revealjs:
    theme: [default, custom.scss]
```

```scss
/*-- scss:defaults --*/
/*-- scss:rules --*/
```

Source: [Slidecraft 101: Colors and Fonts](https://emilhvitfeldt.com/post/slidecraft-colors-fonts/).

## Theming via `$theme-*` + named colors

Don't reuse `$body-bg` everywhere. Name the colors first, then assign Bootstrap/reveal variables to them:

```scss
/*-- scss:defaults --*/
$theme-darkblue: #01364C;
$theme-blue: #99D9DD;
$theme-white: #F7F8F9;
$theme-yellow: #F4BA02;

$body-bg: $theme-darkblue;
$body-color: $theme-white;
$link-color: $theme-blue;
$presentation-heading-color: lighten($theme-blue, 15%);
```

Map + accessor function variant ([Better SCSS files](https://emilhvitfeldt.com/post/slidecraft-scss-uses/)), which avoids `map-get` everywhere:

```scss
$colors: ("red": #FA5F5C, "blue": #394D85, "darkblue": #13234B);
@function theme-color($c) { @return map-get($colors, $c); }
$body-bg: theme-color("darkblue");
```

## Loop-generated utility classes

Signature pattern ([SCSS loops](https://emilhvitfeldt.com/post/slidecraft-scss-loops/)): combinatorial gradient highlighter `.hl-red-blue`:

```scss
@each $name1, $col1 in $colors {
  @each $name2, $col2 in $colors {
    span.hl-#{$name1}-#{$name2}, .hl-#{$name1}-#{$name2} > h2 {
      background-image: linear-gradient(90deg, $col1, $col2);
      background-size: 100% 42%;
      background-repeat: no-repeat;
      background-position: 0 85%;
      width: fit-content;
    }
  }
}
```

5 colors → 25 generated classes. The `background-position: 0 85%` + `size 100% 42%` is the trick for the yellow-marker effect (not a solid fill).

## Custom fragments (beyond `.fragment`)

Three critical selectors ([the CSS fragments post](https://emilhvitfeldt.com/post/slidecraft-fragment-css/)):

```css
.reveal .slides section .fragment.fragment-name           { /* before */ }
.reveal .slides section .fragment.fragment-name.visible   { /* after  */ }
.reveal .slides section .fragment.fragment-name.current-fragment { /* active step */ }
```

Neutralize the default fade-in without losing fragment mechanics:

```scss
.reveal .slides section .fragment.rgb {
  opacity: unset; visibility: unset; color: red;
  &.visible          { color: blue; }
  &.current-fragment { color: green; }
}
```

**`highlight-last` pattern** for incremental lists ([7 Tips](https://emilhvitfeldt.com/post/slidecraft-7-tips-and-tricks/)):

```markdown
::: {.incremental .highlight-last}
- thing 1
- thing 2
:::
```

```scss
.highlight-last  { color: grey; .current-fragment { color: #5500ff; } }
```

## Fragments driven from JS (Reveal events)

Pattern ([the JS fragments post](https://emilhvitfeldt.com/post/slidecraft-fragment-js/)): random color on each step, auto-scroll an output, advance a tabset:

```yaml
format:
  revealjs:
    include-after-body: ["_color.html"]
```

```js
Reveal.on('fragmentshown',  (event) => { /* event.fragment = DOM node */ });
Reveal.on('fragmenthidden', (event) => { });
const random_color = '#' + (Math.random()*0xFFFFFF<<0).toString(16);
```

His `quarto-revealjs-template` starter ships an empty `all-the-js-code.html` wired via `include-after-body` exactly for this case.

## Layout: columns + `r-fit-text` + absolute

Idiomatic columns ([Layout](https://emilhvitfeldt.com/post/slidecraft-layout/)):

```markdown
:::: {.columns}
::: {.column width="40%"} Left  :::
::: {.column width="60%"} Right :::
::::
```

**Full-bleed image** overflowed to avoid white bands:

```markdown
![](noelle-rebekah.jpg){.absolute top="-10%" right="-10%" height="120%" style="max-height: unset;"}
```

`style="max-height: unset"` is the key workaround: without it reveal truncates the image.

**Background image + positioned textbox** with backdrop-filter glassmorphism:

```markdown
## {background-image="tim-marshall.jpg"}

::: {.absolute left="55%" top="55%" style="font-size:1.8em; padding: 0.5em 1em;
     background-color: rgba(255,255,255,.5); backdrop-filter: blur(5px);
     box-shadow: 0 0 1rem 0 rgba(0,0,0,.5); border-radius: 5px;"}
Be Brave

Take Risks
:::
```

**`r-fit-text` is single-line only**, so two auto-fitted lines need **one div per line**:

```markdown
::: r-fit-text
This fits perfectly!
:::
::: r-fit-text
On two lines
:::
```

## Per-slide theme variants

Pattern ([Advanced themes](https://emilhvitfeldt.com/post/slidecraft-scss-themes/), [theme variants](https://emilhvitfeldt.com/post/slidecraft-theme-variants/)): `.theme-slideN` classes applied to a slide; target `:is(.slide-background)` for the background:

```scss
@mixin background-full {
  background-size: cover; background-position: center; background-repeat: no-repeat;
}
.theme-slide1 {
  &:is(.slide-background) {
    background-image: url('../../../../../assets/slide1.svg');
    @include background-full;
  }
  h3 { color: $theme-blue; font-size: 2em; }
  h2, h3, h4, h5, p, pre { margin-left: 100px; }
}
```

Usage: `## Funny title {.theme-slide1}`. The `:is(.slide-background)` is non-obvious: without it the `background-image` doesn't apply, because reveal splits the slide and its background into two separate DOM nodes.

## Code & output

Patterns ([Code and Output](https://emilhvitfeldt.com/post/slidecraft-code-output/)): clean code without border:

```scss
.reveal pre code        { background-color: #FFFFFF; }
.reveal div.sourceCode  { border: none; border-radius: 0; margin-bottom: 10px !important; }
```

Custom syntax-highlighting theme (light/dark via Pandoc `.theme` files):

```yaml
format:
  revealjs:
    theme: [default, custom.scss]
highlight-style:
  light: light.theme
  dark:  dark.theme
```

**Transparent plot** for non-white background ([plot backgrounds](https://emilhvitfeldt.com/post/slidecraft-plot-backgrounds/)):

```yaml
knitr:
  opts_chunk:
    dev: png
    dev.args: { bg: "transparent" }
```

**Sizing** ([plot sizing](https://emilhvitfeldt.com/post/slidecraft-plot-sizing/)): reveal stretches figures by default; disable globally with `auto-stretch: false` or per-slide via `## Title {.nostretch}`. `out-width: 6in` covers 90% of cases.

## Fonts via Google `@import`

```scss
/*-- scss:defaults --*/
@import url('https://fonts.googleapis.com/css2?family=IBM+Plex+Serif:wght@400;700&display=swap');
@import url('https://fonts.googleapis.com/css2?family=Manrope:wght@400;700&display=swap');

$font-family-sans-serif:    'Manrope', sans-serif;
$presentation-heading-font: 'IBM Plex Serif', serif;
$font-family-monospace:     'Fira Code', monospace;
```

Source: [Colors and Fonts](https://emilhvitfeldt.com/post/slidecraft-colors-fonts/).

## Non-obvious tricks

- **`{visibility="hidden"}`** on a heading: keeps the slide in the source but removes it from navigation, as in `## Slide Title {visibility="hidden"}`.
- **Inline SVG menu button** rewritten with a data-URI to rebrand without an external asset ([7 tips](https://emilhvitfeldt.com/post/slidecraft-7-tips-and-tricks/)):
  ```scss
  .reveal .slide-menu-button .fa-bars::before {
    background-image: url('data:image/svg+xml,<svg ... fill="rgb(42,118,221)" ...></svg>') !important;
  }
  ```
- **`asciicast`** for animated terminal-style outputs instead of static blocks ([asciicast post](https://emilhvitfeldt.com/post/slidecraft-asciicast/)):
  ```r
  asciicast::init_knitr_engine()
  options(asciicast_theme = "solarized-light")
  ```
  Then a `{asciicast}` chunk.
- **Absolute everything**: for design-first decks he abandons markdown flow and positions everything with `.absolute`, which gives more control than a theme.
- **gl-transitions trap**: must set `transition: none` at format level to disable reveal's native transition, otherwise both stack.
- **letterbox** is explicitly a xaringan port, a good entry point for migrating from xaringan.

## Cross-refs

- Index: <https://emilhvitfeldt.com/project/slidecraft-101/>
- Book: <https://slidecrafting-book.com/>
- Talk recap: <https://emilhvitfeldt.com/talk/2024-08-06-stunning-quarto-presentations/>
