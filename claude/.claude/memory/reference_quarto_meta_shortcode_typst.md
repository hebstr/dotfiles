---
name: Quarto meta shortcode inside a raw Typst block
description: "`{{< meta a.b >}}` IS substituted inside a ```{=typst} block, but array indexing is unsupported and a missing key prints `?meta:key` into the PDF instead of failing; drives params-in-Typst over params-in-YAML"
metadata:
  type: reference
---

Measured 2026-08-20, Quarto 1.10.18 + Typst 0.15.1, by rendering with `keep-typ: true` and reading the generated `.typ`.

```
| Form                              | Generated .typ            |
|-----------------------------------|---------------------------|
| `{{< meta patient.nom >}}`        | `DUPONT` (substituted)    |
| key present, empty string         | empty (correct)           |
| `{{< meta patient.inexistant >}}` | `?meta:patient.inexistant`|
| `{{< meta lignes >}}` (a YAML seq)| empty string              |
| `{{< meta lignes.0.dci >}}`       | `?meta:lignes.0.dci`      |
```

Two facts that matter beyond the syntax:

- **Scalar nested keys work**, so the shortcode is a real option for a handful of scalar parameters. Sequences do not: neither the whole sequence nor an indexed element resolves.
- **A missing key does not fail the render.** It emits `WARNING (main.lua) Unknown meta key ... specified in a metadata Shortcode` and prints the literal `?meta:<key>` into the PDF, exit 0. On any document whose correctness matters (a prescription, an invoice, an attestation) this is a silent-defect vector, and it is the reason to declare parameters as Typst `#let` bindings in a `PARAMÈTRES` section of the `{=typst}` block rather than in the YAML front matter.

Consumed by the `~/admin/pro-ordo` prescription template design (`.claude/DESIGN.md`). Related: [[reference_quarto_lua_shortcodes]], [[user_quarto_typst_only]].
