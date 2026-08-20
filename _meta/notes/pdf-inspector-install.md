# pdf-inspector : installation et évaluation

*2026-08-20T14:13:55Z by Showboat 0.6.1*
<!-- showboat-id: 5b542714-f2ef-4873-8f80-02ca692dc120 -->

Outil Rust de Firecrawl (MIT, crates.io v1.15.0) : classification PDF texte/scanné et conversion Markdown avec ordre de lecture multi-colonnes. Évalué comme complément à pdftotext dans le process de lecture PDF du harness Claude. Installé via cargo, donc couvert automatiquement par `sys-update cargo` (qui lance `cargo install-update -a`) : aucun module sys-update dédié n'est nécessaire.

Installation. Les features OCR (`--features ocr`) sont volontairement écartées : elles exigent PDFium et ONNX Runtime installés séparément, pour un besoin qui reste marginal ici.

```bash
cargo install pdf-inspector --locked 2>&1 | tail -3
```

```output
    Updating crates.io index
     Ignored package `pdf-inspector v1.15.0` is already installed, use --force to override
```

Binaires déployés et version effective.

```bash
ls -1 ~/.cargo/bin/ | grep -E "pdf2md|detect-pdf|dump_ops"; cargo install --list | grep -A3 "^pdf-inspector"
```

```output
detect-pdf
dump_ops
pdf2md
pdf-inspector v1.15.0:
    detect-pdf
    dump_ops
    pdf2md
```

Contrôle fonctionnel : classification d'un ouvrage Elsevier de 544 pages. Le champ pages_needing_ocr isole la couverture scannée sans que le reste du document soit routé vers l'OCR.

```bash
detect-pdf "$HOME/Documents/des/cours/lca/Référentiels/Collège Santé Publique 2019.pdf" --json | jq -c "{pdf_type,confidence,page_count,pages_sampled,pages_needing_ocr,detection_time_ms}"
```

```output
{"pdf_type":"mixed","confidence":0.76,"page_count":544,"pages_sampled":8,"pages_needing_ocr":[1],"detection_time_ms":140}
```
